local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ==========================
-- CORRECTION : Créer le dossier UIEventRemote au démarrage
-- ==========================
if not ReplicatedStorage:FindFirstChild("UIEventRemote") then
    local folder = Instance.new("Folder")
    folder.Name = "UIEventRemote"
    folder.Parent = ReplicatedStorage
end

local ServiceManager = require(game.ServerScriptService.Server.Megabux_serveur.Core.ServiceManager)
local SystemManager   = require(game.ServerScriptService.Server.Megabux_serveur.Core.SystemManager)

ServiceManager:LoadFolder(script.Parent.Services)
SystemManager:LoadFolder(script.Parent.Systems)

ServiceManager:InitAll()
SystemManager:InitAll()

ServiceManager:StartAll()
SystemManager:StartAll()

-- Dossier pour UIEventRemote
if not ReplicatedStorage:FindFirstChild("UIEventRemote") then
    local folder = Instance.new("Folder")
    folder.Name = "UIEventRemote"
    folder.Parent = ReplicatedStorage
end

-- Dossier pour CombatRemote
if not ReplicatedStorage:FindFirstChild("CombatRemote") then
    local folder = Instance.new("Folder")
    folder.Name = "CombatRemote"
    folder.Parent = ReplicatedStorage
end