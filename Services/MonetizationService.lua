--[[
	Author      : Lopapon
	Module      : Server/Services/MonetizationService
	Description : Traite les achats de Developer Products (via ProcessReceipt,
	              obligatoire pour eviter la perte d'achat si le joueur se
	              deconnecte) et les Game Passes (verification a la connexion +
	              a l'achat via PromptGamePassPurchaseFinished).
	              Pattern registry/factory : ajouter un produit = ajouter une
	              entree ici + un handler, rien d'autre a toucher.
	              IMPORTANT : les vrais Product/Pass Id sont a remplacer une fois
	              crees dans le Creator Dashboard.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local PlayerService = require(script.Parent.PlayerService)
local RewardService = require(script.Parent.RewardService)

local log = Logger.new("MonetizationService")

local MonetizationService = {}

-- ==========================
-- REGISTRE DES DEVELOPER PRODUCTS
-- ==========================
-- productId -> function(player) appelee UNE FOIS l'achat confirme
local DEVELOPER_PRODUCTS = {
	-- [123456789] = function(player)
	-- 	RewardService:GrantGold(player, 500)
	-- end,
}

-- ==========================
-- REGISTRE DES GAME PASSES
-- ==========================
-- passId -> { Id = string cle stockee dans data.OwnedPasses, Name = string }
local GAME_PASSES = {
	-- [987654321] = { Id = "DoubleXP", Name = "Double XP" },
}

local function onProcessReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local handler = DEVELOPER_PRODUCTS[receiptInfo.ProductId]
	if not handler then
		log:Warn("ProcessReceipt pour un ProductId inconnu :", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok = pcall(handler, player)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	EventBus:Publish("ProductPurchased", player, receiptInfo.ProductId)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function grantGamePass(player: Player, passId: number)
	local passData = GAME_PASSES[passId]
	if not passData then
		return
	end

	local data = PlayerService:GetData(player)
	data.OwnedPasses = data.OwnedPasses or {}
	if not table.find(data.OwnedPasses, passData.Id) then
		table.insert(data.OwnedPasses, passData.Id)
		EventBus:Publish("GamePassGranted", player, passData.Id)
		log:Info(player.Name, "possede desormais le pass", passData.Id)
	end
end

function MonetizationService:OwnsPass(player: Player, passId: string): boolean
	local data = PlayerService:GetData(player)
	return data.OwnedPasses ~= nil and table.find(data.OwnedPasses, passId) ~= nil
end

local function checkOwnedPassesOnJoin(player: Player)
	for robloxPassId, passData in pairs(GAME_PASSES) do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, robloxPassId)
		end)
		if ok and owns then
			grantGamePass(player, robloxPassId)
		end
	end
end

function MonetizationService:Init()
	MarketplaceService.ProcessReceipt = onProcessReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if wasPurchased then
			grantGamePass(player, passId)
		end
	end)

	EventBus:Subscribe("PlayerReady", function(player, _entity)
		task.spawn(checkOwnedPassesOnJoin, player)
	end)
end

return MonetizationService