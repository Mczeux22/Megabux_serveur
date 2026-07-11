--[[
	Author      : Lopapon
	Module      : Server/Systems/CombatSystem
	Description : Gere les attaques de melee des mobs contre les joueurs (au contact,
	              avec un cooldown par mob). Suit le meme pattern d'enregistrement que
	              MobAISystem (RunStarted/RunEnded/MobSpawned/MobDied) pour rester
	              decouple de RunService/SpawnService via l'EventBus uniquement.
	              Respecte FreezeService (pas d'attaque pendant un levelup) et
	              entity.IsStunned (pose par StatusEffectSystem).
	              Enregistre dans SystemManager -> :Update(dt) appele chaque Heartbeat.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local DamageSystem = require(script.Parent.DamageSystem)
local KnockbackSystem = require(script.Parent.KnockbackSystem)

local log = Logger.new("CombatSystem")

-- ==========================
-- CONFIG
-- ==========================
local ATTACK_RANGE = 5
local ATTACK_COOLDOWN = 1.2
local KNOCKBACK_FORCE = 35
local KNOCKBACK_DURATION = 0.2

local CombatSystem = {}

-- runId -> { Run = Run, Mobs = { MobEntity } }
CombatSystem._runData = {} :: { [number]: any }

-- mob -> accumulateur de temps depuis la derniere attaque
CombatSystem._attackTimers = {} :: { [any]: number }

-- Trouve le joueur le plus proche du mob, retourne son Player + distance (ou nil)
local function findNearestPlayer(mob: any, players: { Player }): (Player?, number)
	if not mob.RootPart then
		return nil, math.huge
	end

	local nearestPlayer: Player? = nil
	local nearestDistance = math.huge

	for _, player in ipairs(players) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			local distance = Nova.Math.distance2D(mob.RootPart.Position, rootPart.Position)
			if distance < nearestDistance then
				nearestDistance = distance
				nearestPlayer = player
			end
		end
	end

	return nearestPlayer, nearestDistance
end

local function tryAttack(mob: any, target: Player, dt: number)
	local accumulator = (CombatSystem._attackTimers[mob] or 0) + dt

	if accumulator < ATTACK_COOLDOWN then
		CombatSystem._attackTimers[mob] = accumulator
		return
	end

	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not rootPart then
		return
	end

	CombatSystem._attackTimers[mob] = 0

	DamageSystem:ApplyDamage(humanoid, mob.Damage, mob)

	local direction = rootPart.Position - mob.RootPart.Position
	KnockbackSystem:ApplyKnockback(rootPart, direction, KNOCKBACK_FORCE, KNOCKBACK_DURATION)
end

function CombatSystem:Init()
	EventBus:Subscribe("RunStarted", function(runId, players)
		local run = require(script.Parent.Parent.Services.RunService):GetRun(runId)
		if run then
			CombatSystem._runData[runId] = {
				Run = run,
				Mobs = {},
			}
		end
	end)

	EventBus:Subscribe("RunEnded", function(runId)
		CombatSystem._runData[runId] = nil
	end)

	EventBus:Subscribe("MobSpawned", function(runId, mob)
		local data = CombatSystem._runData[runId]
		if data then
			table.insert(data.Mobs, mob)
		end
	end)

	EventBus:Subscribe("MobDied", function(runId, mob)
		local data = CombatSystem._runData[runId]
		if data then
			local index = table.find(data.Mobs, mob)
			if index then
				table.remove(data.Mobs, index)
			end
		end
		CombatSystem._attackTimers[mob] = nil
	end)
end

function CombatSystem:Update(dt: number)
	for runId, data in pairs(CombatSystem._runData) do
		local run = data.Run

		if run.Freeze.IsFrozen then
			continue
		end

		for _, mob in ipairs(data.Mobs) do
			if mob.IsAlive and not mob.IsStunned then
				local target, distance = findNearestPlayer(mob, run.Players)
				if target and distance <= ATTACK_RANGE then
					tryAttack(mob, target, dt)
				end
			end
		end
	end
end

return CombatSystem