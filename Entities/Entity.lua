--[[
	Author      : Lopapon
	Module      : Server/Entities/Entity
	Description : Classe de base pour toute entite du jeu (Player, Mob, Boss).
	              Porte un Maid pour son propre cleanup + acces EventBus.
	              Les classes filles surchargent :Destroy() en appelant Entity.Destroy(self) en premier.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)
local Maid = require(script.Parent.Parent.Core.Maid)

local Entity = {}
Entity.__index = Entity

function	Entity.new(instance: Instance?)
	local self = setmetatable({}, Entity)
	self.Instance = instance
	self.Maid = Maid.new()
	self.IsAlive = true

	self.Died = Nova.Signal.new()
	self.Maid:GiveTask(function()
		self.Died:DisconnectAll()
	end)

	return self
end

function	Entity:Kill(...: any)
	if not self.IsAlive then
		return
	end
	self.IsAlive = false
	self.Died:Fire(self, ...)
end

function	Entity:Destroy()
	self.Maid:Destroy()
end

return Entity
