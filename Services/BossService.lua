--[[
	Author      : Lopapon
	Module      : Server/Services/BossService
	Description : Ecoute la progression de stage de chaque run (via une connexion
	              directe a run.Stage.StageAdvanced -- pas besoin de la faire transiter
	              par l'EventBus global, on a deja la reference a la run) et invoque
	              le boss correspondant a BossConfig.TriggerStage.

	              Republie le spawn/la mort du boss sur les MEMES evenements globaux
	              que les mobs normaux (MobSpawned/MobDied) : MobAISystem, CombatSystem
	              et RewardService le traitent donc automatiquement comme un mob, sans
	              aucune modification de leur part. BossSpawned/BossDied sont des
	              evenements EN PLUS, pour les futurs hooks specifiques (UI barre de
	              vie de boss, musique, etc.).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)
local BossConfig = require(ReplicatedStorage.Shared.Config.BossConfig)

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local BossEntity = require(script.Parent.Parent.Entities.BossEntity)

local log = Logger.new("BossService")

local BossService = {}

-- runId -> { Run = Run, SpawnedBossIds = { [string]: true }, ActiveBoss = BossEntity? }
BossService._runData = {} :: { [number]: any }

-- Point de spawn dedie si la map en a un ("BossSpawnPoint"), sinon pres d'un joueur au hasard
local function pickBossSpawnPosition(run: any): CFrame?
	local mapClone = run.MapClone
	local spawnPoint = mapClone and mapClone:FindFirstChild("BossSpawnPoint")
	if spawnPoint and spawnPoint:IsA("BasePart") then
		return spawnPoint.CFrame
	end

	if #run.Players == 0 then
		return nil
	end

	local targetPlayer = run.Players[Nova.Math.randomInt(1, #run.Players)]
	local character = targetPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return nil
	end

	return CFrame.new(rootPart.Position + Vector3.new(0, 0, -30))
end

function BossService:CheckStageForBoss(runId: number, stageIndex: number)
	local data = BossService._runData[runId]
	if not data or data.ActiveBoss then
		return -- deja un boss actif sur cette run, pas de double spawn
	end

	local bossConfigEntry = BossConfig.GetBossForStage(stageIndex)
	if not bossConfigEntry then
		return
	end
	if data.SpawnedBossIds[bossConfigEntry.Id] then
		return -- deja spawn cette run (evite un re-trigger si le stage est relu)
	end

	local spawnCFrame = pickBossSpawnPosition(data.Run)
	if not spawnCFrame then
		return
	end

	local boss = BossEntity.new(bossConfigEntry, spawnCFrame, data.Run.MapClone, runId)
	if not boss then
		return
	end

	data.SpawnedBossIds[bossConfigEntry.Id] = true
	data.ActiveBoss = boss

	EventBus:Publish("MobSpawned", runId, boss) -- MobAISystem/CombatSystem le prennent en charge
	EventBus:Publish("BossSpawned", runId, boss)

	boss.Died:Connect(function()
		EventBus:Publish("MobDied", runId, boss) -- RewardService distribue XP/Gold automatiquement
	end)

	log:Info("Boss", bossConfigEntry.Id, "invoque (run", runId, ", stage", stageIndex, ")")
end

function BossService:Init()
	EventBus:Subscribe("RunStarted", function(runId, _players)
		local run = require(script.Parent.RunService):GetRun(runId)
		if not run then
			return
		end

		BossService._runData[runId] = {
			Run = run,
			SpawnedBossIds = {},
			ActiveBoss = nil,
		}

		-- StageAdvanced est un Nova.Signal propre a l'instance StageService de la run.
		-- Sa cleanup est deja geree par run.Maid (StageService:Destroy() a la fin de run),
		-- pas besoin de gerer cette connexion manuellement ici.
		run.Stage.StageAdvanced:Connect(function(stageIndex)
			BossService:CheckStageForBoss(runId, stageIndex)
		end)
	end)

	EventBus:Subscribe("RunEnded", function(runId)
		local data = BossService._runData[runId]
		if data and data.ActiveBoss then
			data.ActiveBoss:Destroy()
		end
		BossService._runData[runId] = nil
	end)

	EventBus:Subscribe("MobDied", function(runId, mob)
		local data = BossService._runData[runId]
		if data and data.ActiveBoss == mob then
			data.ActiveBoss = nil
			EventBus:Publish("BossDied", runId, mob)
			log:Info("Boss", mob.MobId, "vaincu (run", runId, ")")
		end
	end)
end

return BossService