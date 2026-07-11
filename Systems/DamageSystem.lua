--[[
	Author      : Lopapon
	Module      : Server/Systems/DamageSystem
	Description : Point d'entree UNIQUE pour infliger des degats, que la cible soit
	              un joueur ou un mob (marche sur n'importe quel Humanoid). La mort
	              est deja geree automatiquement par Entity/PlayerEntity/MobEntity
	              via Humanoid.Died -> :Kill() -- ce module ne s'en occupe pas.
	              Publie "EntityDamaged" sur l'EventBus pour les hooks VFX/UI cote client.

	              Point d'extension futur : c'est ICI qu'il faudra brancher les
	              reductions de degats (armure, resistances) une fois ces stats definies.
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)

local log = Logger.new("DamageSystem")

local DamageSystem = {}

-- Inflige des degats a un Humanoid. `source` est libre (mob, player, nil) -- sert
-- surtout au tracking de kill (RewardService plus tard) et au debug.
function DamageSystem:ApplyDamage(humanoid: Humanoid?, amount: number, source: any?): boolean
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if amount <= 0 then
		return false
	end

	humanoid:TakeDamage(amount)

	EventBus:Publish("EntityDamaged", humanoid, amount, source)
	return true
end

-- Soigne un Humanoid (utile pour les futurs items/spells de heal), clamp au MaxHealth
function DamageSystem:Heal(humanoid: Humanoid?, amount: number)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	EventBus:Publish("EntityHealed", humanoid, amount)
end

return DamageSystem