--[[
	Author      : Lopapon
	Module      : Server/Services/HeroService
	Description : Gere la selection et le deverrouillage des heros. La donnee
	              persistante (UnlockedHeroes, SelectedHero) vit dans DataService --
	              ce service ne fait que la lire/modifier et resoudre les infos
	              d'un hero via HeroConfig (Shared). Aucun etat interne : tout est
	              deja porte par le cache DataService, comme StatService le fait
	              pour les stats de run.
	Usage : HeroService:SelectHero(player, "Berserker")
	        HeroService:GetStarterWeapon(player) -- pour InventoryService plus tard
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroConfig = require(game.ReplicatedStorage.Shared.Megabux_shared.Config.HeroConfig)

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local PlayerService = require(script.Parent.PlayerService)

local log = Logger.new("HeroService")

local HeroService = {}

-- Retourne l'entree HeroConfig du hero actuellement selectionne (fallback Default
-- si la donnee est corrompue/manquante, evite un crash plutot qu'un hero invalide)
function HeroService:GetSelectedHero(player: Player): any
	local data = PlayerService:GetData(player)
	local heroId = data.SelectedHero or "Default"
	return HeroConfig[heroId] or HeroConfig.Default
end

function HeroService:IsUnlocked(player: Player, heroId: string): boolean
	local data = PlayerService:GetData(player)
	for _, unlockedId in ipairs(data.UnlockedHeroes or {}) do
		if unlockedId == heroId then
			return true
		end
	end
	return false
end

-- Change le hero selectionne s'il est deverrouille. Retourne true si succes.
function HeroService:SelectHero(player: Player, heroId: string): boolean
	if not HeroConfig[heroId] then
		log:Warn("HeroConfig introuvable pour", heroId)
		return false
	end

	if not HeroService:IsUnlocked(player, heroId) then
		log:Warn(player.Name, "a tente de selectionner un hero non debloque :", heroId)
		return false
	end

	local data = PlayerService:GetData(player)
	data.SelectedHero = heroId

	EventBus:Publish("HeroSelected", player, heroId)
	log:Info(player.Name, "selectionne le hero", heroId)
	return true
end

-- Deverrouille un hero (achat boutique, quete, rebirth...). Idempotent -- retourne
-- false si deja debloque, pour laisser l'appelant distinguer "rien fait" de "echec".
function HeroService:UnlockHero(player: Player, heroId: string): boolean
	if not HeroConfig[heroId] then
		log:Warn("HeroConfig introuvable pour", heroId)
		return false
	end

	if HeroService:IsUnlocked(player, heroId) then
		return false
	end

	local data = PlayerService:GetData(player)
	data.UnlockedHeroes = data.UnlockedHeroes or {}
	table.insert(data.UnlockedHeroes, heroId)

	EventBus:Publish("HeroUnlocked", player, heroId)
	log:Info(player.Name, "debloque le hero", heroId)
	return true
end

-- Raccourci pratique pour InventoryService (actuellement STARTER_WEAPON est en dur --
-- a remplacer par cet appel quand la selection de hero sera branchee cote UI)
function HeroService:GetStarterWeapon(player: Player): string
	return HeroService:GetSelectedHero(player).StarterWeapon
end

return HeroService