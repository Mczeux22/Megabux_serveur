--[[
	Author      : Lopapon
	Module      : Data/DataTemplate
	Description : Schema par defaut des donnees joueur + version actuelle.
	              Toute modif de structure = bump DataTemplate.Version
	              + ajout d'une migration dans MigrationService.
]]

local DataTemplate = {}

DataTemplate.Version = 1

function	DataTemplate.new()
	return {
		Version = DataTemplate.Version,

		-- Progression
		Level = 1,
		XP = 0,
		Gold = 0,

		-- Heros / Weapons debloques (IDs, pas les classes -- meme logique que HeroConfig)
		UnlockedHeroes = { "Default" },
		UnlockedWeapons = {},
		SelectedHero = "Default",

		-- Stats meta (rebirth futur)
		RebirthCount = 0,

		-- Stats de session/lifetime
		Stats = {
			RunsCompleted = 0,
			TotalKills = 0,
			BestTime = 0,
		},

		-- Timestamp de derniere sauvegarde (debug/backup)
		LastSaved = 0,
	}
end

return DataTemplate
