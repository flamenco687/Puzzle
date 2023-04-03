--!strict

local Types = require(script.Parent.Types)

local Assembler = {}

function Assembler.__call<T>(self: _Properties, data: T): Types.Component<T>
	return {data = data, name = self._name}
end

function Assembler.__tostring(self: _Properties): string
	return self._name
end

local function Constructor(name: string): Types.Assembler<any>
	if name :: any == true then return Assembler :: any end --> Returns the metatable for testing purposes

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