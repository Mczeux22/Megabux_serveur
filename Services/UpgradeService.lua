--[[
	Author      : Lopapon
	Module      : Server/Services/UpgradeService
	Description : Genere les choix d'upgrade proposes a un joueur a chaque levelup
	              (ecoute "PlayerLeveledUp" publie par LevelSystem) et applique le
	              choix du joueur via StatService (modificateur permanent pour la
	              run, source = "upgrade_<Id>_<stack>"). Previent LevelSystem via
	              :CompleteLevelUp() une fois le choix effectue, ce qui degele la
	              run si tous les joueurs en attente ont valide.
	              Le declenchement de ChooseUpgrade viendra plus tard d'un Remote
	              cote client (UpgradeRemote, pas encore construit) -- point
	              d'accroche pret, meme logique que AbilityService:TryUseAbility.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)
local UpgradeConfig = require(game.ReplicatedStorage.Shared.Megabux_shared.Config.UpgradeConfig)

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local StatService = require(script.Parent.StatService)
local LevelSystem = require(script.Parent.Parent.Systems.LevelSystem)

local log = Logger.new("UpgradeService")

local CHOICES_PER_LEVELUP = 3

local UpgradeService = {}

-- userId -> { UpgradeId, ... } (choix actuellement proposes, en attente de validation)
UpgradeService._offered = {} :: { [number]: { string } }

-- userId -> { [upgradeId] = stackCount }
UpgradeService._stacks = {} :: { [number]: { [string]: number } }

local function getStacks(userId: number)
	local stacks = UpgradeService._stacks[userId]
	if not stacks then
		stacks = {}
		UpgradeService._stacks[userId] = stacks
	end
	return stacks
end

-- Ne garde que les upgrades qui n'ont pas atteint leur MaxStacks pour ce joueur
local function getEligibleUpgrades(userId: number): { any }
	local stacks = getStacks(userId)
	local eligible = {}
	for _, entry in ipairs(UpgradeConfig.GetAll()) do
		local currentStacks = stacks[entry.Id] or 0
		if currentStacks < entry.MaxStacks then
			table.insert(eligible, entry)
		end
	end
	return eligible
end

-- Tire N choix distincts parmi les upgrades eligibles (peut retourner moins de N
-- si le joueur a deja tout maxe)
local function rollChoices(userId: number, count: number): { any }
	local eligible = Nova.Table.shuffle(getEligibleUpgrades(userId))
	local choices = {}
	for i = 1, math.min(count, #eligible) do
		table.insert(choices, eligible[i])
	end
	return choices
end

-- Genere et publie les choix d'upgrade pour un joueur venant de level up
function UpgradeService:OfferUpgrades(player: Player)
	local choices = rollChoices(player.UserId, CHOICES_PER_LEVELUP)

	if #choices == 0 then
		-- plus rien a proposer (tout maxe) -- on ne bloque pas le joueur pour rien
		log:Info(player.Name, "a maxe tous les upgrades disponibles, degel immediat")
		LevelSystem:CompleteLevelUp(player)
		return
	end

	local ids = {}
	for _, entry in ipairs(choices) do
		table.insert(ids, entry.Id)
	end
	UpgradeService._offered[player.UserId] = ids

	EventBus:Publish("UpgradesOffered", player, choices)
	log:Info(player.Name, "recoit", #choices, "choix d'upgrade")
end

-- Applique l'upgrade choisi par le joueur. Retourne true si le choix etait valide.
function UpgradeService:ChooseUpgrade(player: Player, upgradeId: string): boolean
	local offered = UpgradeService._offered[player.UserId]
	if not offered or not table.find(offered, upgradeId) then
		log:Warn(player.Name, "a tente de choisir un upgrade non propose :", upgradeId)
		return false
	end

	local entry = UpgradeConfig[upgradeId]
	if not entry then
		return false
	end

	local stacks = getStacks(player.UserId)
	local currentStacks = (stacks[upgradeId] or 0) + 1
	stacks[upgradeId] = currentStacks

	local sourceId = ("upgrade_%s_%d"):format(upgradeId, currentStacks)
	StatService:AddModifier(player, sourceId, entry.Stat, entry.Value, entry.Type)

	UpgradeService._offered[player.UserId] = nil

	EventBus:Publish("UpgradeChosen", player, upgradeId, currentStacks)
	log:Info(player.Name, "choisit", upgradeId, "(stack", currentStacks, ")")

	LevelSystem:CompleteLevelUp(player)

	return true
end

-- Reinitialise les stacks d'un joueur (nouvelle run -- les upgrades ne sont jamais persistants)
function UpgradeService:ResetStacks(player: Player)
	UpgradeService._stacks[player.UserId] = nil
	UpgradeService._offered[player.UserId] = nil
end

function UpgradeService:Init()
	EventBus:Subscribe("PlayerLeveledUp", function(player, _newLevel)
		UpgradeService:OfferUpgrades(player)
	end)

	EventBus:Subscribe("RunStarted", function(_runId, players)
		for _, player in ipairs(players) do
			UpgradeService:ResetStacks(player)
		end
	end)

	EventBus:Subscribe("PlayerLeaving", function(player, _entity)
		UpgradeService._stacks[player.UserId] = nil
		UpgradeService._offered[player.UserId] = nil
	end)
end

return UpgradeService