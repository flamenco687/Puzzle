--!strict

local t = require(script.Parent.Parent.t)
local Types = require(script.Parent.Types)

local Assembler = { _isAssembler = true }

function Assembler.__call<T>(self: _Properties, data: T): Types.Component<T>
	return {data = data, name = self._name}
end

function Assembler.__tostring(self: _Properties): string
	return self._name
end

local function Constructor<T>(name: string): Types.Assembler<T>
	if not t.string(name) then error("New Assembler -> Argument #1 expected string, got "..typeof(name), 2) end

	local self: _Properties = {
		_name = name,
	}

	return setmetatable(self, Assembler) :: any
end

-->> World private properties
type _Properties = {
	_name: string
}

return Constructor