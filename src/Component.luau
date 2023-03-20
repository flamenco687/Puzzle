--!strict

local Types = require(script.Parent.Types)

--> Component private properties
type _Properties = {
	_name: string
}

local Metatable = {} --> Prevents the class table from containing metamethods

function Metatable.__call<T>(self: _Properties, data: T): Types.ComponentInfo<T>
	return { data = data, name = self._name }
end

function Metatable.__tostring(self: _Properties): string
	return self._name
end

return function(name: string): <T>(data: T) -> Types.ComponentInfo<T>
	local self: any = { --> any is being used as the best/only option to match typings with the exported type
		_name = name,
	}

	return setmetatable(self, Metatable)
end