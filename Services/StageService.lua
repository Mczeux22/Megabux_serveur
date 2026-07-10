--[[
	Author      : Lopapon
	Module      : Server/Services/StageService
	Description : Gere la progression temporelle d'une run (temps ecoule, numero de stage).
	              Instanciable : une instance par run. Respecte le FreezeService associe
	              (le temps ne s'ecoule pas pendant un freeze).
	Usage : local stage = StageService.new(runId, freezeService)
	        stage:Start()
	        stage.StageAdvanced:Connect(function(stageIndex) ... end)
	        stage:Stop()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)

local Logger = require(script.Parent.Parent.Core.Logger)

-- Duree d'un stage en secondes (a tuner) -- ex: nouveau palier de mobs toutes les 60s
local STAGE_DURATION = 60

local StageService = {}
StageService.__index = StageService

function StageService.new(runId: number, freezeService: any)
	local self = setmetatable({}, StageService)

	self.RunId = runId
	self.FreezeService = freezeService
	self.ElapsedTime = 0
	self.StageIndex = 1
	self.Running = false

	self.StageAdvanced = Nova.Signal.new()
	self._log = Logger.new("StageService[" .. runId .. "]")
	self._loopThread = nil :: thread?

	return self
end

function StageService:Start()
	if self.Running then
		return
	end
	self.Running = true

	self._loopThread = task.spawn(function()
		while self.Running do
			task.wait(1)

			if self.FreezeService and self.FreezeService.IsFrozen then
				continue -- le temps de la run ne bouge pas pendant un freeze
			end

			self.ElapsedTime += 1

			local expectedStage = math.floor(self.ElapsedTime / STAGE_DURATION) + 1
			if expectedStage > self.StageIndex then
				self.StageIndex = expectedStage
				self._log:Info("Stage", self.StageIndex, "atteint (", self.ElapsedTime, "s)")
				self.StageAdvanced:Fire(self.StageIndex)
			end
		end
	end)
end

function StageService:Stop()
	self.Running = false
	if self._loopThread then
		task.cancel(self._loopThread)
		self._loopThread = nil
	end
end

function StageService:GetElapsedTime(): number
	return self.ElapsedTime
end

function StageService:GetStageIndex(): number
	return self.StageIndex
end

function StageService:Destroy()
	self:Stop()
	self.StageAdvanced:DisconnectAll()
end

return StageService
