--[[
	Author      : Lopapon
	Module      : Server/Services/NPCService
	Description : Detecte les PNJ places dans le Lobby (Model tagge "NPC" avec
	              attribut "NPCId" + ProximityPrompt), lit NPCConfig pour resoudre
	              leurs dialogues, et publie "NPCInteracted" sur l'EventBus --
	              QuestService ecoute cet event pour lancer une quete si le PNJ
	              en propose une (NPCConfig.QuestId).
	Meme pattern que ChestService (CollectionService + GetInstanceAddedSignal pour
	              supporter des PNJ ajoutes dynamiquement, pas seulement au boot).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NPCConfig = require(ReplicatedStorage.Shared.Megabux_shared.Config.NPCConfig)

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)

local log = Logger.new("NPCService")

local NPC_TAG = "NPC"

local NPCService = {}

local function onPromptTriggered(npcInstance: Instance, player: Player)
	local npcId = npcInstance:GetAttribute("NPCId")
	if not npcId then
		log:Warn("PNJ sans attribut NPCId :", npcInstance:GetFullName())
		return
	end

	local config = NPCConfig.Get(npcId)
	if not config then
		log:Warn("NPCConfig introuvable pour", npcId)
		return
	end

	EventBus:Publish("NPCInteracted", player, config)
	log:Info(player.Name, "interagit avec", npcId)
end

local function onNPCAdded(npcInstance: Instance)
	local prompt = npcInstance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		log:Warn("PNJ sans ProximityPrompt :", npcInstance:GetFullName())
		return
	end

	prompt.Triggered:Connect(function(player)
		onPromptTriggered(npcInstance, player)
	end)
end

function NPCService:Init()
	for _, npcInstance in ipairs(CollectionService:GetTagged(NPC_TAG)) do
		onNPCAdded(npcInstance)
	end

	CollectionService:GetInstanceAddedSignal(NPC_TAG):Connect(onNPCAdded)
end

return NPCService