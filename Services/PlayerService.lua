--[[
	Author      : Lopapon
	Module      : Server/Services/PlayerService
	Description : Point d'entree unique pour recuperer un PlayerEntity ou la donnee
	              persistante d'un joueur. Fait le pont entre DataService (persistant)
	              et PlayerEntity (runtime). Publie sur EventBus : PlayerReady, PlayerLeaving.
]]

local Players = game:GetService("Players")

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local DataService = require(script.Parent.Parent.Data.DataService)
local PlayerEntity = require(script.Parent.Parent.Entities.PlayerEntity)

local log = Logger.new("PlayerService")

local PlayerService = {}
PlayerService._entities = {} :: { [number]: any } -- userId -> PlayerEntity

local function	onCharacterAdded(player: Player, character: Model)
	local userId = player.UserId

	-- Si un ancien PlayerEntity trainait (respawn), on le nettoie avant d'en creer un nouveau
	local existing = PlayerService._entities[userId]
	if existing then
		existing:Destroy()
	end

	local entity = PlayerEntity.new(player, character)
	PlayerService._entities[userId] = entity

	EventBus:Publish("PlayerReady", player, entity)
	log:Info("PlayerEntity cree pour", player.Name)
end

function	PlayerService:GetEntity(player: Player): any?
	return PlayerService._entities[player.UserId]
end

-- Raccourci pratique : donnee persistante (attend le chargement si besoin, voir DataService:Get)
function	PlayerService:GetData(player: Player): { [any]: any }
	return DataService:Get(player)
end

function	PlayerService:Init()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)

		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local entity = PlayerService._entities[player.UserId]
		if entity then
			EventBus:Publish("PlayerLeaving", player, entity)
			entity:Destroy()
			PlayerService._entities[player.UserId] = nil
		end
	end)

	-- Deja connectes si le script reload en Studio
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
end

return PlayerService
