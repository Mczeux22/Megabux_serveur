--[[
	Author      : Lopapon
	Module      : Server/Systems/AutoCombatSystem
	Description : Auto-declenche les armes equipees de chaque joueur en run (pas de
	              visee manuelle, style bullet-heaven). Meme pattern d'enregistrement
	              que MobAISystem/CombatSystem (RunStarted/RunEnded via EventBus).
	              Respecte FreezeService (pas d'attaque pendant un levelup).
	              Enregistre dans SystemManager -> :Update(dt) appele chaque Heartbeat.
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local InventoryService = require(script.Parent.Parent.Services.InventoryService)
local WeaponService = require(script.Parent.Parent.Services.WeaponService)

local log = Logger.new("AutoCombatSystem")

local AutoCombatSystem = {}

-- runId -> Run
AutoCombatSystem._runs = {} :: { [number]: any }

function AutoCombatSystem:Init()
	EventBus:Subscribe("RunStarted", function(runId, players)
		local run = require(script.Parent.Parent.Services.RunService):GetRun(runId)
		if run then
			AutoCombatSystem._runs[runId] = run
		end
	end)

	EventBus:Subscribe("RunEnded", function(runId)
		AutoCombatSystem._runs[runId] = nil
	end)
end

function AutoCombatSystem:Update(dt: number)
	for _, run in pairs(AutoCombatSystem._runs) do
		if run.Freeze.IsFrozen then
			continue
		end

		for _, player in ipairs(run.Players) do
			local equippedWeapons = InventoryService:GetEquippedWeapons(player)
			for _, weaponId in ipairs(equippedWeapons) do
				WeaponService:TryFireWeapon(player, weaponId)
			end
		end
	end
end

return AutoCombatSystem