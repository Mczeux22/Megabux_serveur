--[[
	Author      : Lopapon
	Module      : Server/Services/LeaderboardService
	Description : Classement global persistant via OrderedDataStore. Ne garde que
	              le MEILLEUR score de chaque joueur (n'ecrase que si le nouveau
	              score est superieur). Lecture paginee pour un futur affichage UI.
	Usage : LeaderboardService:SubmitScore(player, score)
	        local top = LeaderboardService:GetTopScores(10)
]]

local DataStoreService = game:GetService("DataStoreService")

local Logger = require(script.Parent.Parent.Core.Logger)
local log = Logger.new("LeaderboardService")

local LeaderboardService = {}

local orderedStore = DataStoreService:GetOrderedDataStore("Leaderboard_v1")

-- Soumet un score. N'ecrase le score existant que s'il est superieur (meilleure run).
function LeaderboardService:SubmitScore(player: Player, score: number)
	if score <= 0 then
		return
	end

	local key = tostring(player.UserId)

	local ok, err = pcall(function()
		local current = orderedStore:GetAsync(key)
		if not current or score > current then
			orderedStore:SetAsync(key, score)
		end
	end)

	if not ok then
		log:Warn("Echec soumission de score pour", player.Name, "-", err)
	end
end

-- Retourne les N meilleurs scores : { { UserId = number, Score = number }, ... }
function LeaderboardService:GetTopScores(count: number): { any }
	local results = {}

	local ok, pages = pcall(function()
		return orderedStore:GetSortedAsync(false, count)
	end)

	if not ok then
		log:Warn("Echec lecture du classement -", pages)
		return results
	end

	local currentPage = pages:GetCurrentPage()
	for _, entry in ipairs(currentPage) do
		table.insert(results, {
			UserId = tonumber(entry.key),
			Score = entry.value,
		})
	end

	return results
end

return LeaderboardService