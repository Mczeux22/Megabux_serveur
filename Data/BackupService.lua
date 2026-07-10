--[[
	Author      : Lopapon
	Module      : Data/BackupService
	Description : Sauvegarde secondaire (DataStore separe) apres chaque save reussi.
	              Ne remplace jamais un save principal, sert uniquement de filet
	              pour restauration manuelle en cas de perte/corruption de donnees.
]]

local DataStoreService = game:GetService("DataStoreService")

local Logger = require(script.Parent.Parent.Core.Logger)
local log = Logger.new("BackupService")

local BackupService = {}

local backupStore = DataStoreService:GetDataStore("PlayerBackups_v1")

-- Garde N backups par joueur (rotation simple par index)
local MAX_BACKUPS = 3

function	BackupService:SaveBackup(userId: number, data: { [any]: any })
	local slot = os.time() % MAX_BACKUPS
	local key = ("%d_slot%d"):format(userId, slot)

	local ok, err = pcall(function()
		backupStore:SetAsync(key, data)
	end)

	if not ok then
		log:Warn("Echec backup pour", userId, "-", err)
	end
end

-- Restauration manuelle uniquement (commande admin, jamais auto)
function	BackupService:GetLatestBackup(userId: number): { [any]: any }?
	local latest, latestTime = nil, 0

	for slot = 0, MAX_BACKUPS - 1 do
		local key = ("%d_slot%d"):format(userId, slot)
		local ok, data = pcall(function()
			return backupStore:GetAsync(key)
		end)
		if ok and data and (data.LastSaved or 0) > latestTime then
			latest = data
			latestTime = data.LastSaved or 0
		end
	end

	return latest
end

return BackupService
