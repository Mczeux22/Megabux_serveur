--[[
	Author      : Lopapon
	Module      : Server/Services/LootService
	Description : Tire les recompenses BONUS (au-dela du XP/Gold garanti deja gere
	              par RewardService/MobConfig) pour un mob tue ou un coffre ouvert.
	              Lit LootConfig.MobBonusDrops et ChestConfig (Shared) -- module pur,
	              sans etat interne, chaque appel est un tirage independant.
	Usage : local rewards = LootService:RollForMob(mobId)
	        local rewards = LootService:RollForChest(chestId)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)
local LootConfig = require(ReplicatedStorage.Shared.Config.LootConfig)
local ChestConfig = require(ReplicatedStorage.Shared.Config.ChestConfig)

local Logger = require(script.Parent.Parent.Core.Logger)
local log = Logger.new("LootService")

local LootService = {}

-- Tire un montant aleatoire entre MinAmount et MaxAmount pour une entree de drop
local function rollAmount(entry: any): number
	return Nova.Math.randomInt(entry.MinAmount, entry.MaxAmount)
end

-- Tire une liste de LootDropEntry (chance individuelle chacune -- peut donner 0, 1
-- ou plusieurs drops d'un coup, chaque entree est independante des autres)
local function rollDropList(dropList: { any }): { any }
	local results = {}
	for _, entry in ipairs(dropList) do
		if Nova.Math.chance(entry.Chance) then
			table.insert(results, {
				Type = entry.Type,
				Amount = rollAmount(entry),
				ItemId = entry.ItemId,
			})
		end
	end
	return results
end

-- Drops bonus a la mort d'un mob (en plus du XP/Gold garanti de MobConfig.BaseStats,
-- deja distribue directement par RewardService -- voir onMobDied)
function LootService:RollForMob(mobId: string): { any }
	local dropList = LootConfig.MobBonusDrops[mobId]
	if not dropList then
		return {}
	end
	return rollDropList(dropList)
end

-- Recompenses a l'ouverture d'un coffre : Gold garanti (fourchette) + drops bonus.
-- Le Gold garanti est TOUJOURS present (contrairement aux drops bonus qui roll une chance).
function LootService:RollForChest(chestId: string): { any }
	local config = ChestConfig[chestId]
	if not config then
		log:Warn("ChestConfig introuvable pour", chestId)
		return {}
	end

	local rewards = {
		{
			Type = "Gold",
			Amount = Nova.Math.randomInt(config.GuaranteedGold.Min, config.GuaranteedGold.Max),
		},
	}

	for _, bonusReward in ipairs(rollDropList(config.BonusDrops)) do
		table.insert(rewards, bonusReward)
	end

	return rewards
end

return LootService