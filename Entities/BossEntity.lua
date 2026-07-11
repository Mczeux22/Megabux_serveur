--[[
	Author      : Lopapon
	Module      : Server/Entities/BossEntity
	Description : Herite de MobEntity (donc de Entity) -- reutilise tout : Humanoid,
	              tag CollectionService "Enemy", signal Died. Rejoue MobEntity.new
	              avec un multiplicateur de difficulte fixe a 1 (les stats de boss
	              sont deja des valeurs absolues dans BossConfig, pas besoin de scaler).
	              Ajoute uniquement le suivi de phases : PhaseChanged:Fire(phaseIndex)
	              a chaque seuil de HP franchi (BossConfig.PhaseThresholds).
	Usage : local boss = BossEntity.new(bossConfigEntry, cframe, mapParent, runId)
	        boss.PhaseChanged:Connect(function(phaseIndex) ... end)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)

local MobEntity = require(script.Parent.MobEntity)

local BossEntity = setmetatable({}, { __index = MobEntity })
BossEntity.__index = BossEntity

function BossEntity.new(bossConfigEntry: any, spawnCFrame: CFrame, mapParent: Instance?, runId: number?)
	-- difficultyMultiplier = 1 : BossConfig.BaseStats sont deja des valeurs finales
	local baseMob = MobEntity.new(bossConfigEntry, spawnCFrame, 1, mapParent, runId)
	if not baseMob then
		return nil
	end

	local self = setmetatable(baseMob, BossEntity)

	self.PhaseThresholds = bossConfigEntry.PhaseThresholds or {}
	self.CurrentPhase = 1
	self.PhaseChanged = Nova.Signal.new()
	self.Maid:GiveTask(function()
		self.PhaseChanged:DisconnectAll()
	end)

	if self.Humanoid then
		self.Maid:GiveTask(self.Humanoid.HealthChanged:Connect(function(newHealth)
			local percent = newHealth / self.Humanoid.MaxHealth
			for i, threshold in ipairs(self.PhaseThresholds) do
				local phaseIndex = i + 1
				if percent <= threshold and self.CurrentPhase < phaseIndex then
					self.CurrentPhase = phaseIndex
					self.PhaseChanged:Fire(phaseIndex)
				end
			end
		end))
	end

	return self
end

function BossEntity:Destroy()
	MobEntity.Destroy(self)
end

return BossEntity