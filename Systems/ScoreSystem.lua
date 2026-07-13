--[[
	Author      : Lopapon
	Module      : Server/Systems/ScoreSystem
	Description : Calcule un score de run en temps reel (kills ponderes + temps de
	              survie) pour chaque run active. A la fin de la run (RunEnded),
	              soumet le score final de chaque joueur a LeaderboardService et
	              met a jour les Stats lifetime (DataService) -- RunsCompleted,
	              TotalKills, BestTime.
	              Pas de boucle Heartbeat necessaire pour le calcul (le score est
	              accumule evenement par evenement), mais reste enregistre dans
	              SystemManager pour beneficier du meme cycle de vie Init que les
	              autres Systems.
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local PlayerService = require(script.Parent.Parent.Services.PlayerService)
local LeaderboardService = require(script.Parent.Parent.Services.LeaderboardService)

local log = Logger.new("ScoreSystem")

-- ==========================
-- CONFIG (ponderation du score -- a tuner selon le ressenti en jeu)
-- ==========================
local POINTS_PER_KILL = 10
local POINTS_PER_SECOND_SURVIVED = 1

local ScoreSystem = {}

-- runId -> { Run = Run, Kills = { [userId] = number } }
ScoreSystem._runData = {} :: { [number]: any }

function ScoreSystem:Init()
	EventBus:Subscribe("RunStarted", function(runId, players)
		local run = require(script.Parent.Parent.Services.RunService):GetRun(runId)
		if not run then
			return
		end

		local kills = {}
		for _, player in ipairs(players) do
			kills[player.UserId] = 0
		end

		ScoreSystem._runData[runId] = {
			Run = run,
			Kills = kills,
		}
	end)

	EventBus:Subscribe("MobDied", function(runId, _mob)
		local data = ScoreSystem._runData[runId]
		if not data then
			return
		end

		-- Attribution simple : tous les joueurs presents dans la run recoivent le
		-- kill (co-op, pas de tracking d'attribution individuelle -- meme logique
		-- que RewardService qui distribue XP/Gold a toute la run)
		for _, player in ipairs(data.Run.Players) do
			data.Kills[player.UserId] = (data.Kills[player.UserId] or 0) + 1
		end
	end)

	EventBus:Subscribe("RunEnded", function(runId)
		local data = ScoreSystem._runData[runId]
		if not data then
			return
		end

		local elapsedTime = data.Run.Zone:GetElapsedTime()

		for _, player in ipairs(data.Run.Players) do
			local kills = data.Kills[player.UserId] or 0
			local score = (kills * POINTS_PER_KILL) + (elapsedTime * POINTS_PER_SECOND_SURVIVED)

			LeaderboardService:SubmitScore(player, score)

			local playerData = PlayerService:GetData(player)
			playerData.Stats = playerData.Stats or { RunsCompleted = 0, TotalKills = 0, BestTime = 0 }
			playerData.Stats.RunsCompleted += 1
			playerData.Stats.TotalKills += kills
			if elapsedTime > playerData.Stats.BestTime then
				playerData.Stats.BestTime = elapsedTime
			end

			log:Info(player.Name, "termine la run", runId, "avec un score de", score)
		end

		ScoreSystem._runData[runId] = nil
	end)
end

return ScoreSystem