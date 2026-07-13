--[[
	Author      : Lopapon
	Module      : Server/Services/RunService
	Description : Orchestre le cycle de vie complet d'une run :
	              detection du pad (ProximityPrompt) -> capture de la party ->
	              clonage de la map template avec offset -> teleport des joueurs ->
	              suivi de la progression (StageService) -> fin de run -> cleanup complet.
	              Supporte plusieurs runs simultanees, chacune totalement isolee
	              (map clonee + offset, Maid dedie, StageService/FreezeService dedies).

	Emplacement attendu des instances :
	  workspace.Lobby.RunPad (Part avec un ProximityPrompt enfant)
	  ServerStorage.MapTemplates.DefaultMap (Model a cloner pour chaque run)
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Logger = require(script.Parent.Parent.Core.Logger)
local Maid = require(script.Parent.Parent.Core.Maid)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local PlayerService = require(script.Parent.PlayerService)
local ZoneService = require(script.Parent.ZoneService)
local FreezeService = require(script.Parent.FreezeService)

local log = Logger.new("RunService")

-- ==========================
-- CONFIG
-- ==========================
local PAD_CAPTURE_RADIUS = 15
local MAX_PARTY_SIZE = 4
local MAP_OFFSET_STUDS = 2000
local LOBBY_SPAWN_POSITION = Vector3.new(0, 5, 0) -- a ajuster selon ton lobby reel

-- ==========================
-- CLASSE INTERNE : Run
-- ==========================
local Run = {}
Run.__index = Run

local nextRunId = 0

local function getNextRunId(): number
	nextRunId += 1
	return nextRunId
end

function Run.new(players: { Player })
	local self = setmetatable({}, Run)

	self.RunId = getNextRunId()
	self.Players = players
	self.State = "Waiting"
	self.Maid = Maid.new()
	self.Offset = Vector3.new(self.RunId * MAP_OFFSET_STUDS, 0, 0)
	self.MapClone = nil :: Model?

	self.Freeze = FreezeService.new(self.RunId)
	self.Zone = ZoneService.new(self.RunId, self.Freeze)

	self.Maid:GiveTask(self.Freeze)
	self.Maid:GiveTask(self.Zone)

	return self
end

function Run:CloneMap(): boolean
	local JoinDataService = require(script.Parent.JoinDataService)
	local mapId = (self.Players[1] and JoinDataService:GetMapId(self.Players[1])) or "DefaultMap"

	local template = ServerStorage:FindFirstChild("MapTemplates")
		and ServerStorage.MapTemplates:FindFirstChild(mapId)

	if not template then
		log:Error("MapTemplates." .. mapId .. " introuvable dans ServerStorage - impossible de creer la run", self.RunId)
		return false
	end

	local clone = template:Clone()
	clone.Name = "Run_" .. self.RunId
	clone:PivotTo(clone:GetPivot() + self.Offset)
	clone.Parent = Workspace

	self.MapClone = clone
	self.Maid:GiveTask(clone)
	return true
end

function Run:TeleportPlayersIn()
	for _, player in ipairs(self.Players) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				rootPart.CFrame = CFrame.new(LOBBY_SPAWN_POSITION + self.Offset)
			end
		end

		local entity = PlayerService:GetEntity(player)
		if entity then
			entity:EnterRun(self.RunId)
		end
	end
end

function Run:TeleportPlayersOut()
	for _, player in ipairs(self.Players) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				rootPart.CFrame = CFrame.new(LOBBY_SPAWN_POSITION)
			end
		end

		local entity = PlayerService:GetEntity(player)
		if entity then
			entity:ExitRun()
		end
	end
end

function Run:OpenBarriersForZone(zoneIndex: number)
	local CollectionService = game:GetService("CollectionService")

	for _, barrier in ipairs(CollectionService:GetTagged("ZoneBarrier")) do
		if barrier:IsDescendantOf(self.MapClone) and barrier:GetAttribute("OpensAtZone") == zoneIndex then
			if barrier:IsA("BasePart") then
				barrier.CanCollide = false
				barrier.Transparency = 1
			end
			barrier:SetAttribute("Opened", true)
			EventBus:Publish("MistActivated", self.RunId, barrier)
			log:Info("Barriere ouverte pour la zone", zoneIndex, "(run", self.RunId, ")")
		end
	end
end

function Run:Start()
	if not self:CloneMap() then
		return false
	end

	self.State = "Active"
	self:TeleportPlayersIn()
	self.Zone:Start()
	self.Zone.ZoneAdvanced:Connect(function(zoneIndex)
		self:OpenBarriersForZone(zoneIndex)
	end)

	EventBus:Publish("RunStarted", self.RunId, self.Players)
	log:Info("Run", self.RunId, "demarree avec", #self.Players, "joueur(s)")
	return true
end

-- Retire un joueur d'une run en cours (deconnexion, quitte manuellement)
function Run:RemovePlayer(player: Player)
	for i, p in ipairs(self.Players) do
		if p == player then
			table.remove(self.Players, i)
			break
		end
	end
end

function Run:End()
	if self.State == "Ending" then
		return
	end
	self.State = "Ending"

	self.Zone:Stop()
	self:TeleportPlayersOut()

	EventBus:Publish("RunEnded", self.RunId)
	log:Info("Run", self.RunId, "terminee")

	self.Maid:Destroy() -- detruit MapClone, Freeze, Stage d'un coup
end

-- ==========================
-- SERVICE
-- ==========================
local RunService = {}
RunService._activeRuns = {} :: { [number]: any } -- runId -> Run
RunService._pendingParty = {} :: { Player }

local function capturePartyNearPad(pad: BasePart): { Player }
	local party = {}
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart and (rootPart.Position - pad.Position).Magnitude <= PAD_CAPTURE_RADIUS then
				table.insert(party, player)
				if #party >= MAX_PARTY_SIZE then
					break
				end
			end
		end
	end
	return party
end

function RunService:GetRun(runId: number): any?
	return RunService._activeRuns[runId]
end

function RunService:GetRunForPlayer(player: Player): any?
	for _, run in pairs(RunService._activeRuns) do
		if table.find(run.Players, player) then
			return run
		end
	end
	return nil
end

function RunService:StartRun(players: { Player })
	if #players == 0 then
		return
	end

	local run = Run.new(players)
	RunService._activeRuns[run.RunId] = run

	if not run:Start() then
		RunService._activeRuns[run.RunId] = nil
	end
end

function RunService:EndRun(runId: number)
	local run = RunService._activeRuns[runId]
	if not run then
		log:Warn("EndRun appele sur une run inexistante :", runId)
		return
	end

	run:End()
	RunService._activeRuns[runId] = nil
end

local function onPadTriggered(pad: BasePart)
	local party = capturePartyNearPad(pad)
	if #party == 0 then
		return
	end
	RunService:StartRun(party)
end

function RunService:Init()
	local pad = Workspace:FindFirstChild("Lobby") and Workspace.Lobby:FindFirstChild("RunPad")
	if not pad then
		log:Error("workspace.Lobby.RunPad introuvable - le declenchement de run par pad est desactive")
	else
		local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(_player)
				onPadTriggered(pad)
			end)
		else
			log:Error("Aucun ProximityPrompt trouve sur RunPad")
		end
	end

	-- Si un joueur quitte le serveur en pleine run, on le retire proprement
	EventBus:Subscribe("PlayerLeaving", function(player, entity)
		local run = RunService:GetRunForPlayer(player)
		if run then
			run:RemovePlayer(player)
			if #run.Players == 0 then
				RunService:EndRun(run.RunId)
			end
		end
	end)
end

return RunService