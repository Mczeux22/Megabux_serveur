--[[
	Author      : Lopapon
	Module      : Core/Logger
	Description : Wrapper print/warn avec niveaux + prefixe par module
	              Usage : local log = Logger.new("WaveService") puis log:Info("...")
]]

local Logger = {}
Logger.__index = Logger

export type Level = "Debug" | "Info" | "Warn" | "Error"

-- Change en "Info" ou "Warn" en prod pour couper les logs de debug
Logger.MinLevel: Level = "Debug"

local LEVEL_ORDER = { Debug = 1, Info = 2, Warn = 3, Error = 4 }

function	Logger.new(tag: string)
	local self = setmetatable({}, Logger)
	self._tag = tag
	return self
end

function	Logger:_shouldLog(level: Level): boolean
	return LEVEL_ORDER[level] >= LEVEL_ORDER[Logger.MinLevel]
end

function	Logger:Debug(...: any)
	if self:_shouldLog("Debug") then
		print(("[%s][Debug]"):format(self._tag), ...)
	end
end

function	Logger:Info(...: any)
	if self:_shouldLog("Info") then
		print(("[%s]"):format(self._tag), ...)
	end
end

function	Logger:Warn(...: any)
	if self:_shouldLog("Warn") then
		warn(("[%s][Warn]"):format(self._tag), ...)
	end
end

function	Logger:Error(...: any)
	if self:_shouldLog("Error") then
		warn(("[%s][ERROR]"):format(self._tag), ...)
	end
end

return Logger
