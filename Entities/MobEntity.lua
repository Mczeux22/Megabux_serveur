--[[
	Author      : Lopapon
	Module      : Server/Entities/MobEntity
	Description : Wrapper runtime autour d'un mob clone depuis MobConfig.
	              Applique les stats scalees par la difficulte, tag l'instance avec
	              CollectionService "Enemy" (utilise par les armes type CircleAttackWeapon),
	              et relie Humanoid.Died au signal Died herite d'Entity.
	Usage : local mob = MobEntity.new(mobConfigEntry, cframe, difficultyMultiplier, mapParent)
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Entity = require(script.Parent.Entity)

local MobEntity = setmetatable({}, { __index = Entity })
MobEntity.__index = MobEntity

local ENEMY_TAG = "Enemy"

function MobEntity.new(mobConfigEntry: any, spawnCFrame: CFrame, difficultyMultiplier: number, mapParent: Instance?, runId: number?)
	local template = ServerStorage:FindFirstChild("MobTemplates")
		and ServerStorage.MobTemplates:FindFirstChild(mobConfigEntry.Id)

	if not template then
		warn("[MobEntity] Template introuvable pour", mobConfigEntry.Id, "dans ServerStorage.MobTemplates")
		return nil
	end

	local clone = template:Clone()
	clone:PivotTo(spawnCFrame)

	local self = setmetatable(Entity.new(clone), MobEntity)

	self.MobId = mobConfigEntry.Id
	self.RunId = runId
	self.Humanoid = clone:FindFirstChildOfClass("Humanoid") :: Humanoid
	self.RootPart = clone:FindFirstChild("HumanoidRootPart") :: BasePart?

	-- Stats scalees par la difficulte (HP/degats montent avec le temps + nb joueurs)
	self.MaxHP = mobConfigEntry.BaseStats.MaxHP * difficultyMultiplier
	self.Damage = mobConfigEntry.BaseStats.Damage * difficultyMultiplier
	self.Speed = mobConfigEntry.BaseStats.Speed -- la vitesse ne scale pas, evite les mobs injouables
	self.XPReward = mobConfigEntry.BaseStats.XPReward
	self.GoldReward = mobConfigEntry.BaseStats.GoldReward

	if self.Humanoid then
		self.Humanoid.MaxHealth = self.MaxHP
		self.Humanoid.Health = self.MaxHP
		self.Humanoid.WalkSpeed = self.Speed

		self.Maid:GiveTask(self.Humanoid.Died:Connect(function()
			self:Kill()
		end))
	end

	CollectionService:AddTag(clone, ENEMY_TAG)
	self.Maid:GiveTask(function()
		CollectionService:RemoveTag(clone, ENEMY_TAG)
	end)

	clone.Parent = mapParent or workspace
	self.Maid:GiveTask(clone)

	return self
end

function MobEntity:Destroy()
	Entity.Destroy(self)
end

return MobEntity