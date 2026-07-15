--[[
    Author      : Mczeux22
    Module      : Server/Services/QuestService
    Description : Gère les quêtes (progression, récompenses).
                  Intègre avec DataService pour sauvegarder l'état.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestConfig = require(ReplicatedStorage.Shared.Megabux_shared.Config.QuestConfig)

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local PlayerService = require(script.Parent.PlayerService)
local RewardService = require(script.Parent.RewardService)

local log = Logger.new("QuestService")

local QuestService = {}
QuestService._playerQuests = {} :: { [number]: { [string]: any } } -- userId -> { questId -> progress }

-- Commence une quête pour un joueur
function QuestService:StartQuest(player: Player, questId: string)
    local data = PlayerService:GetData(player)
    local userId = player.UserId

    if not QuestConfig[questId] then
        log:Warn("Quête introuvable :", questId)
        return false
    end

    -- Initialiser le tracking si nécessaire
    if not QuestService._playerQuests[userId] then
        QuestService._playerQuests[userId] = {}
    end

    -- Vérifier si la quête est déjà en cours
    if QuestService._playerQuests[userId][questId] then
        log:Warn(player.Name, "a déjà la quête", questId)
        return false
    end

    -- Initialiser la progression
    QuestService._playerQuests[userId][questId] = {
        Progress = 0,
        Required = QuestConfig[questId].Required,
        Type = QuestConfig[questId].Type,
    }

    EventBus:Publish("QuestStarted", player, questId)
    log:Info(player.Name, "a commencé la quête", questId)
    return true
end

-- Met à jour la progression d'une quête
function QuestService:UpdateQuest(player: Player, questId: string, amount: number)
    local userId = player.UserId
    if not QuestService._playerQuests[userId] or not QuestService._playerQuests[userId][questId] then
        return
    end

    local quest = QuestService._playerQuests[userId][questId]
    quest.Progress += amount

    -- Vérifier si la quête est terminée
    if quest.Progress >= quest.Required then
        QuestService:CompleteQuest(player, questId)
    else
        EventBus:Publish("QuestUpdated", player, questId, quest.Progress, quest.Required)
    end
end

-- Termine une quête et donne les récompenses
function QuestService:CompleteQuest(player: Player, questId: string)
    local userId = player.UserId
    if not QuestService._playerQuests[userId] or not QuestService._playerQuests[userId][questId] then
        return
    end

    local questConfig = QuestConfig[questId]
    if not questConfig then
        return
    end

    -- Donner les récompenses
    for _, reward in ipairs(questConfig.Rewards) do
        RewardService:ApplyReward(player, reward)
    end

    -- Nettoyer
    QuestService._playerQuests[userId][questId] = nil

    -- Sauvegarder dans DataService
    local data = PlayerService:GetData(player)
    data.CompletedQuests = data.CompletedQuests or {}
    table.insert(data.CompletedQuests, questId)

    EventBus:Publish("QuestCompleted", player, questId)
    log:Info(player.Name, "a terminé la quête", questId)
end

-- Initialisation
function QuestService:Init()
    EventBus:Subscribe("MobDied", function(runId, mob)
        -- Exemple : Mettre à jour les quêtes de type "Tuer X mobs"
        for _, player in ipairs(require(script.Parent.RunService):GetRun(runId).Players) do
            for questId, quest in pairs(QuestService._playerQuests[player.UserId] or {}) do
                if quest.Type == "KillMobs" and quest.MobId == mob.MobId then
                    QuestService:UpdateQuest(player, questId, 1)
                end
            end
        end
    end)
end

-- Destruction
function QuestService:Destroy()
    QuestService._playerQuests = {}
end

return QuestService