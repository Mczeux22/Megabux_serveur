--[[
	Author      : Lopapon
	Module      : Server/Systems/SpawnSystem
	Description : Gere le TIMING des spawns (SpawnService gere le QUOI/OU).
	              Enregistre dans SystemManager -> :Update(dt) appele chaque Heartbeat.
	              Un accumulateur de temps par run, reset a chaque spawn reussi.
	              N'avance pas pendant un freeze (levelup) -- coherent avec StageService.
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local DifficultyService = require(script.Parent.Parent.Services.DifficultyService)
local SpawnService = require(script.Parent.Parent.Services.SpawnService)

local log = Logger.new("SpawnSystem")

-- ==========================
-- CONFIG
-- ==========================
local BASE_SPAWN_INTERVAL = 3 -- secondes entre deux spawns a difficulte 1.0

local SpawnSystem = {}

-- runId -> { Run = Run, Accumulator = number }
SpawnSystem._runTimers = {} :: { [number]: any }

function SpawnSystem:Init()
	EventBus:Subscribe("RunStarted", function(runId, players)
		local run = require(script.Parent.Parent.Services.RunService):GetRun(runId)
		if run then
			SpawnSystem._runTimers[runId] = {
				Run = run,
				Accumulator = 0,
			}
		end
	end)

	EventBus:Subscribe("RunEnded", function(runId)
		SpawnSystem._runTimers[runId] = nil
	end)
end

function SpawnSystem:Update(dt: number)
	for runId, timerData in pairs(SpawnSystem._runTimers) do
		local run = timerData.Run

		if run.Freeze.IsFrozen then
			continue
		end

		timerData.Accumulator += dt

		local elapsedTime = run.Zone:GetElapsedTime()
		local difficultyMultiplier = DifficultyService:GetDifficultyMultiplier(elapsedTime, #run.Players)

		-- Plus la difficulte monte, plus l'intervalle raccourcit (min 0.5s pour eviter le spam total)
		local interval = math.max(0.5, BASE_SPAWN_INTERVAL / difficultyMultiplier)

		if timerData.Accumulator >= interval then
			timerData.Accumulator = 0
			SpawnService:TrySpawnMob(runId)
		end
	end
end

return SpawnSystem