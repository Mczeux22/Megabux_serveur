--[[
	Author      : Lopapon
	Module      : Server/Services/ZoneService
	Description : REMPLACE StageService (a supprimer du projet). Gere la progression
	              d'une run par ZONES PHYSIQUES au lieu d'un simple timer abstrait :
	              chaque zone dure ZONE_DURATION secondes, puis la brume force
	              l'avancee et la barriere suivante s'ouvre (voir RunService:Start()
	              qui connecte ZoneAdvanced pour manipuler les instances physiques).

	              Deux compteurs de temps distincts :
	              - TotalElapsedTime : ne reset JAMAIS, sert a DifficultyService
	                (la difficulte scale sur la duree totale de la run, pas la zone)
	              - TimeInZone : reset a chaque nouvelle zone, sert au timer de brume

	Usage : local zone = ZoneService.new(runId, freezeService)
	        zone:Start()
	        zone.ZoneAdvanced:Connect(function(zoneIndex) ... end)
	        zone:Stop()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)

local Logger = require(script.Parent.Parent.Core.Logger)

-- Duree d'une zone en secondes avant que la brume force l'avancee (3 minutes)
local ZONE_DURATION = 180

local ZoneService = {}
ZoneService.__index = ZoneService

function ZoneService.new(runId: number, freezeService: any)
	local self = setmetatable({}, ZoneService)

	self.RunId = runId
	self.FreezeService = freezeService
	self.TotalElapsedTime = 0
	self.TimeInZone = 0
	self.ZoneIndex = 1
	self.Running = false

	self.ZoneAdvanced = Nova.Signal.new()
	self._log = Logger.new("ZoneService[" .. runId .. "]")
	self._loopThread = nil :: thread?

	return self
end

function ZoneService:Start()
	-- Garde: si TotalElapsedTime n'existe pas, c'est que Start est appele
	-- par le ServiceManager sur la classe (pas une instance .new()). On ignore.
	if self.TotalElapsedTime == nil then
		return
	end
	if self.Running then
		return
	end
	self.Running = true

	self._loopThread = task.spawn(function()
		while self.Running do
			task.wait(1)

			if self.FreezeService and self.FreezeService.IsFrozen then
				continue -- le temps de la run ne bouge pas pendant un freeze (levelup)
			end

			self.TotalElapsedTime += 1
			self.TimeInZone += 1

			if self.TimeInZone >= ZONE_DURATION then
				self.TimeInZone = 0
				self.ZoneIndex += 1
				self._log:Info("Zone", self.ZoneIndex, "(brume declenchee, ", self.TotalElapsedTime, "s ecoulees)")
				self.ZoneAdvanced:Fire(self.ZoneIndex)
			end
		end
	end)
end

function ZoneService:Stop()
	self.Running = false
	if self._loopThread then
		task.cancel(self._loopThread)
		self._loopThread = nil
	end
end

-- Temps total ecoule depuis le debut de la run (jamais reset) -- pour DifficultyService
function ZoneService:GetElapsedTime(): number
	return self.TotalElapsedTime
end

function ZoneService:GetZoneIndex(): number
	return self.ZoneIndex
end

function ZoneService:Destroy()
	self:Stop()
	self.ZoneAdvanced:DisconnectAll()
end

return ZoneService