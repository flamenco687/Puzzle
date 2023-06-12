--!strict

-->> Modules

local Types = require(script.Parent.Types)
local None = require(script.Parent.None)

-->> Assembler

local Assembler = { _isAssembler = true }

function Assembler.__call<T>(self: _Assembler, data: T): Types.Component<T>
	return {data = if data == nil then None :: any else data, name = self._name}
end

function Assembler.__tostring(self: _Assembler): string
	return self._name
end

local function Constructor<T>(name: string): Assembler<T>
	if not type(name) == "string" then error("New Assembler -> Argument #1 expected string, got "..typeof(name), 2) end

	local self: _Assembler = {
		_name = name,
	} 

	return setmetatable(self, Assembler) :: any
end

export type Assembler<T> = (data: T) -> Types.Component<T> --> Assembler is exported twice in different modules for easier access

-->> World private properties
export type _Assembler = {
	_name: string
}

return Constructor