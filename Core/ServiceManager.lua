--[[
	Author      : Lopapon
	Module      : Core/ServiceManager
	Description : Auto-discovery des Services (Server/Services).
	              Chaque Service retourne une table avec Init() et/ou Start() optionnels.
	              Init = tout le monde se prepare (tables, abonnements EventBus)
	              Start = tout le monde est pret, on peut agir
	              (evite les bugs d'ordre "ServiceA a besoin de ServiceB pas encore charge")
]]

local Logger = require(script.Parent.Logger)
local log = Logger.new("ServiceManager")

local ServiceManager = {}
ServiceManager._services = {} :: { [string]: any }

-- Services qui doivent etre initialises en premier (dependances critiques)
local INIT_PRIORITY = { "DataService" }

local function getSortedNames(): { string }
	local names = {}
	local prioritized = {}
	for _, prio in ipairs(INIT_PRIORITY) do
		if ServiceManager._services[prio] then
			table.insert(names, prio)
			prioritized[prio] = true
		end
	end
	for name in pairs(ServiceManager._services) do
		if not prioritized[name] then
			table.insert(names, name)
		end
	end
	table.sort(names, function(a, b)
		if prioritized[a] and not prioritized[b] then return true end
		if not prioritized[a] and prioritized[b] then return false end
		return a < b
	end)
	return names
end

function	ServiceManager:LoadFolder(folder: Instance)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local ok, service = pcall(require, child)
			if ok then
				ServiceManager._services[child.Name] = service
				log:Info("Charge :", child.Name)
			else
				log:Error("Echec require sur", child.Name, "-", service)
			end
		end
	end
end

function	ServiceManager:Get(name: string): any
	local service = ServiceManager._services[name]
	if not service then
		log:Error("Service introuvable :", name)
	end
	return service
end

function	ServiceManager:InitAll()
	for _, name in ipairs(getSortedNames()) do
		local service = ServiceManager._services[name]
		if type(service.Init) == "function" then
			local ok, err = pcall(service.Init, service)
			if not ok then
				log:Error("Echec Init sur", name, "-", err)
			end
		end
	end
end

function	ServiceManager:StartAll()
	for _, name in ipairs(getSortedNames()) do
		local service = ServiceManager._services[name]
		if type(service.Start) == "function" then
			local ok, err = pcall(service.Start, service)
			if not ok then
				log:Error("Echec Start sur", name, "-", err)
			end
		end
	end
end

return ServiceManager
