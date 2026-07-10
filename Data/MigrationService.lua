--[[
	Author      : Lopapon
	Module      : Data/MigrationService
	Description : Fait passer une donnee joueur d'une ancienne version au format actuel.
	              Chaque migration est une fonction Version N -> N+1, appliquees en chaine.
	              Ajouter une migration : DataTemplate.Version += 1, puis nouvel index ici.
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local log = Logger.new("MigrationService")

local MigrationService = {}

-- Migrations[N] = fonction qui transforme la donnee de version N vers N+1
local Migrations: { [number]: (data: { [any]: any }) -> { [any]: any } } = {
	-- Exemple pour plus tard :
	-- [1] = function(data)
	-- 	data.RebirthCount = data.RebirthCount or 0
	-- 	return data
	-- end,
}

function	MigrationService.Migrate(data: { [any]: any }, targetVersion: number): { [any]: any }
	data.Version = data.Version or 0

	if data.Version == targetVersion then
		return data
	end

	if data.Version > targetVersion then
		log:Error("Donnee plus recente que le code ! Version data:", data.Version, "Version code:", targetVersion)
		return data
	end

	log:Info("Migration de", data.Version, "vers", targetVersion)

	while data.Version < targetVersion do
		local migrate = Migrations[data.Version]
		if not migrate then
			log:Error("Migration manquante pour la version", data.Version, "- arret")
			break
		end
		data = migrate(data)
		data.Version += 1
	end

	return data
end

return MigrationService