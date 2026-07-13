--[[
	Author      : Lopapon
	Module      : Server/Systems/MistSystem
	Description : Ecoute "MistActivated" (publie par RunService quand une zone
	              s'ouvre) et inflige des degats periodiques a tout joueur encore
	              du mauvais cote de la barriere qui vient de s'ouvrir.
	              Detection generique par produit scalaire sur le LookVector de la
	              barriere : un joueur est "en retard" si sa position projetee est
	              derriere le plan de la barriere, peu importe l'orientation de la map.
	              Enregistre dans SystemManager -> :Update(dt) appele chaque Heartbeat.
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local DamageSystem = require(script.Parent.DamageSystem)

local log = Logger.new("MistSystem")

-- ==========================
-- CONFIG
-- ==========================
local MIST_DAMAGE_PER_TICK = 5
local MIST_TICK_INTERVAL = 1 -- secondes entre deux ticks de degats

local MistSystem = {}

-- runId -> { Run = Run, ActiveBarrier = BasePart?, Accumulator = number }
MistSystem._runData = {} :: { [number]: any }

-- Un joueur est "en retard" si sa position est du cote oppose au LookVector de la barriere
local function isPlayerBehindBarrier(rootPart: BasePart, barrier: BasePart): boolean
	local toPlayer = rootPart.Position - barrier.Position
	local dot = toPlayer:Dot(barrier.CFrame.LookVector)
	return dot < 0
end

function MistSystem:Init()
	EventBus:Subscribe("RunStarted", function(runId, players)
		local run = require(script.Parent.Parent.Services.RunService):GetRun(runId)
		if run then
			MistSystem._runData[runId] = {
				Run = run,
				ActiveBarrier = nil,
				Accumulator = 0,
			}
		end
	end)

	EventBus:Subscribe("RunEnded", function(runId)
		MistSystem._runData[runId] = nil
	end)

	EventBus:Subscribe("MistActivated", function(runId, barrier)
		local data = MistSystem._runData[runId]
		if data and barrier:IsA("BasePart") then
			data.ActiveBarrier = barrier
			data.Accumulator = 0
		end
	end)
end

function MistSystem:Update(dt: number)
	for _, data in pairs(MistSystem._runData) do
		local run = data.Run
		local barrier = data.ActiveBarrier

		if not barrier or run.Freeze.IsFrozen then
			continue
		end

		data.Accumulator += dt
		if data.Accumulator < MIST_TICK_INTERVAL then
			continue
		end
		data.Accumulator = 0

		for _, player in ipairs(run.Players) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

			if humanoid and rootPart and isPlayerBehindBarrier(rootPart, barrier) then
				DamageSystem:ApplyDamage(humanoid, MIST_DAMAGE_PER_TICK, "Mist")
			end
		end
	end
end

return MistSystem