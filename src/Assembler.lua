--!strict

-->> Modules

local t = require(script.Parent.Parent.t)

local Types = require(script.Parent.Types)
local None = require(script.Parent.None)

-->> Assembler

local Assembler = { _isAssembler = true }

function Assembler.__call<T>(self: _Assembler, data: T): Types.Component<T>
	return {data = if data == nil then None else data, name = self._name}
end

function Assembler.__tostring(self: _Assembler): string
	return self._name
end

local function Constructor<T>(name: string): Types.Assembler<T>
	if not t.string(name) then error("New Assembler -> Argument #1 expected string, got "..typeof(name), 2) end

	local self: _Assembler = {
		_name = name,
	}

	return setmetatable(self, Assembler) :: any
end

-->> World private properties
export type _Assembler = {
	_name: string
}

return Constructor