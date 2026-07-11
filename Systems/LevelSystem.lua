--[[
	Author      : Lopapon
	Module      : Server/Systems/LevelSystem
	Description : Gere la montee de niveau IN-RUN du joueur (RunLevel + CurrentXP sur
	              PlayerEntity), distincte du Level persistant meta-progression
	              (DataService). Ecoute "PlayerXPGranted" (publie par RewardService).

	              A chaque levelup : freeze toute la run (choix d'upgrade a l'ecran),
	              le degel n'intervient que quand TOUS les joueurs en attente ont
	              valide leur choix via :CompleteLevelUp() (appele plus tard par
	              UpgradeService, pas encore construit -- point d'accroche pret).

	              Gere aussi le cas d'un gros gain de XP d'un coup (ex: coffre) qui
	              ferait franchir plusieurs paliers en meme temps.
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local PlayerService = require(script.Parent.Parent.Services.PlayerService)

local log = Logger.new("LevelSystem")

-- ==========================
-- CONFIG (courbe d'XP -- a tuner selon le ressenti en jeu)
-- ==========================
local BASE_XP_REQUIREMENT = 10
local XP_GROWTH_PER_LEVEL = 5

local function getXPRequiredForLevel(level: number): number
	return BASE_XP_REQUIREMENT + (level - 1) * XP_GROWTH_PER_LEVEL
end

local LevelSystem = {}

-- runId -> { Run = Run, PendingPlayers = { [Player]: true } }
LevelSystem._runData = {} :: { [number]: any }

local function getRunData(runId: number)
	return LevelSystem._runData[runId]
end

-- Fait monter le joueur d'autant de niveaux que son XP le permet (gere le multi-levelup)
local function processLevelUps(player: Player, entity: any, runId: number)
	local data = getRunData(runId)
	if not data then
		return
	end

	local leveledUp = false

	while entity.CurrentXP >= getXPRequiredForLevel(entity.RunLevel) do
		entity.CurrentXP -= getXPRequiredForLevel(entity.RunLevel)
		entity.RunLevel += 1
		leveledUp = true
	end

	if not leveledUp then
		return
	end

	data.PendingPlayers[player] = true

	if not data.Run.Freeze.IsFrozen then
		data.Run.Freeze:Freeze()
	end

	EventBus:Publish("PlayerLeveledUp", player, entity.RunLevel)
	log:Info(player.Name, "atteint le niveau", entity.RunLevel)
end

-- A appeler par UpgradeService une fois que le joueur a valide son choix d'upgrade
function LevelSystem:CompleteLevelUp(player: Player)
	local entity = PlayerService:GetEntity(player)
	if not entity or not entity.RunId then
		return
	end

	local data = getRunData(entity.RunId)
	if not data then
		return
	end

	data.PendingPlayers[player] = nil

	if next(data.PendingPlayers) == nil and data.Run.Freeze.IsFrozen then
		data.Run.Freeze:Unfreeze()
	end
end

function LevelSystem:Init()
	EventBus:Subscribe("RunStarted", function(runId, players)
		local run = require(script.Parent.Parent.Services.RunService):GetRun(runId)
		if run then
			LevelSystem._runData[runId] = {
				Run = run,
				PendingPlayers = {},
			}
		end
	end)

	EventBus:Subscribe("RunEnded", function(runId)
		LevelSystem._runData[runId] = nil
	end)

	-- Si un joueur quitte pendant qu'on l'attendait, on ne bloque pas le degel des autres
	EventBus:Subscribe("PlayerLeaving", function(player, entity)
		if entity and entity.RunId then
			local data = getRunData(entity.RunId)
			if data and data.PendingPlayers[player] then
				data.PendingPlayers[player] = nil
				if next(data.PendingPlayers) == nil and data.Run.Freeze.IsFrozen then
					data.Run.Freeze:Unfreeze()
				end
			end
		end
	end)

	EventBus:Subscribe("PlayerXPGranted", function(player, _amount, _newXP)
		local entity = PlayerService:GetEntity(player)
		if entity and entity.RunId then
			processLevelUps(player, entity, entity.RunId)
		end
	end)
end

return LevelSystem