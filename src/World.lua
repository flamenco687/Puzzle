--!strict

-->> Modules

local t = require(script.Parent.Parent.t)

local Types = require(script.Parent.Types)

-->> World

local World = {}

function World.Has(self: _World, id: number): boolean
	return if id < self._nextId and id > 0 and not self._missing[id] then true else false
end

function World.SpawnAt(self: _World, id: number, ...: Types.Component<any>): number
	if not Types.Components(...) then error("Spawn() -> Arguments expected components tuple, got "..typeof(...), 2) end

	local components: {Types.Component<any>} = {...}

	for _, component in components do
		if not self._storage[component.name] then
			self._storage[component.name] = {}
		end

		self._storage[component.name][id] = component.data
	end

	if self._missing[id] then
		self._missing[id] = nil
	end

	if id >= self._nextId then
		if id ~= self._nextId then
			for missingId = self._nextId, id - 1 do
				self._missing[missingId] = true
			end
		end

		self._nextId = id + 1
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

	if #self._missing > id then
		self._missing[id] = true
	end

	if id == self._nextId - 1 then
		if self._size < id then
			for possibleEntity = id - 1, 1, -1 do
				if self._missing[possibleEntity] then
					self._missing[possibleEntity] = nil
				else
					self._nextId = possibleEntity + 1
					break
				end
			end
		else
			self._nextId -= 1
		end
	end

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
			(componentsToReturn :: {any})[index] = data
		end

		return table.unpack(componentsToReturn :: {any})
	else
		for component in self._storage do
			local data = self._storage[component][id];
			(componentsToReturn :: Types.Dictionary<any>)[component] = data
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
		_missing = {},
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
	_missing: {true},
	_nextId: number,
	_size: number
}

-->> World classes
export type World = Methods & Properties
export type _World = Methods & _Properties

return Constructor