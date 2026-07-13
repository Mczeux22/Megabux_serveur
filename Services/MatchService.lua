--[[
	Author      : Lopapon
	Module      : Server/Services/MatchService
	Description : File d'attente et classement ELO pour le mode competitif 1v1.
	              Gere la mise en file, l'appariement (2 joueurs de la file ->
	              une Run dediee via RunService), et la mise a jour du rating a
	              la fin d'un match.
	              La RESOLUTION du combat (qui gagne un 1v1) n'existe pas encore --
	              CombatSystem/DamageSystem ne gerent aujourd'hui que
	              mob -> joueur, pas joueur -> joueur. :ReportMatchResult() est le
	              point d'accroche pret pour brancher ca plus tard (meme logique
	              que AbilityService en attente d'un Remote).
	Usage : MatchService:JoinQueue(player)
	        MatchService:LeaveQueue(player)
	        MatchService:ReportMatchResult(runId, winner, loser)
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local PlayerService = require(script.Parent.PlayerService)
local RunService = require(script.Parent.RunService)

local log = Logger.new("MatchService")

-- ==========================
-- CONFIG
-- ==========================
local DEFAULT_RATING = 1000
local K_FACTOR = 32

local MatchService = {}

-- File d'attente FIFO
MatchService._queue = {} :: { Player }

-- runId -> { PlayerA, PlayerB } -- runs issues du matchmaking, distinguees des
-- runs PvE normales pour ne pas fausser le rating si RunEnded arrive sans resultat
MatchService._activeMatches = {} :: { [number]: { Player } }

-- Le rating est stocke directement dans la donnee persistante (DataService), avec
-- un fallback par defaut a la lecture -- pas besoin de bump DataTemplate.Version
-- pour un champ additif simple (meme approche defensive que RewardService pour Gold)
local function getRating(player: Player): number
	local data = PlayerService:GetData(player)
	return data.Rating or DEFAULT_RATING
end

local function setRating(player: Player, rating: number)
	local data = PlayerService:GetData(player)
	data.Rating = rating
end

-- Probabilite de victoire attendue de A face a B (formule ELO standard)
local function expectedScore(ratingA: number, ratingB: number): number
	return 1 / (1 + 10 ^ ((ratingB - ratingA) / 400))
end

local function removeFromQueue(player: Player)
	local index = table.find(MatchService._queue, player)
	if index then
		table.remove(MatchService._queue, index)
	end
end

-- Tente d'apparier les 2 premiers joueurs de la file. Retourne true si un match a demarre.
local function tryMatchmake(): boolean
	if #MatchService._queue < 2 then
		return false
	end

	local playerA = table.remove(MatchService._queue, 1)
	local playerB = table.remove(MatchService._queue, 1)

	-- L'un des deux a pu se deconnecter pendant qu'il attendait -- on remet
	-- proprement celui qui est toujours la plutot que de perdre sa place
	if not playerA.Parent or not playerB.Parent then
		if playerA.Parent then
			table.insert(MatchService._queue, 1, playerA)
		end
		if playerB.Parent then
			table.insert(MatchService._queue, 1, playerB)
		end
		return false
	end

	RunService:StartRun({ playerA, playerB })

	-- RunService:StartRun ne retourne pas encore la Run creee (voir RunService.lua) --
	-- on la retrouve via GetRunForPlayer en attendant un retour direct de StartRun
	local matchedRun = RunService:GetRunForPlayer(playerA)
	if not matchedRun then
		log:Warn("Impossible de recuperer la run pour le match", playerA.Name, "vs", playerB.Name)
		return false
	end

	MatchService._activeMatches[matchedRun.RunId] = { playerA, playerB }
	EventBus:Publish("MatchStarted", matchedRun.RunId, playerA, playerB)
	log:Info("Match demarre :", playerA.Name, "vs", playerB.Name, "(run", matchedRun.RunId, ")")
	return true
end

function MatchService:JoinQueue(player: Player)
	if table.find(MatchService._queue, player) then
		return
	end
	table.insert(MatchService._queue, player)
	log:Info(player.Name, "rejoint la file ranked (rating", getRating(player), ")")

	tryMatchmake()
end

function MatchService:LeaveQueue(player: Player)
	removeFromQueue(player)
end

-- A appeler une fois qu'un vainqueur est determine (branche plus tard sur un futur
-- systeme de combat PvP -- voir description du module)
function MatchService:ReportMatchResult(runId: number, winner: Player, loser: Player)
	if not MatchService._activeMatches[runId] then
		log:Warn("ReportMatchResult sur un match inconnu :", runId)
		return
	end

	local winnerRating = getRating(winner)
	local loserRating = getRating(loser)

	local winnerExpected = expectedScore(winnerRating, loserRating)
	local loserExpected = expectedScore(loserRating, winnerRating)

	local newWinnerRating = math.floor(winnerRating + K_FACTOR * (1 - winnerExpected) + 0.5)
	local newLoserRating = math.floor(loserRating + K_FACTOR * (0 - loserExpected) + 0.5)

	setRating(winner, newWinnerRating)
	setRating(loser, newLoserRating)

	MatchService._activeMatches[runId] = nil

	EventBus:Publish("MatchEnded", runId, winner, loser, newWinnerRating, newLoserRating)
	log:Info(winner.Name, "bat", loser.Name, "- ratings :", newWinnerRating, "/", newLoserRating)
end

function MatchService:Init()
	EventBus:Subscribe("PlayerLeaving", function(player, _entity)
		removeFromQueue(player)
	end)

	EventBus:Subscribe("RunEnded", function(runId)
		MatchService._activeMatches[runId] = nil
	end)
end

return MatchService