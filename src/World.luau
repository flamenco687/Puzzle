--!strict

local Types = require(script.Parent.Types)

local World = {}

function World.Spawn(self: _World, ...: Types.Component<any>): number
	local components: { Types.Component<any> } = { ... }

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
	end

	self._size -= 1
end

function World.Get(self: _World, id: number, ...: Types.Assembler?): {any} | {[string]: any}
	local assemblers: { [string]: true }? = if #{...} > 0 then {} else nil

	if assemblers then
		for _, component: Types.Assembler in {... :: Types.Assembler} do
			assemblers[tostring(component)] = true
		end
	end

	local assemblersToUnpack: { any }? = if assemblers then table.create(#assemblers) else nil
	local assemblersToReturn: Types.Dictionary<any>? = if not assemblers then {} else nil

	for component in self._storage do
		if self._storage[component][id] ~= nil then
			if assemblersToUnpack and assemblers and assemblers[component] then
				table.insert(assemblersToUnpack, (self._storage[component][id] :: Types.Component<any>))
			elseif assemblersToReturn then
				assemblersToReturn[component] = (self._storage[component][id] :: Types.Component<any>)
			end
		end
	end

	return if assemblersToUnpack then table.unpack(assemblersToUnpack) else assemblersToReturn
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