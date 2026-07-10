--[[
	Author      : Lopapon
	Module      : Server/Systems/MobAISystem
	Description : Suit tous les mobs actifs par run, choisit leur cible (joueur le plus
	              proche) et delegue le mouvement a PathfindingSystem. Respecte le
	              FreezeService de la run (aucun mouvement pendant un levelup).
	              Enregistre dans SystemManager -> :Update(dt) appele chaque Heartbeat.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local PathfindingSystem = require(script.Parent.PathfindingSystem)

local log = Logger.new("MobAISystem")

local MobAISystem = {}

-- runId -> { Run = Run, Mobs = { MobEntity } }
MobAISystem._runData = {} :: { [number]: any }

-- Trouve le joueur le plus proche du mob dans sa run, retourne sa position (ou nil)
local function findNearestPlayerPosition(mob: any, players: { Player }): Vector3?
	if not mob.RootPart then
		return nil
	end

	local nearestPosition: Vector3? = nil
	local nearestDistance = math.huge

	for _, player in ipairs(players) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			local distance = Nova.Math.distance2D(mob.RootPart.Position, rootPart.Position)
			if distance < nearestDistance then
				nearestDistance = distance
				nearestPosition = rootPart.Position
			end
		end
	end

	return nearestPosition
end

function MobAISystem:Init()
	EventBus:Subscribe("RunStarted", function(runId, players)
		local run = require(script.Parent.Parent.Services.RunService):GetRun(runId)
		if run then
			MobAISystem._runData[runId] = {
				Run = run,
				Mobs = {},
			}
		end
	end)

	EventBus:Subscribe("RunEnded", function(runId)
		MobAISystem._runData[runId] = nil
	end)

	EventBus:Subscribe("MobSpawned", function(runId, mob)
		local data = MobAISystem._runData[runId]
		if data then
			table.insert(data.Mobs, mob)
		end
	end)

	EventBus:Subscribe("MobDied", function(runId, mob)
		local data = MobAISystem._runData[runId]
		if data then
			local index = table.find(data.Mobs, mob)
			if index then
				table.remove(data.Mobs, index)
			end
		end
		PathfindingSystem:ClearMob(mob)
	end)
end

function MobAISystem:Update(dt: number)
	for runId, data in pairs(MobAISystem._runData) do
		local run = data.Run

		if run.Freeze.IsFrozen then
			continue -- les mobs restent figes pendant le levelup
		end

		for _, mob in ipairs(data.Mobs) do
			if mob.IsAlive then
				local targetPosition = findNearestPlayerPosition(mob, run.Players)
				if targetPosition then
					PathfindingSystem:UpdateMobMovement(mob, targetPosition)
				end
			end
		end
	end
end

return MobAISystem