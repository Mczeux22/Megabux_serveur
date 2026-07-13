--[[
	Author      : Lopapon
	Module      : Server/Services/StatService
	Description : Calcule les stats effectives d'un joueur (Base + Modificateurs Flat/Percent).
	              Les modificateurs sont regroupes par "source" (ex: une arme, une
	              competence, un buff temporaire) pour pouvoir tous les retirer d'un
	              coup via RemoveModifiersFromSource, sans avoir a suivre chaque
	              modificateur individuellement cote appelant.
	              Formule : (Base + somme des Flat) * (1 + somme des Percent)
	              Cas special "Speed" : applique directement le resultat sur
	              Humanoid.WalkSpeed a chaque changement. Les autres stats sont
	              purement des valeurs a lire via GetStat (ex: WeaponService lit
	              "Damage" comme bonus de degats plat).
	Usage : StatService:GetStat(player, "Damage")
	        StatService:AddModifier(player, "ability_SpeedBurst", "Speed", 0.5, "Percent")
	        StatService:RemoveModifiersFromSource(player, "ability_SpeedBurst")
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local PlayerService = require(script.Parent.PlayerService)

local log = Logger.new("StatService")

export type ModifierType = "Flat" | "Percent"

-- ==========================
-- CONFIG : stats de base par defaut (avant tout modificateur)
-- ==========================
local BASE_STATS = {
	Damage = 0,    -- bonus de degats plat, ajoute aux degats de base des armes
	Speed = 16,    -- WalkSpeed de base (doit matcher NORMAL_SPEED cote DevTools)
	Armor = 0,     -- reduction de degats -- point d'accroche futur pour DamageSystem
	GoldFind = 0,  -- bonus % de gold trouve -- point d'accroche futur pour RewardService
	XPFind = 0,    -- bonus % d'XP trouve -- point d'accroche futur pour RewardService
}

local StatService = {}

-- userId -> { [statName] = baseValue }
StatService._baseStats = {} :: { [number]: { [string]: number } }

-- userId -> { [sourceId] = { { Stat = string, Value = number, Type = ModifierType }, ... } }
StatService._modifiers = {} :: { [number]: { [string]: { any } } }

local function getBaseStats(userId: number)
	local base = StatService._baseStats[userId]
	if not base then
		base = {}
		for stat, value in pairs(BASE_STATS) do
			base[stat] = value
		end
		StatService._baseStats[userId] = base
	end
	return base
end

local function getSourceModifiers(userId: number)
	local sources = StatService._modifiers[userId]
	if not sources then
		sources = {}
		StatService._modifiers[userId] = sources
	end
	return sources
end

-- Calcule la valeur effective d'une stat : (Base + somme Flat) * (1 + somme Percent)
function StatService:GetStat(player: Player, statName: string): number
	local base = getBaseStats(player.UserId)[statName] or 0

	local flatSum = 0
	local percentSum = 0

	for _, modifiers in pairs(getSourceModifiers(player.UserId)) do
		for _, modifier in ipairs(modifiers) do
			if modifier.Stat == statName then
				if modifier.Type == "Percent" then
					percentSum += modifier.Value
				else
					flatSum += modifier.Value
				end
			end
		end
	end

	return (base + flatSum) * (1 + percentSum)
end

-- Applique le resultat du stat "Speed" directement sur le Humanoid du joueur
-- (les autres stats n'ont pas d'effet automatique, elles sont juste lues a la demande)
local function applySpeedIfNeeded(player: Player, statName: string)
	if statName ~= "Speed" then
		return
	end
	local entity = PlayerService:GetEntity(player)
	if entity and entity.Humanoid then
		entity.Humanoid.WalkSpeed = StatService:GetStat(player, "Speed")
	end
end

-- Ajoute un modificateur regroupe sous sourceId (ex: "ability_SpeedBurst", "weapon_Dagger")
function StatService:AddModifier(player: Player, sourceId: string, statName: string, value: number, modifierType: ModifierType)
	local sources = getSourceModifiers(player.UserId)
	local modifiers = sources[sourceId]
	if not modifiers then
		modifiers = {}
		sources[sourceId] = modifiers
	end

	table.insert(modifiers, {
		Stat = statName,
		Value = value,
		Type = modifierType,
	})

	applySpeedIfNeeded(player, statName)
	EventBus:Publish("StatChanged", player, statName, StatService:GetStat(player, statName))
end

-- Retire TOUS les modificateurs d'une source d'un coup (fin de buff, arme retiree, etc.)
function StatService:RemoveModifiersFromSource(player: Player, sourceId: string)
	local sources = StatService._modifiers[player.UserId]
	if not sources or not sources[sourceId] then
		return
	end

	local affectedStats = {}
	for _, modifier in ipairs(sources[sourceId]) do
		affectedStats[modifier.Stat] = true
	end

	sources[sourceId] = nil

	for statName in pairs(affectedStats) do
		applySpeedIfNeeded(player, statName)
		EventBus:Publish("StatChanged", player, statName, StatService:GetStat(player, statName))
	end
end

-- Reinitialise toutes les stats d'un joueur a leurs valeurs de base (nouvelle vie, debug, etc.)
function StatService:ResetStats(player: Player)
	StatService._baseStats[player.UserId] = nil
	StatService._modifiers[player.UserId] = nil
	getBaseStats(player.UserId)
	applySpeedIfNeeded(player, "Speed")
end

function StatService:Init()
	EventBus:Subscribe("PlayerReady", function(player, _entity)
		StatService:ResetStats(player)
	end)

	EventBus:Subscribe("PlayerLeaving", function(player, _entity)
		StatService._baseStats[player.UserId] = nil
		StatService._modifiers[player.UserId] = nil
	end)
end

return StatService