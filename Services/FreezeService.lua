--[[
	Author      : Lopapon
	Module      : Server/Services/FreezeService
	Description : Gere le freeze-time d'une run (pause au levelup, freeze entre vagues).
	              Instanciable : une instance par run (meme pattern que l'ancien WaveService)
	              pour eviter qu'une run figee bloque les autres runs en cours.
	Usage : local freeze = FreezeService.new(runId)
	        freeze:Freeze()
	        freeze:WaitUntilUnfrozen() -- yield jusqu'au prochain :Unfreeze()
	        freeze:Unfreeze()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)

local Logger = require(script.Parent.Parent.Core.Logger)

local FreezeService = {}
FreezeService.__index = FreezeService

function FreezeService.new(runId: number)
	local self = setmetatable({}, FreezeService)

	self.RunId = runId
	self.IsFrozen = false
	self.Unfrozen = Nova.Signal.new()
	self._log = Logger.new("FreezeService[" .. runId .. "]")

	return self
end

function FreezeService:Freeze()
	if self.IsFrozen then
		return
	end
	self.IsFrozen = true
	self._log:Debug("Run gelee")
end

function FreezeService:Unfreeze()
	if not self.IsFrozen then
		return
	end
	self.IsFrozen = false
	self._log:Debug("Run degelee")
	self.Unfrozen:Fire()
end

-- Bloque le thread appelant jusqu'au prochain Unfreeze (utile pour un SpawnSystem
-- qui veut juste "attendre que ca reprenne" sans boucler sur IsFrozen)
function FreezeService:WaitUntilUnfrozen()
	if not self.IsFrozen then
		return
	end
	self.Unfrozen:Wait()
end

function FreezeService:Destroy()
	self.Unfrozen:DisconnectAll()
end

return FreezeService
