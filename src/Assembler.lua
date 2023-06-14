--!strict

--> Modules

local Types = require(script.Parent.Types)
local None = require(script.Parent.None)

--> Assembler

export type Assembler<T> = (data: T) -> Types.Component<T> -- Assembler is also exported in Types for accessiblity reasons

export type _Assembler<T> = {
	_name: string
}

local Assembler = { _isAssembler = true }

--> Assembler: Metamethods

function Assembler.__call<T>(self: _Assembler<T>, data: T): Types.Component<T>
	return {data = if data == nil then None :: any else data, name = self._name}
end

function Assembler.__tostring<T>(self: _Assembler<T>): string
	return self._name
end

local function Constructor<T>(name: string): Assembler<T>
	if type(name) ~= "string" then error("New Assembler -> Argument #1 expected string, got "..typeof(name), 2) end

	local self: _Assembler<T> = {
		_name = name,
	}

	return setmetatable(self, Assembler) :: any
end

return Constructor