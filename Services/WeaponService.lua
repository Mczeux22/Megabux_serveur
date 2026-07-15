--[[
	Author      : Lopapon
	Module      : Server/Services/WeaponService
	Description : Declenche une arme pour un joueur : verifie le cooldown, trouve les
	              cibles via HitboxSystem, applique les degats via DamageSystem.
	              Le TIMING (quand appeler TryFireWeapon) est gere par AutoCombatSystem,
	              pas ici -- meme separation que SpawnService/SpawnSystem.
	              Le bonus de degats vient de StatService (stat "Damage" du joueur).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)
local WeaponConfig = require(game.ReplicatedStorage.Shared.Megabux_shared.Config.WeaponConfig)

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local PlayerService = require(script.Parent.PlayerService)
local StatService = require(script.Parent.StatService)
local HitboxSystem = require(script.Parent.Parent.Systems.HitboxSystem)
local DamageSystem = require(script.Parent.Parent.Systems.DamageSystem)

local log = Logger.new("WeaponService")

local ENEMY_TAG = "Enemy"

local WeaponService = {}

-- userId -> { [weaponId] = lastFireTime (os.clock()) }
WeaponService._cooldowns = {} :: { [number]: { [string]: number } }

-- Ne garde que la cible la plus proche parmi une liste de Humanoid
local function keepNearestOnly(humanoids: { Humanoid }, fromPosition: Vector3): { Humanoid }
	local nearest: Humanoid? = nil
	local nearestDistance = math.huge

	for _, humanoid in ipairs(humanoids) do
		local rootPart = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			local distance = Nova.Math.distance2D(fromPosition, rootPart.Position)
			if distance < nearestDistance then
				nearestDistance = distance
				nearest = humanoid
			end
		end
	end

	return nearest and { nearest } or {}
end

-- Tente de declencher une arme pour un joueur. Retourne true si elle a bien tire
-- (meme si elle n'a touche personne -- le cooldown demarre quand meme).
function WeaponService:TryFireWeapon(player: Player, weaponId: string): boolean
	local entity = PlayerService:GetEntity(player)
	if not entity or not entity.IsAlive or not entity.RootPart then
		return false
	end

	local config = WeaponConfig[weaponId]
	if not config then
		log:Warn("WeaponConfig introuvable pour", weaponId)
		return false
	end

	local userCooldowns = WeaponService._cooldowns[player.UserId]
	if not userCooldowns then
		userCooldowns = {}
		WeaponService._cooldowns[player.UserId] = userCooldowns
	end

	local now = os.clock()
	local lastFire = userCooldowns[weaponId] or 0
	if now - lastFire < config.Cooldown then
		return false
	end
	userCooldowns[weaponId] = now

	local bonusDamage = StatService:GetStat(player, "Damage")
	local finalDamage = config.Damage + bonusDamage

	local targets = HitboxSystem:GetHumanoidsInRadius(entity.RootPart.Position, config.Range, ENEMY_TAG)
	if config.Type == "Nearest" then
		targets = keepNearestOnly(targets, entity.RootPart.Position)
	end

	for _, humanoid in ipairs(targets) do
		DamageSystem:ApplyDamage(humanoid, finalDamage, player)
	end

	EventBus:Publish("WeaponFired", player, weaponId, #targets)
	return true
end

function WeaponService:Init()
	EventBus:Subscribe("PlayerLeaving", function(player, _entity)
		WeaponService._cooldowns[player.UserId] = nil
	end)
end

return WeaponService