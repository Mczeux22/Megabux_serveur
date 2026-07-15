--[[
	Author      : Lopapon
	Module      : Data/DataService
	Description : Chargement/sauvegarde des donnees joueur.
	              Cache en memoire pendant la session, retry avec backoff sur echec DataStore,
	              save au PlayerRemoving + periodique + BindToClose.
	Usage : DataService:Get(player) -> table (attend que le chargement soit fini)
	        DataService:Set(player, key, value)
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)

local Logger = require(script.Parent.Parent.Core.Logger)
local DataTemplate = require(script.Parent.DataTemplate)
local MigrationService = require(script.Parent.MigrationService)
local BackupService = require(script.Parent.BackupService)

local log = Logger.new("DataService")

local DataService = {}

local playerStore = DataStoreService:GetDataStore("PlayerData_v1")

DataService._cache = {} :: { [number]: { [any]: any } }
DataService._loadedSignals = {} :: { [number]: any } -- Nova.Signal, fire une fois le chargement termine
DataService._SAVE_RETRIES = 3
DataService._RETRY_DELAY = 2 -- secondes, double a chaque echec

local function	attemptWithRetry(fn: () -> any, retries: number): (boolean, any)
	local delay = DataService._RETRY_DELAY
	for attempt = 1, retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		log:Warn(("Tentative %d/%d echouee : %s"):format(attempt, retries, tostring(result)))
		if attempt < retries then
			task.wait(delay)
			delay *= 2
		end
	end
	return false, nil
end

-- Charge la donnee d'un joueur (appele au PlayerAdded)
function	DataService:_load(player: Player)
	local userId = player.UserId
	if DataService._cache[userId] or DataService._loadedSignals[userId] then
		return -- deja charge ou chargement en cours
	end
	DataService._loadedSignals[userId] = Nova.Signal.new()

	local ok, raw = attemptWithRetry(function()
		return playerStore:GetAsync("Player_" .. userId)
	end, DataService._SAVE_RETRIES)

	local data: { [any]: any }

	if not ok then
		log:Error("Impossible de charger les donnees de", player.Name, "- utilisation d'un template vide (risque de perte)")
		data = DataTemplate.new()
	elseif raw == nil then
		log:Info("Nouveau joueur :", player.Name)
		data = DataTemplate.new()
	else
		data = MigrationService.Migrate(raw, DataTemplate.Version)
	end

	DataService._cache[userId] = data
	DataService._loadedSignals[userId]:Fire(data)
	log:Info("Donnees chargees pour", player.Name)
end

-- Sauvegarde la donnee d'un joueur, retourne true si succes
function	DataService:_save(player: Player): boolean
	local userId = player.UserId
	local data = DataService._cache[userId]
	if not data then
		return false
	end

	data.LastSaved = os.time()

	local ok = attemptWithRetry(function()
		playerStore:SetAsync("Player_" .. userId, data)
	end, DataService._SAVE_RETRIES)

	if ok then
		BackupService:SaveBackup(userId, data)
		log:Info("Sauvegarde OK pour", player.Name)
	else
		log:Error("SAUVEGARDE ECHOUEE pour", player.Name, "apres", DataService._SAVE_RETRIES, "tentatives")
	end

	return ok
end

-- Attend que le chargement soit termine puis retourne la donnee (bloquant via Signal:Wait)
-- Si aucun chargement n'a ete initie, on le declenche pour eviter de retourner un template vide
function	DataService:Get(player: Player): { [any]: any }
	local userId = player.UserId
	if DataService._cache[userId] then
		return DataService._cache[userId]
	end

	local signal = DataService._loadedSignals[userId]
	if signal then
		return signal:Wait()
	end

	-- Aucun chargement en cours: on le declenche maintenant (synchrone)
	log:Warn("Get() appele avant chargement pour", player.Name, "- chargement immediat")
	DataService:_load(player)

	-- _load termine (synchrone) ou garde (deja lance ailleurs)
	if DataService._cache[userId] then
		return DataService._cache[userId]
	end

	signal = DataService._loadedSignals[userId]
	if signal then
		return signal:Wait()
	end

	return DataTemplate.new()
end

function	DataService:Set(player: Player, key: string, value: any)
	local data = DataService:Get(player)
	data[key] = value
end

function	DataService:Init()
	Players.PlayerAdded:Connect(function(player)
		DataService:_load(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		DataService:_save(player)
		DataService._cache[player.UserId] = nil
		DataService._loadedSignals[player.UserId] = nil
	end)

	-- Deja connectes si le script reload en Studio pendant les tests
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			DataService:_load(player)
		end)
	end
end

function	DataService:Start()
	-- Sauvegarde periodique de securite (toutes les 5 minutes)
	task.spawn(function()
		while true do
			task.wait(300)
			for _, player in ipairs(Players:GetPlayers()) do
				DataService:_save(player)
			end
		end
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			DataService:_save(player)
		end
	end)
end

return DataService
