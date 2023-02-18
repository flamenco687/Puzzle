--!strict

local Types = require(script.Parent.Types)

local Component = {}
local Class = {}

export type Component = typeof(Component.new())
export type _Component = Component & _Properties

type _Properties = {
	_name: string
}

function Class.__call<T>(self: _Component, data: T): Types.ComponentInfo<T>
	return {data = data, name = self._name}
end

function Class.__tostring(self: _Component): string
	return self._name
end

function Component.new(name: string): <T>(data: T) -> Types.ComponentInfo<T>
	local self: _Properties = {
		_name = name,
	}

	return setmetatable(self, Class)
end

return Component