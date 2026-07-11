--[[
	Author      : Lopapon
	Module      : Server/Services/ChestService
	Description : Gere les coffres places dans les maps. Un coffre = un Model avec
	              le tag CollectionService "Chest", un attribut "ChestId" (cle de
	              ChestConfig) et un ProximityPrompt enfant. Ouverture a usage unique,
	              loot va uniquement au joueur qui declenche (pas toute la run,
	              contrairement aux drops de mob).
	Emplacement : les coffres sont places directement dans les Model de
	              ServerStorage.MapTemplates.* en Studio, tag + attribut a la main.
]]

local CollectionService = game:GetService("CollectionService")

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local RewardService = require(script.Parent.RewardService)
local LootService = require(script.Parent.LootService)

local log = Logger.new("ChestService")

local CHEST_TAG = "Chest"

local ChestService = {}

local function openChest(chestInstance: Instance, player: Player)
	if chestInstance:GetAttribute("Opened") then
		return
	end

	local chestId = chestInstance:GetAttribute("ChestId")
	if not chestId then
		log:Warn("Coffre sans attribut ChestId :", chestInstance:GetFullName())
		return
	end

	chestInstance:SetAttribute("Opened", true)

	local rewards = LootService:RollForChest(chestId)
	for _, rewardEntry in ipairs(rewards) do
		RewardService:ApplyReward(player, rewardEntry)
	end

	local prompt = chestInstance:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end

	EventBus:Publish("ChestOpened", chestInstance, player, chestId, rewards)
	log:Info("Coffre", chestId, "ouvert par", player.Name)
end

local function onChestAdded(chestInstance: Instance)
	local prompt = chestInstance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		log:Warn("Coffre sans ProximityPrompt :", chestInstance:GetFullName())
		return
	end

	prompt.Triggered:Connect(function(player)
		openChest(chestInstance, player)
	end)
end

function ChestService:Init()
	-- Coffres deja presents (ex: script reload en Studio pendant les tests)
	for _, chestInstance in ipairs(CollectionService:GetTagged(CHEST_TAG)) do
		onChestAdded(chestInstance)
	end

	-- Coffres ajoutes plus tard (clonage de map a chaque nouvelle run -- les tags
	-- et attributs survivent au :Clone(), donc chaque nouveau coffre clone
	-- declenche ce signal automatiquement)
	CollectionService:GetInstanceAddedSignal(CHEST_TAG):Connect(onChestAdded)
end

return ChestService