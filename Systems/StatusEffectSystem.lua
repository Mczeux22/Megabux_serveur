--[[
	Author      : Lopapon
	Module      : Server/Systems/StatusEffectSystem
	Description : Applique et suit les effets de statut sur une entite (Player ou Mob).
	              3 types geres : Poison (degats sur la duree), Slow (vitesse reduite),
	              Stun (immobilise + entity.IsStunned = true, lu par MobAISystem/CombatSystem).
	              Un seul effet actif par type et par entite : reappliquer le meme type
	              rafraichit sa duree/valeur plutot que d'empiler (pas de vrai stacking pour l'instant).
	              Enregistre dans SystemManager -> :Update(dt) appele chaque Heartbeat.
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local DamageSystem = require(script.Parent.DamageSystem)

local log = Logger.new("StatusEffectSystem")

export type EffectType = "Poison" | "Slow" | "Stun"

local StatusEffectSystem = {}

-- entity -> { [EffectType] = { Duration, Value, TickInterval?, TickAccumulator?, OriginalSpeed? } }
StatusEffectSystem._entityEffects = {} :: { [any]: any }

local function getOrCreateEntry(entity: any)
	local effects = StatusEffectSystem._entityEffects[entity]
	if not effects then
		effects = {}
		StatusEffectSystem._entityEffects[entity] = effects
	end
	return effects
end

-- Poison : `value` = degats par tick, `tickInterval` = secondes entre deux ticks
function StatusEffectSystem:ApplyPoison(entity: any, duration: number, value: number, tickInterval: number)
	if not entity or not entity.Humanoid then
		return
	end
	local effects = getOrCreateEntry(entity)
	effects.Poison = {
		Duration = duration,
		Value = value,
		TickInterval = tickInterval,
		TickAccumulator = 0,
	}
end

-- Slow : `percent` entre 0 et 1 (0.3 = -30% de vitesse)
function StatusEffectSystem:ApplySlow(entity: any, duration: number, percent: number)
	if not entity or not entity.Humanoid then
		return
	end
	local effects = getOrCreateEntry(entity)

	if not effects.Slow then
		effects.Slow = { OriginalSpeed = entity.Humanoid.WalkSpeed }
	end
	effects.Slow.Duration = duration
	effects.Slow.Value = percent
	entity.Humanoid.WalkSpeed = effects.Slow.OriginalSpeed * (1 - percent)
end

-- Stun : bloque le mouvement, `entity.IsStunned` lu par MobAISystem/CombatSystem pour ignorer l'entite
function StatusEffectSystem:ApplyStun(entity: any, duration: number)
	if not entity or not entity.Humanoid then
		return
	end
	local effects = getOrCreateEntry(entity)

	if not effects.Stun then
		effects.Stun = { OriginalSpeed = entity.Humanoid.WalkSpeed }
	end
	effects.Stun.Duration = duration
	entity.Humanoid.WalkSpeed = 0
	entity.IsStunned = true
end

local function clearEffect(entity: any, effects: any, effectType: EffectType)
	if effectType == "Slow" then
		entity.Humanoid.WalkSpeed = effects.Slow.OriginalSpeed
	elseif effectType == "Stun" then
		entity.Humanoid.WalkSpeed = effects.Stun.OriginalSpeed
		entity.IsStunned = false
	end
	effects[effectType] = nil
end

-- Retire tous les effets d'une entite d'un coup (mort, fin de run)
function StatusEffectSystem:ClearEntity(entity: any)
	local effects = StatusEffectSystem._entityEffects[entity]
	if not effects or not entity.Humanoid then
		StatusEffectSystem._entityEffects[entity] = nil
		return
	end

	for effectType in pairs(effects) do
		clearEffect(entity, effects, effectType)
	end
	StatusEffectSystem._entityEffects[entity] = nil
end

function StatusEffectSystem:Init()
	-- Nettoyage automatique a la mort, evite les fuites + les WalkSpeed corrompus
	EventBus:Subscribe("MobDied", function(_runId, mob)
		StatusEffectSystem:ClearEntity(mob)
	end)

	EventBus:Subscribe("PlayerLeaving", function(_player, entity)
		StatusEffectSystem:ClearEntity(entity)
	end)
end

function StatusEffectSystem:Update(dt: number)
	for entity, effects in pairs(StatusEffectSystem._entityEffects) do
		if not entity.IsAlive or not entity.Humanoid then
			StatusEffectSystem._entityEffects[entity] = nil
			continue
		end

		for effectType, data in pairs(effects) do
			data.Duration -= dt

			if effectType == "Poison" then
				data.TickAccumulator += dt
				if data.TickAccumulator >= data.TickInterval then
					data.TickAccumulator = 0
					DamageSystem:ApplyDamage(entity.Humanoid, data.Value, "Poison")
				end
			end

			if data.Duration <= 0 then
				clearEffect(entity, effects, effectType)
			end
		end

		if next(effects) == nil then
			StatusEffectSystem._entityEffects[entity] = nil
		end
	end
end

return StatusEffectSystem