--[[
	Author      : Lopapon
	Module      : Core/SystemManager
	Description : Auto-discovery des Systems (Server/Systems).
	              Meme pattern Init/Start que ServiceManager, plus une boucle
	              Heartbeat centralisee qui appelle :Update(dt) sur tous les systems.
]]

local RunService = game:GetService("RunService")

local Logger = require(script.Parent.Logger)
local log = Logger.new("SystemManager")

local SystemManager = {}
SystemManager._systems = {} :: { any }
SystemManager._heartbeatConnection = nil :: RBXScriptConnection?

function	SystemManager:LoadFolder(folder: Instance)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local ok, system = pcall(require, child)
			if ok then
				table.insert(SystemManager._systems, system)
				log:Info("Charge :", child.Name)
			else
				log:Error("Echec require sur", child.Name, "-", system)
			end
		end
	end
end

function	SystemManager:InitAll()
	for _, system in ipairs(SystemManager._systems) do
		if type(system.Init) == "function" then
			system:Init()
		end
	end
end

function	SystemManager:StartAll()
	for _, system in ipairs(SystemManager._systems) do
		if type(system.Start) == "function" then
			system:Start()
		end
	end

	if SystemManager._heartbeatConnection then
		return
	end

	SystemManager._heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		for _, system in ipairs(SystemManager._systems) do
			if type(system.Update) == "function" then
				system:Update(dt)
			end
		end
	end)
end

function	SystemManager:StopAll()
	if SystemManager._heartbeatConnection then
		SystemManager._heartbeatConnection:Disconnect()
		SystemManager._heartbeatConnection = nil
	end
end

return SystemManager
