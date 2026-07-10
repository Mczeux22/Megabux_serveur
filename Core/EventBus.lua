--[[
	Author      : Lopapon
	Module      : Core/EventBus
	Description : Bus d'evenements global, base sur Nova.Signal.
	              Permet aux Services/Systems de communiquer par nom d'event
	              sans se requirer entre eux (evite les dependances circulaires).
	Usage : EventBus:Subscribe("EnemyDied", function(enemy, killer) ... end)
	        EventBus:Publish("EnemyDied", enemy, killer)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nova = require(ReplicatedStorage.Shared.Nova)

local EventBus = {}
EventBus._signals = {} :: { [string]: any }

local function	getSignal(eventName: string)
	local signal = EventBus._signals[eventName]
	if not signal then
		signal = Nova.Signal.new()
		EventBus._signals[eventName] = signal
	end
	return signal
end

-- S'abonne a un event, retourne une Connection (a donner a un Maid)
function	EventBus:Subscribe(eventName: string, callback: (...any) -> ())
	return getSignal(eventName):Connect(callback)
end

-- Declenche un event pour tous les abonnes
function	EventBus:Publish(eventName: string, ...: any)
	local signal = EventBus._signals[eventName]
	if signal then
		signal:Fire(...)
	end
end

-- Coupe tous les abonnes d'un event precis (debug/tests surtout)
function	EventBus:ClearEvent(eventName: string)
	local signal = EventBus._signals[eventName]
	if signal then
		signal:DisconnectAll()
	end
end

return EventBus
