--[[
	Author      : Lopapon
	Module      : Server/Systems/KnockbackSystem
	Description : Applique une impulsion physique temporaire (BodyVelocity) sur un
	              RootPart. Annule proprement tout knockback en cours sur la meme
	              cible avant d'en appliquer un nouveau (evite l'empilement de forces).
	Usage : KnockbackSystem:ApplyKnockback(rootPart, direction, 50, 0.3)
]]

local Logger = require(script.Parent.Parent.Core.Logger)
local log = Logger.new("KnockbackSystem")

local KNOCKBACK_NAME = "CombatKnockback"

local KnockbackSystem = {}

-- rootPart -> thread (le task.delay de cleanup en cours, pour pouvoir l'annuler)
KnockbackSystem._activeKnockbacks = {} :: { [BasePart]: thread }

function KnockbackSystem:ApplyKnockback(rootPart: BasePart?, direction: Vector3, force: number, duration: number)
	if not rootPart then
		return
	end

	-- Annule le knockback precedent sur cette cible s'il y en a un
	local existingThread = KnockbackSystem._activeKnockbacks[rootPart]
	if existingThread then
		task.cancel(existingThread)
	end
	local existingVelocity = rootPart:FindFirstChild(KNOCKBACK_NAME)
	if existingVelocity then
		existingVelocity:Destroy()
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude == 0 then
		return
	end
	flatDirection = flatDirection.Unit

	local velocity = Instance.new("BodyVelocity")
	velocity.Name = KNOCKBACK_NAME
	velocity.MaxForce = Vector3.new(math.huge, 0, math.huge) -- pas d'impact vertical
	velocity.Velocity = flatDirection * force
	velocity.Parent = rootPart

	KnockbackSystem._activeKnockbacks[rootPart] = task.delay(duration, function()
		if velocity and velocity.Parent then
			velocity:Destroy()
		end
		KnockbackSystem._activeKnockbacks[rootPart] = nil
	end)
end

-- A appeler si une cible est detruite pendant son knockback, pour eviter une erreur silencieuse
function KnockbackSystem:CancelKnockback(rootPart: BasePart?)
	if not rootPart then
		return
	end
	local existingThread = KnockbackSystem._activeKnockbacks[rootPart]
	if existingThread then
		task.cancel(existingThread)
		KnockbackSystem._activeKnockbacks[rootPart] = nil
	end
end

return KnockbackSystem