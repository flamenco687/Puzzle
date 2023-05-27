--!strict

-->> Modules

local t = require(script.Parent.Parent.t)

local Types = require(script.Parent.Types)
local Void = require(script.Parent.Void)

-->> World

local World = {}

function World.SpawnAt(self: _World, id: number, ...: Types.Component<any>)
	if not Types.Components(...) then error("Spawn() -> Arguments expected components tuple, got "..typeof(...), 2) end

	local components: {Types.Component<any>} = {...}

	for _, component in components do
		if not self._storage[component.name] then
			self._storage[component.name] = {}
		end

		if id > #self._storage[component.name] + 1 then --> Introduces Void in possible void positions to prevent holes
			for index = 1, id - 1 do
				if self._storage[component.name][index] == nil then
					self._storage[component.name][index] =  Void
				end
			end
		end

		self._storage[component.name][id] = component.data
	end

	if id == self._nextId then
		self._nextId += 1
	end

	self._size += 1

	return id
end

function World.Spawn(self: _World, ...: Types.Component<any>): number
	return self:SpawnAt(self._nextId, ...)
end

function World.Remove(self: _World, id: number): true
	if not t.number(id) then error("Remove() -> Argument #1 expected number, got "..typeof(id), 2) end

	for component in self._storage do
		self._storage[component][id] = nil

		if #self._storage[component] == 0 then
			self._storage[component] = nil
		end
	end

	self._size -= 1
	self._nextId -= 1

	return true
end

function World.Get(self: _World, id: number, ...: Types.Assembler<any>?): ...any | Types.Dictionary<any>
	if not t.number(id) then error("Get() -> Argument #1 expected number, got "..typeof(id), 2) end

	local assemblers = if ... then {...} else nil
	local componentsToReturn = if assemblers then table.create(#assemblers) :: {any} else {} :: Types.Dictionary<any>

	if assemblers then
		for index, assembler in assemblers :: {Types.Assembler<any>} do
			if not getmetatable(assembler :: any) or not getmetatable(assembler :: any).__call then
				error("Get() -> Argument #"..1 + index.." expected assembler, got "..typeof(assembler), 2)
			end

			local data = self._storage[tostring(assembler)][id];
			(componentsToReturn :: {any})[index] = if data == Void then nil else data
		end

		return table.unpack(componentsToReturn :: {any})
	else
		for component in self._storage do
			local data = self._storage[component][id];
			(componentsToReturn :: Types.Dictionary<any>)[component] = if data == Void then nil else data
		end
		return componentsToReturn :: Types.Dictionary<any>
	end
end

function World.Set(self: _World, id: number, ...: Types.Component<any>): true
	if not t.number(id) then error("Set() -> Argument #1 expected number, got "..typeof(id), 2) end
	if not Types.Components(...) then error("Set() -> Argument #2 expected components tuple, got "..typeof(...), 2) end

	local components: {Types.Component<any>} = {...}

	for _, component in components do
		self._storage[component.name][id] = component.data
	end

	return true
end

local Metatable = { __index = World, _isWorld = true } --> Avoids inserting metamethods inside the methods table

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
export type World = Methods & Properties
export type _World = Methods & _Properties

return Constructor