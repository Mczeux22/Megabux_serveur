--[[
	Author      : Lopapon
	Module      : Server/Systems/HitboxSystem
	Description : Detection de cibles dans une zone (rayon autour d'un point), filtrees
	              par tag CollectionService (ex: "Enemy"). Utilitaire pur, pas d'etat,
	              pas de boucle propre -- appele a la demande par CombatSystem ou par
	              les futures armes (WeaponService/AbilityService).
	Usage : local mobs = HitboxSystem:GetHumanoidsInRadius(position, 10, "Enemy")
]]

local CollectionService = game:GetService("CollectionService")

local Logger = require(script.Parent.Parent.Core.Logger)
local log = Logger.new("HitboxSystem")

local HitboxSystem = {}

-- Retourne les Model taggues dans un rayon donne autour d'une position (2D, ignore Y)
function HitboxSystem:GetTargetsInRadius(position: Vector3, radius: number, tag: string): { Model }
	local results = {}

	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		if instance:IsA("Model") then
			local rootPart = instance.PrimaryPart or instance:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local dx = rootPart.Position.X - position.X
				local dz = rootPart.Position.Z - position.Z
				local distance = math.sqrt(dx * dx + dz * dz)
				if distance <= radius then
					table.insert(results, instance)
				end
			end
		end
	end

	return results
end

-- Meme chose mais retourne directement les Humanoid (pratique pour DamageSystem)
function HitboxSystem:GetHumanoidsInRadius(position: Vector3, radius: number, tag: string): { Humanoid }
	local humanoids = {}

	for _, target in ipairs(HitboxSystem:GetTargetsInRadius(position, radius, tag)) do
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			table.insert(humanoids, humanoid)
		end
	end

	return humanoids
end

-- Verifie si une cible precise (Model) est dans le rayon -- evite un scan complet
-- quand on a deja une reference directe (ex: verifier la portee d'attaque d'un mob)
function HitboxSystem:IsInRange(fromPosition: Vector3, toPosition: Vector3, radius: number): boolean
	local dx = toPosition.X - fromPosition.X
	local dz = toPosition.Z - fromPosition.Z
	return math.sqrt(dx * dx + dz * dz) <= radius
end

return HitboxSystem