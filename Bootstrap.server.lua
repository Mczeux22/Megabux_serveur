local ServerScriptService = game:GetService("ServerScriptService")

local ServiceManager = require(game.ServerScriptService.Server.Megabux_serveur.Core.ServiceManager)
local SystemManager   = require(game.ServerScriptService.Server.Megabux_serveur.Core.SystemManager)

ServiceManager:LoadFolder(script.Services)
SystemManager:LoadFolder(script.Systems)

ServiceManager:InitAll()
SystemManager:InitAll()

ServiceManager:StartAll()
SystemManager:StartAll()
