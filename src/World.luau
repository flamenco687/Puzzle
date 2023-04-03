--!strict

local Types = require(script.Parent.Types)

local World = {}

function World.Spawn(self: _World, ...: Types.Component<any>): number
	local components: {Types.Component<any>} = {...}

	for _, component in components do
		if not self._storage[component.name] then
			self._storage[component.name] = {}
		end

		self._storage[component.name][self._nextId] = component.data
	end

	self._nextId += 1
	self._size += 1

	return self._nextId - 1
end

function World.Remove(self: _World, id: number): ()
	for component in self._storage do
		self._storage[component][id] = nil

		if #self._storage[component] == 0 then
			self._storage[component] = nil
		end
	end

	self._size -= 1
	self._nextId -= 1
end

function World.Get(self: _World, id: number, ...: Types.Assembler<any>?): ...any | Types.Dictionary<any>
	local assemblers: { Types.Assembler<any> }? = if ... then {... :: Types.Assembler<any>} else nil
	local componentsToReturn = if assemblers then table.create(#assemblers) :: {any} else {} :: Types.Dictionary<any>

	if assemblers then
		for _, assembler in assemblers do
			table.insert(componentsToReturn :: {any}, self._storage[tostring(assembler)][id]) end
		return table.unpack(componentsToReturn :: {any})
	else
		for component in self._storage do
			(componentsToReturn :: Types.Dictionary<any>)[component] = self._storage[component][id] end
		return componentsToReturn :: Types.Dictionary<any>
	end
end

function World.Set(self: _World, id: number, ...: Types.Component<any>)
	local components: {Types.Component<any>} = {...}

	for _, component in components do
		self._storage[component.name][id] = component.data
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