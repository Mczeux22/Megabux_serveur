--[[
	Author      : Lopapon
	Module      : Server/Services/InventoryService
	Description : Gere les armes EQUIPEES pour la run en cours (etat runtime, plafonne
	              a MAX_WEAPON_SLOTS). Distinct de DataService.UnlockedWeapons qui est
	              la liste persistante de ce que le joueur a le droit d'equiper.
	              Auto-equipe une arme de depart au spawn du personnage.
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local PlayerService = require(script.Parent.PlayerService)

local log = Logger.new("InventoryService")

-- ==========================
-- CONFIG
-- ==========================
local MAX_WEAPON_SLOTS = 6
local STARTER_WEAPON = "Dagger" -- a terme : lu depuis HeroConfig[hero].StarterWeapon

local InventoryService = {}

-- userId -> { weaponId, ... }
InventoryService._equipped = {} :: { [number]: { string } }

function InventoryService:GetEquippedWeapons(player: Player): { string }
	return InventoryService._equipped[player.UserId] or {}
end

-- Equipe une arme si elle est debloquee et qu'il reste de la place. Retourne true si succes.
function InventoryService:EquipWeapon(player: Player, weaponId: string): boolean
	local data = PlayerService:GetData(player)
	local isUnlocked = false
	for _, unlockedId in ipairs(data.UnlockedWeapons or {}) do
		if unlockedId == weaponId then
			isUnlocked = true
			break
		end
	end
	if not isUnlocked and weaponId ~= STARTER_WEAPON then
		log:Warn(player.Name, "a tente d'equiper une arme non debloquee :", weaponId)
		return false
	end

	local equipped = InventoryService._equipped[player.UserId]
	if not equipped then
		equipped = {}
		InventoryService._equipped[player.UserId] = equipped
	end

	if table.find(equipped, weaponId) then
		return false -- deja equipee
	end
	if #equipped >= MAX_WEAPON_SLOTS then
		log:Warn(player.Name, "a atteint le nombre max d'armes equipees")
		return false
	end

	table.insert(equipped, weaponId)
	EventBus:Publish("WeaponEquipped", player, weaponId)
	return true
end

function InventoryService:UnequipWeapon(player: Player, weaponId: string)
	local equipped = InventoryService._equipped[player.UserId]
	if not equipped then
		return
	end
	local index = table.find(equipped, weaponId)
	if index then
		table.remove(equipped, index)
		EventBus:Publish("WeaponUnequipped", player, weaponId)
	end
end

function InventoryService:Init()
	EventBus:Subscribe("PlayerReady", function(player, _entity)
		InventoryService._equipped[player.UserId] = {}
		InventoryService:EquipWeapon(player, STARTER_WEAPON)
	end)

	EventBus:Subscribe("PlayerLeaving", function(player, _entity)
		InventoryService._equipped[player.UserId] = nil
	end)
end

return InventoryService