--!strict

local Types = require(script.Parent.Types)

local World = {}

function World.Spawn(self: _World, ...: Types.Component<any>): number
	local componentInfos: {Types.Component<any>} = { ... }

	for _, componentInfo in componentInfos do
		if not self._storage[componentInfo.name] then
			self._storage[componentInfo.name] = {}
		end

		self._storage[componentInfo.name][self._nextId] = componentInfo.data
	end

	self._nextId += 1
	self._size += 1

	return self._nextId - 1
end

function World.Remove(self: _World, id: number): ()
	for component in self._storage do
		self._storage[component][id] = nil
	end

	self._size -= 1
end

function World.Get(self: _World, id: number, ...: Types.Assembler?): {any} | {[string]: any}
	local components: {[string]: true}? = if #{...} > 0 then {} else nil

	if components then
		for _, component: Types.Assembler in {... :: Types.Assembler} do
			components[tostring(component)] = true
		end
	end

	local componentsToUnpack: {any}? = if components then table.create(#components) else nil
	local componentsToReturn: Types.Dictionary<any>? = if not components then {} else nil

	for component in self._storage do
		if self._storage[component][id] ~= nil then
			if componentsToUnpack and components and components[component] then
				table.insert(componentsToUnpack, (self._storage[component][id] :: Types.Component<any>))
			elseif componentsToReturn then
				componentsToReturn[component] = (self._storage[component][id] :: Types.Component<any>)
			end
		end
	end

	return if componentsToUnpack then table.unpack(componentsToUnpack) else componentsToReturn
end

function World.Set(self: _World, id: number, ...: Types.Component<any>)
	local components: {Types.Component<any>} = {...}

	for _, componentInfo in components do
		self._storage[componentInfo.name][id] = componentInfo.data
	end
end

local Metatable = { __index = World } --> Avoids inserting metamethods inside the methods table

local function Constructor(): World
	local self: Properties & _Properties = {
		_storage = {},
		_nextId = 1,
		_size = 0
	}

	return setmetatable(self, Metatable) :: _World
end

-->> World methods
type Methods = typeof(World)

-->> World public properties
type Properties = {}

-->> World private properties
type _Properties = {
	_storage: Types.Storage,
	_nextId: number,
	_size: number
}

-->> World classes
type World = Methods & Properties
type _World = Methods & _Properties

return Constructor