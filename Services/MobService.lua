--[[
	Author      : Lopapon
	Module      : Server/Services/MobService
	Description : Registre GLOBAL (toutes runs confondues) des MobEntity actifs.
	              Distinct de SpawnService (qui gere les mobs PAR run) -- utile
	              pour du monitoring/debug (nombre total de mobs simultanes sur le
	              serveur) et comme point d'entree unique si un systeme a besoin
	              de retrouver un MobEntity a partir de son Instance clonee sans
	              connaitre son runId.
	Usage : local mob = MobService:GetMobFromInstance(someModel)
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local EventBus = require(script.Parent.Parent.Core.EventBus)

local log = Logger.new("MobService")

local MobService = {}

-- Instance (Model clone) -> MobEntity
MobService._byInstance = {} :: { [Instance]: any }

-- Retrouve le MobEntity proprietaire d'une instance clonee (ex: depuis un hit de projectile)
function MobService:GetMobFromInstance(instance: Instance): any?
	return MobService._byInstance[instance]
end

function MobService:GetActiveMobCount(): number
	local count = 0
	for _ in pairs(MobService._byInstance) do
		count += 1
	end
	return count
end

function MobService:Init()
	EventBus:Subscribe("MobSpawned", function(_runId, mob)
		if mob.Instance then
			MobService._byInstance[mob.Instance] = mob
		end
	end)

	EventBus:Subscribe("MobDied", function(_runId, mob)
		if mob.Instance then
			MobService._byInstance[mob.Instance] = nil
		end
	end)
end

return MobService