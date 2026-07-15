--[[
	Author      : Lopapon
	Module      : Server/Services/AbilityService
	Description : Declenche une competence active pour un joueur (cooldown propre,
	              separe des armes). Contrairement a WeaponService, rien ne tick
	              automatiquement ici -- l'activation vient d'un appel explicite
	              (plus tard : un Remote client, pas encore construit).
	              Chaque competence a son effet code en dur dans le if/elseif --
	              accepte pour 2 competences, a transformer en registre de handlers
	              si la liste grandit beaucoup (voir note en bas du fichier).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AbilityConfig = require(game.ReplicatedStorage.Shared.Megabux_shared.Config.AbilityConfig)

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local PlayerService = require(script.Parent.PlayerService)
local StatService = require(script.Parent.StatService)
local DamageSystem = require(script.Parent.Parent.Systems.DamageSystem)

local log = Logger.new("AbilityService")

local AbilityService = {}

-- userId -> { [abilityId] = lastUseTime (os.clock()) }
AbilityService._cooldowns = {} :: { [number]: { [string]: number } }

local function useHeal(player: Player, entity: any, config: any)
	DamageSystem:Heal(entity.Humanoid, config.HealAmount)
end

local function useSpeedBurst(player: Player, entity: any, config: any)
	local sourceId = "ability_SpeedBurst"
	StatService:AddModifier(player, sourceId, "Speed", config.SpeedBonusPercent, "Percent")
	task.delay(config.Duration, function()
		StatService:RemoveModifiersFromSource(player, sourceId)
	end)
end

local ABILITY_HANDLERS = {
	Heal = useHeal,
	SpeedBurst = useSpeedBurst,
}

-- Tente d'utiliser une competence. Retourne true si elle s'est declenchee.
function AbilityService:TryUseAbility(player: Player, abilityId: string): boolean
	local entity = PlayerService:GetEntity(player)
	if not entity or not entity.IsAlive then
		return false
	end

	local config = AbilityConfig[abilityId]
	local handler = ABILITY_HANDLERS[abilityId]
	if not config or not handler then
		log:Warn("Competence inconnue :", abilityId)
		return false
	end

	local userCooldowns = AbilityService._cooldowns[player.UserId]
	if not userCooldowns then
		userCooldowns = {}
		AbilityService._cooldowns[player.UserId] = userCooldowns
	end

	local now = os.clock()
	local lastUse = userCooldowns[abilityId] or 0
	if now - lastUse < config.Cooldown then
		return false
	end
	userCooldowns[abilityId] = now

	handler(player, entity, config)

	EventBus:Publish("AbilityUsed", player, abilityId)
	log:Info(player.Name, "utilise", abilityId)
	return true
end

function AbilityService:Init()
	EventBus:Subscribe("PlayerLeaving", function(player, _entity)
		AbilityService._cooldowns[player.UserId] = nil
	end)
end

return AbilityService

--[[
	Note evolutivite : si tu ajoutes beaucoup de competences avec des effets varies,
	remplace ABILITY_HANDLERS par un dossier Server/Abilities/<Id>.lua auto-discover
	(meme pattern que ServiceManager), pour rester 100% registry/factory sans jamais
	toucher a ce fichier.
]]