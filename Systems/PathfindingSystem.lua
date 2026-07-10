--[[
	Author      : Lopapon
	Module      : Server/Systems/PathfindingSystem
	Description : Calcule et fait suivre un chemin a un mob vers une position cible.
	              Utilitaire pur, pas de boucle propre -- appele par MobAISystem:Update().
	              Repath periodique (pas a chaque frame, trop couteux) + fallback en
	              ligne droite si PathfindingService echoue (mob bloque, cible inaccessible).
]]

local PathfindingService = game:GetService("PathfindingService")

local Logger = require(script.Parent.Parent.Core.Logger)
local log = Logger.new("PathfindingSystem")

-- ==========================
-- CONFIG
-- ==========================
local REPATH_INTERVAL = 0.5 -- secondes entre deux recalculs de chemin
local WAYPOINT_REACHED_DISTANCE = 4
local AGENT_PARAMS = {
	AgentRadius = 3,
	AgentHeight = 6,
	AgentCanJump = false,
}

local PathfindingSystem = {}

-- mob -> { Waypoints = {Vector3}, Index = number, LastRepathTime = number }
PathfindingSystem._mobPathData = {} :: { [any]: any }

local function computeWaypoints(fromPosition: Vector3, toPosition: Vector3): { Vector3 }
	local path = PathfindingService:CreatePath(AGENT_PARAMS)

	local ok = pcall(function()
		path:ComputeAsync(fromPosition, toPosition)
	end)

	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = {}
		for _, waypoint in ipairs(path:GetWaypoints()) do
			table.insert(waypoints, waypoint.Position)
		end
		return waypoints
	end

	-- Fallback : ligne droite si le pathfinding echoue (cible trop loin, bloquee, etc.)
	return { toPosition }
end

-- Met a jour le mouvement d'un mob vers une cible. A appeler chaque frame pour un mob actif.
function PathfindingSystem:UpdateMobMovement(mob: any, targetPosition: Vector3)
	if not mob.RootPart or not mob.Humanoid then
		return
	end

	local data = PathfindingSystem._mobPathData[mob]
	local now = os.clock()

	if not data or (now - data.LastRepathTime) >= REPATH_INTERVAL then
		local waypoints = computeWaypoints(mob.RootPart.Position, targetPosition)
		data = {
			Waypoints = waypoints,
			Index = 1,
			LastRepathTime = now,
		}
		PathfindingSystem._mobPathData[mob] = data
	end

	local currentWaypoint = data.Waypoints[data.Index]
	if not currentWaypoint then
		return
	end

	if (mob.RootPart.Position - currentWaypoint).Magnitude <= WAYPOINT_REACHED_DISTANCE then
		data.Index = math.min(data.Index + 1, #data.Waypoints)
		currentWaypoint = data.Waypoints[data.Index]
	end

	mob.Humanoid:MoveTo(currentWaypoint)
end

-- A appeler quand un mob meurt/est detruit, pour eviter les fuites memoire
function PathfindingSystem:ClearMob(mob: any)
	PathfindingSystem._mobPathData[mob] = nil
end

return PathfindingSystem