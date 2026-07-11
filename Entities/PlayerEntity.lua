--[[
	Author      : Lopapon
	Module      : Server/Entities/PlayerEntity
	Description : Wrapper runtime autour d'un Player -- etat de run (HP, XP, Kills, RunLevel),
	              distinct de PersistentData (DataService). Cree au CharacterAdded,
	              detruit au CharacterRemoving/PlayerRemoving.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)

local Entity = require(script.Parent.Entity)

local PlayerEntity = setmetatable({}, { __index = Entity })
PlayerEntity.__index = PlayerEntity

function	PlayerEntity.new(player: Player, character: Model)
	local self = setmetatable(Entity.new(character), PlayerEntity)

	self.Player = player
	self.Character = character
	self.Humanoid = character:WaitForChild("Humanoid") :: Humanoid
	self.RootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	-- Etat runtime de run (reset a chaque run, pas sauvegarde)
	self.InRun = false
	self.RunId = nil :: number?
	self.CurrentXP = 0
	self.RunLevel = 1
	self.Kills = 0

	self.HealthChanged = Nova.Signal.new()
	self.Maid:GiveTask(function()
		self.HealthChanged:DisconnectAll()
	end)

	self.Maid:GiveTask(self.Humanoid.HealthChanged:Connect(function(newHealth)
		self.HealthChanged:Fire(newHealth, self.Humanoid.MaxHealth)
		if newHealth <= 0 then
			self:Kill()
		end
	end))

	-- Le Died herite d'Entity se declenche deja via :Kill(), mais on veut
	-- aussi capter la mort "brutale" (chute, kill admin) qui ne passe pas par nous
	self.Maid:GiveTask(self.Humanoid.Died:Connect(function()
		self:Kill()
	end))

	return self
end

function	PlayerEntity:GainXP(amount: number)
	self.CurrentXP += amount
end

function	PlayerEntity:AddKill()
	self.Kills += 1
end

function	PlayerEntity:EnterRun(runId: number)
	self.InRun = true
	self.RunId = runId
	self.CurrentXP = 0
	self.RunLevel = 1
	self.Kills = 0
end

function	PlayerEntity:ExitRun()
	self.InRun = false
	self.RunId = nil
end

function	PlayerEntity:Destroy()
	Entity.Destroy(self)
end

return PlayerEntity