--[[
	Author      : Lopapon
	Module      : Server/Services/JoinDataService
	Description : Gere la selection de map pour les joueurs qui rejoignent une run.
	             Retourne l'ID de la map associee a un joueur (par defaut "DefaultMap").
]]

local JoinDataService = {}

-- Retourne l'ID de la map pour un joueur donne.
-- Par defaut, toutes les runs utilisent "DefaultMap".
-- Tu peux etendre cette logique pour choisir une map selon des criteres (niveau, votes, etc.).
function JoinDataService:GetMapId(player: Player): string
	return "DefaultMap"
end

return JoinDataService