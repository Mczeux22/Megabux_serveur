--[[
	Author      : Lopapon
	Module      : Core/StateManager
	Description : Store cle/valeur global pour l'etat du jeu (pas les data joueur)
	Usage : StateManager:Set("GamePhase", "InRun")
	        StateManager:OnChange("GamePhase", function(new, old) ... end)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)

local StateManager = {}
StateManager._state = {} :: { [string]: any }
StateManager._signals = {} :: { [string]: any }

local function	getSignal(key: string)
	local signal = StateManager._signals[key]
	if not signal then
		signal = Nova.Signal.new()
		StateManager._signals[key] = signal
	end
	return signal
end

function	StateManager:Get(key: string): any
	return StateManager._state[key]
end

-- Modifie une valeur, notifie les abonnes seulement si elle a change
function	StateManager:Set(key: string, value: any)
	local old = StateManager._state[key]
	if old == value then
		return
	end
	StateManager._state[key] = value
	local signal = StateManager._signals[key]
	if signal then
		signal:Fire(value, old)
	end
end

function	StateManager:OnChange(key: string, callback: (newValue: any, oldValue: any) -> ())
	return getSignal(key):Connect(callback)
end

return StateManager
