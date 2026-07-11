--[[
	Author      : Lopapon
	Module      : Server/Services/RewardService
	Description : Applique les recompenses a un joueur (XP en runtime via PlayerEntity,
	              Gold en persistant via DataService). S'abonne a "MobDied" pour
	              distribuer le XP/Gold garanti (MobConfig.BaseStats) + les drops
	              bonus (LootService) a TOUS les joueurs de la run (co-op, pas de split).
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local PlayerService = require(script.Parent.PlayerService)
local LootService = require(script.Parent.LootService)

local log = Logger.new("RewardService")

local RewardService = {}

-- Ajoute du XP de run (runtime, reset a chaque run) via PlayerEntity
function RewardService:GrantXP(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	local entity = PlayerService:GetEntity(player)
	if not entity then
		return
	end

	entity:GainXP(amount)
	EventBus:Publish("PlayerXPGranted", player, amount, entity.CurrentXP)
end

-- Ajoute du Gold persistant (sauvegarde par DataService, jamais reset)
function RewardService:GrantGold(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	local data = PlayerService:GetData(player)
	data.Gold = (data.Gold or 0) + amount
	EventBus:Publish("PlayerGoldGranted", player, amount, data.Gold)
end

-- Applique une RewardEntry generique (utile pour les drops bonus de LootService)
function RewardService:ApplyReward(player: Player, rewardEntry: any)
	if rewardEntry.Type == "XP" then
		RewardService:GrantXP(player, rewardEntry.Amount)
	elseif rewardEntry.Type == "Gold" then
		RewardService:GrantGold(player, rewardEntry.Amount)
	elseif rewardEntry.Type == "Item" then
		log:Warn("Drop d'item ignore (InventoryService pas encore construit) :", rewardEntry.ItemId)
	end
end

-- Distribue une liste de RewardEntry a tous les joueurs d'une run
function RewardService:GrantToRun(runId: number, rewards: { any })
	local run = require(script.Parent.RunService):GetRun(runId)
	if not run then
		return
	end

	for _, player in ipairs(run.Players) do
		for _, rewardEntry in ipairs(rewards) do
			RewardService:ApplyReward(player, rewardEntry)
		end
	end
end

local function onMobDied(runId: number, mob: any)
	local run = require(script.Parent.RunService):GetRun(runId)
	if not run then
		return
	end

	local baseRewards = {
		{ Type = "XP", Amount = mob.XPReward },
		{ Type = "Gold", Amount = mob.GoldReward },
	}

	local bonusRewards = LootService:RollForMob(mob.MobId)

	for _, player in ipairs(run.Players) do
		for _, rewardEntry in ipairs(baseRewards) do
			RewardService:ApplyReward(player, rewardEntry)
		end
		for _, rewardEntry in ipairs(bonusRewards) do
			RewardService:ApplyReward(player, rewardEntry)
		end
	end
end

function RewardService:Init()
	EventBus:Subscribe("MobDied", function(runId, mob)
		onMobDied(runId, mob)
	end)
end

return RewardService