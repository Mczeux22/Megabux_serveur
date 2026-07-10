--[[
	Author      : Lopapon
	Module      : Server/Services/DifficultyService
	Description : Calcul stateless de la difficulte d'une run.
	              Pas d'etat interne : prend le temps ecoule + nb joueurs en entree,
	              retourne un multiplicateur. Reutilisable par n'importe quelle run
	              sans risque de collision d'etat entre instances simultanees.
]]

local DifficultyService = {}

-- Reglages de base (a tuner selon le ressenti en jeu)
local BASE_MULTIPLIER = 1.0
local TIME_SCALING_PER_MINUTE = 0.15   -- +15% par minute ecoulee
local PLAYER_SCALING_PER_EXTRA = 0.35  -- +35% de "budget" par joueur au-dela du premier

-- Multiplicateur global de difficulte (sert a scaler HP/degats/vitesse de spawn des mobs)
function DifficultyService:GetDifficultyMultiplier(elapsedSeconds: number, playerCount: number): number
	local minutesElapsed = elapsedSeconds / 60
	local timeMultiplier = 1 + (minutesElapsed * TIME_SCALING_PER_MINUTE)
	return BASE_MULTIPLIER * timeMultiplier
end

-- Multiplicateur de "budget de spawn" (combien d'ennemis en simultane) selon le nb de joueurs
function DifficultyService:GetSpawnBudgetMultiplier(playerCount: number): number
	playerCount = math.max(1, playerCount)
	return 1 + ((playerCount - 1) * PLAYER_SCALING_PER_EXTRA)
end

-- Combine les deux en un seul multiplicateur pratique pour SpawnService plus tard
function DifficultyService:GetCombinedMultiplier(elapsedSeconds: number, playerCount: number): number
	return DifficultyService:GetDifficultyMultiplier(elapsedSeconds, playerCount)
		* DifficultyService:GetSpawnBudgetMultiplier(playerCount)
end

return DifficultyService