--[[
	Author      : Lopapon
	Module      : Server/Services/RebirthService
	Description : Gere le rebirth (prestige) : verifie les conditions (Level +
	              Gold), reset la progression meta (Level, XP, Gold,
	              UnlockedWeapons -- garde UnlockedHeroes et les Stats lifetime),
	              incremente RebirthCount, et applique le bonus permanent
	              (RebirthConfig.Bonus) via StatService a chaque connexion.

	              L'application du bonus est deferree (task.defer) apres
	              PlayerReady pour toujours s'executer APRES
	              StatService:ResetStats -- l'ordre d'Init() entre Services n'est
	              pas garanti par ServiceManager (scan de dossier, pairs() non
	              ordonne), donc on ne peut pas supposer que StatService a deja
	              tourne au moment ou RebirthService recoit PlayerReady.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RebirthConfig = require(game.ReplicatedStorage.Shared.Megabux_shared.Config.RebirthConfig)

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local PlayerService = require(script.Parent.PlayerService)
local StatService = require(script.Parent.StatService)

local log = Logger.new("RebirthService")

local REBIRTH_SOURCE_ID = "rebirth_permanent"

local RebirthService = {}

-- Applique (ou reapplique) le bonus permanent correspondant au RebirthCount actuel.
-- Retire d'abord l'ancien modificateur pour eviter un double-stack si appele deux fois.
local function applyRebirthBonus(player: Player)
	local data = PlayerService:GetData(player)
	local rebirthCount = data.RebirthCount or 0

	StatService:RemoveModifiersFromSource(player, REBIRTH_SOURCE_ID)

	if rebirthCount <= 0 then
		return
	end

	local bonus = RebirthConfig.Bonus
	local totalValue = bonus.ValuePerRebirth * rebirthCount
	StatService:AddModifier(player, REBIRTH_SOURCE_ID, bonus.Stat, totalValue, bonus.Type)
end

-- Verifie si un joueur remplit les conditions pour rebirth (niveau meta + gold)
function RebirthService:CanRebirth(player: Player): boolean
	local data = PlayerService:GetData(player)

	if RebirthConfig.MaxRebirths and (data.RebirthCount or 0) >= RebirthConfig.MaxRebirths then
		return false
	end

	if (data.Level or 1) < RebirthConfig.RequiredLevel then
		return false
	end

	if (data.Gold or 0) < RebirthConfig.GoldCost then
		return false
	end

	return true
end

-- Effectue le rebirth. Retourne true si succes.
function RebirthService:TryRebirth(player: Player): boolean
	if not RebirthService:CanRebirth(player) then
		log:Warn(player.Name, "a tente un rebirth sans remplir les conditions")
		return false
	end

	local data = PlayerService:GetData(player)

	data.Gold -= RebirthConfig.GoldCost
	data.Level = 1
	data.XP = 0
	data.UnlockedWeapons = {}
	data.RebirthCount = (data.RebirthCount or 0) + 1
	-- UnlockedHeroes et Stats lifetime (RunsCompleted/TotalKills/BestTime) sont
	-- volontairement conserves -- le rebirth reset la progression de puissance,
	-- pas l'historique ni les heros debloques

	applyRebirthBonus(player)

	EventBus:Publish("PlayerRebirthed", player, data.RebirthCount)
	log:Info(player.Name, "effectue son rebirth #", data.RebirthCount)
	return true
end

function RebirthService:Init()
	EventBus:Subscribe("PlayerReady", function(player, _entity)
		task.defer(function()
			applyRebirthBonus(player)
		end)
	end)
end

return RebirthService