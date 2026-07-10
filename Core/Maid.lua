--[[
	Author      : Lopapon
	Module      : Core/Maid
	Description : Cleanup centralise (connections, instances, signaux, callbacks)
	              Usage : local maid = Maid.new()
	                      maid:GiveTask(someConnection)
	                      maid:GiveTask(someInstance)
	                      maid:Destroy() -- nettoie tout
]]

local Maid = {}
Maid.__index = Maid

export type Task = RBXScriptConnection | Instance | (() -> ()) | { Destroy: (any) -> () }

function	Maid.new()
	local self = setmetatable({}, Maid)
	self._tasks = {}
	return self
end

local function	cleanupOne(task: Task)
	local taskType = typeof(task)
	if taskType == "RBXScriptConnection" then
		task:Disconnect()
	elseif taskType == "Instance" then
		task:Destroy()
	elseif taskType == "function" then
		task()
	elseif taskType == "table" and task.Destroy then
		task:Destroy()
	end
end

-- Enregistre une tache a nettoyer plus tard, retourne une cle pour :Remove() cible
function	Maid:GiveTask(task: Task): number
	local index = #self._tasks + 1
	self._tasks[index] = task
	return index
end

-- Nettoie une tache precise sans attendre le Destroy complet du Maid
function	Maid:Remove(index: number)
	local task = self._tasks[index]
	if task then
		cleanupOne(task)
		self._tasks[index] = nil
	end
end

-- Nettoie tout d'un coup (fin de run, mort d'un ennemi, etc.)
function	Maid:Destroy()
	for _, task in pairs(self._tasks) do
		cleanupOne(task)
	end
	self._tasks = {}
end

return Maid
