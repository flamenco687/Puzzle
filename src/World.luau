--!strict

local Types = require(script.Parent.Types)
local Component = require(script.Parent.Component)

local World: _World = {}

type World = Methods --> Public type for World
type _World = World & _Properties --> Private type for World

--> World public methods
type Methods = {
	Spawn: (self: _World, ... Types.ComponentInfo<any>) -> number,
	Remove: (self: _World, id: number) -> (),
	Get: (self: _World, id: number, ... Component.Component?) -> {any} | {[string]: any},
	Set: (self: _World, id: number, ... Types.ComponentInfo<any>) -> ()
}

--> World private properties
type _Properties = {
	_componentAssociations: Types.ComponentAssociations,
	_nextId: number,
	_size: number
}

function World:Spawn(...: Types.ComponentInfo<any>): number
	local componentInfos: {Types.ComponentInfo<any>} = { ... }

	for _, componentInfo in componentInfos do
		if not self._componentAssociations[componentInfo.name] then
			self._componentAssociations[componentInfo.name] = {}
		end

		self._componentAssociations[componentInfo.name][self._nextId] = componentInfo.data
	end

	self._nextId += 1
	self._size += 1

	return self._nextId - 1
end

function World:Remove(id: number): ()
	for component in self._componentAssociations do
		self._componentAssociations[component][id] = nil
	end

	self._size -= 1
end

function World:Get(id: number, ...: Component.Component?): {any} | {[string]: any}
	local components: {[string]: true}? = if #{...} > 0 then {} else nil

	if components then
		for _, component: Component.Component in {... :: Component.Component} do
			components[tostring(component)] = true
		end
	end

	local componentsToUnpack: {any}? = if components then table.create(#components) else nil
	local componentsToReturn: Types.Dictionary? = if not components then {} else nil

	for component in self._componentAssociations do
		if self._componentAssociations[component][id] ~= nil then
			if componentsToUnpack and components and components[component] then
				table.insert(componentsToUnpack, (self._componentAssociations[component][id] :: Types.ComponentInfo<any>))
			elseif componentsToReturn then
				componentsToReturn[component] = (self._componentAssociations[component][id] :: Types.ComponentInfo<any>)
			end
		end
	end

	return if componentsToUnpack then table.unpack(componentsToUnpack) else componentsToReturn
end

function World:Set(id: number, ...: Types.ComponentInfo<any>)
	local components: {Types.ComponentInfo<any>} = {...}

	for _, componentInfo in components do
		self._componentAssociations[componentInfo.name][id] = componentInfo.data
	end
end

local Metatable = { __index = World } --> Private table that acts as metatable for World objects

return function(): World
	local self: _Properties = {
		_componentAssociations = {},
		_nextId = 1,
		_size = 0
	}

	return setmetatable(self, Metatable)
end