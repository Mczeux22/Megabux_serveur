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
	for name, service in pairs(ServiceManager._services) do
		if type(service.Init) == "function" then
			local ok, err = pcall(service.Init, service)
			if not ok then
				log:Error("Echec Init sur", name, "-", err)
			end
		end
	end
end

function	ServiceManager:StartAll()
	for name, service in pairs(ServiceManager._services) do
		if type(service.Start) == "function" then
			local ok, err = pcall(service.Start, service)
			if not ok then
				log:Error("Echec Start sur", name, "-", err)
			end
		end
	end
end

return ServiceManager
