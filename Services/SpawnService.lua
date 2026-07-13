--[[
	Author      : Lopapon
	Module      : Server/Services/SpawnService
	Description : Decide QUOI spawn, OU, et instancie les MobEntity pour une run donnee.
	              S'abonne a RunStarted/RunEnded pour suivre les runs actives sans
	              dependre directement de RunService (couplage via EventBus uniquement).
	              Le TIMING (quand spawn) est gere par SpawnSystem, pas ici.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)
local MobConfig = require(ReplicatedStorage.Shared.Config.MobConfig)

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local DifficultyService = require(script.Parent.DifficultyService)
local MobEntity = require(script.Parent.Parent.Entities.MobEntity)

local log = Logger.new("SpawnService")

-- ==========================
-- CONFIG
-- ==========================
local SPAWN_RADIUS_MIN = 25
local SPAWN_RADIUS_MAX = 40
local MAX_MOBS_PER_RUN = 40 -- garde-fou perf, ajustable selon les tests

local SpawnService = {}

-- runId -> { Run = Run, ActiveMobs = { MobEntity } }
SpawnService._runData = {} :: { [number]: any }

-- Choix pondere d'un type de mob parmi ceux debloques au stage actuel
local function pickWeightedMob(availableMobs: { any }): any?
	if #availableMobs == 0 then
		return nil
	end

	local totalWeight = 0
	for _, mob in ipairs(availableMobs) do
		totalWeight += mob.SpawnWeight
	end

	local roll = Nova.Math.randomFloat(0, totalWeight)
	local cursor = 0
	for _, mob in ipairs(availableMobs) do
		cursor += mob.SpawnWeight
		if roll <= cursor then
			return mob
		end
	end

	return availableMobs[#availableMobs]
end

-- Position aleatoire en anneau autour d'un joueur pris au hasard dans la run
local function pickSpawnPosition(run: any): CFrame?
	if #run.Players == 0 then
		return nil
	end

	local targetPlayer = run.Players[Nova.Math.randomInt(1, #run.Players)]
	local character = targetPlayer.Character
	if not character then
		return nil
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return nil
	end

	local angle = Nova.Math.randomAngle()
	local radius = Nova.Math.randomFloat(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
	local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

	return CFrame.new(rootPart.Position + offset)
end

function SpawnService:RegisterRun(runId: number, run: any)
	SpawnService._runData[runId] = {
		Run = run,
		ActiveMobs = {},
	}
end

function SpawnService:UnregisterRun(runId: number)
	local data = SpawnService._runData[runId]
	if not data then
		return
	end

	for _, mob in ipairs(data.ActiveMobs) do
		mob:Destroy()
	end

	SpawnService._runData[runId] = nil
end

function SpawnService:GetActiveMobCount(runId: number): number
	local data = SpawnService._runData[runId]
	return data and #data.ActiveMobs or 0
end

-- Tente de spawn un mob pour la run donnee. Retourne le MobEntity cree, ou nil.
function SpawnService:TrySpawnMob(runId: number): any?
	local data = SpawnService._runData[runId]
	if not data then
		return nil
	end

	if #data.ActiveMobs >= MAX_MOBS_PER_RUN then
		return nil
	end

	local run = data.Run
	local zoneIndex = run.Zone:GetZoneIndex()
	local elapsedTime = run.Zone:GetElapsedTime()

	local availableMobs = MobConfig.GetAvailableAtZone(zoneIndex)
	local mobConfigEntry = pickWeightedMob(availableMobs)
	if not mobConfigEntry then
		return nil
	end

	local spawnCFrame = pickSpawnPosition(run)
	if not spawnCFrame then
		return nil
	end

	local difficultyMultiplier = DifficultyService:GetDifficultyMultiplier(elapsedTime, #run.Players)
	local mapParent = run.MapClone

	local mob = MobEntity.new(mobConfigEntry, spawnCFrame, difficultyMultiplier, mapParent, runId)
	if not mob then
		return nil
	end

	table.insert(data.ActiveMobs, mob)

	mob.Died:Connect(function()
		local index = table.find(data.ActiveMobs, mob)
		if index then
			table.remove(data.ActiveMobs, index)
		end
		EventBus:Publish("MobDied", runId, mob)
	end)

	EventBus:Publish("MobSpawned", runId, mob)
	return mob
end

function SpawnService:Init()
	EventBus:Subscribe("RunStarted", function(runId, players)
		local run = require(script.Parent.RunService):GetRun(runId)
		if run then
			SpawnService:RegisterRun(runId, run)
			log:Info("Spawn active pour la run", runId)
		end
	end)

	EventBus:Subscribe("RunEnded", function(runId)
		SpawnService:UnregisterRun(runId)
		log:Info("Spawn desactive pour la run", runId)
	end)
end

return SpawnService