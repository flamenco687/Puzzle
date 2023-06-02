--!strict

-->> Modules

local t = require(script.Parent.Parent.t)
local Signal = require(script.Parent.Signal)

local Types = require(script.Parent.Types)

-->> World

local World = {}

function World.Has(self: _World, id: number): boolean
	return if id < self._nextId and id > 0 and not self._missing[id] then true else false
end

--->> QueryResult

local QueryResult = {}
local QueryResultMetatable = { __index = QueryResult }

local QueryResultCache = {}

function QueryResult.Without(self: _QueryResult, ...: Types.Assembler<any>): QueryResult
	local without = {...}
	local queryResultId = self._queryResultId .. "-"

	for _, assembler in without do
		queryResultId = queryResultId .. tostring(assembler)
	end

	if QueryResultCache[queryResultId] then
		return QueryResultCache[queryResultId]
	end

	local queryResultWithout: QueryResultProperties & _QueryResultProperties = {
		_world = self._world,
		_with = self._with,
		_without = without,
		_queryResultId = queryResultId,
	}

	QueryResultCache[queryResultId] = queryResultWithout

	return setmetatable(queryResultWithout, QueryResultMetatable) :: QueryResult
end

function QueryResultMetatable.__iter(self: _QueryResult)
	local id = 0

	local function Iter()
		id += 1

		if id == self._world._nextId then return end --> Terminates the loop
		if self._world._missing[id] then return Iter() end --> Continues the loop

		if self._without then
			for _, assembler in self._without do
				if self._world:Get(id, assembler) then return Iter() end
			end
		end

		local data = {}

		for order, assembler in self._with do
			data[order] = self._world:Get(id, assembler)
		end

		if #data < #self._with then return Iter() end --> Ensures that all components are present

		return id, table.unpack(data)
	end

	return Iter
end

local function QueryResultConstructor(world: _World, ...: Types.Assembler<any>): QueryResult
	local with = {...}
	local queryResultId = ""

	for _, assembler in with do
		queryResultId = queryResultId .. tostring(assembler)
	end

	if QueryResultCache[queryResultId] then
		return QueryResultCache[queryResultId]
	end

	local self: QueryResultProperties & _QueryResultProperties = {
		_world = world,
		_with = {...},
		_queryResultId = queryResultId
	}

	QueryResultCache[queryResultId] = self

	return setmetatable(self, QueryResultMetatable) :: _QueryResult
end

-->> QueryResult methods
type QueryResultMethods = typeof(QueryResult)

-->> QueryResult public properties
type QueryResultProperties = {}

-->> QueryResult private properties
type _QueryResultProperties = {
	_world: _World,
	_queryResultId: number,
	_with: {Types.Assembler<any>},
	_without: {Types.Assembler<any>}?
}

-->> QueryResult classes
export type QueryResult = QueryResultMethods
export type _QueryResult = QueryResultMethods & _QueryResultProperties

--->> World

type SignalCache = {
	[_World]: {
		[number | Types.Assembler<any>]: Signal.Signal
	}
}

local SignalCache = {}

function World._Update(self: _World, component: string, id: number, oldValue: any?, newValue: any?)
	local componentSignal, entitySignal = SignalCache[self][component], SignalCache[self][id]

	if componentSignal then componentSignal:Fire(id, oldValue, newValue) end
	if entitySignal then entitySignal:Fire(component, oldValue, newValue) end
end

function World.OnUpdate(self: _World, index: number | Types.Assembler<any>): Signal.Signal
	if typeof(index) ~= "number" then index = tostring(index) end

	if not SignalCache[self][index] then
		SignalCache[self][index] = Signal(true)
	end

	return SignalCache[self][index]
end

function World.Query(self: _World, ...: Types.Assembler<any>): QueryResult
	return QueryResultConstructor(self, ...)
end

function World.SpawnAt(self: _World, id: number, ...: Types.Component<any>): number
	if not Types.Components(...) then error("Spawn() -> Arguments expected components tuple, got "..typeof(...), 2) end

	local components: {Types.Component<any>} = {...}

	for _, component in components do
		if not self._storage[component.name] then
			self._storage[component.name] = {}
		end

		self._storage[component.name][id] = component.data
		self:_Update(component.name, id, nil, component.data)
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
		self:_Update(component, id, self._storage[component][id], nil)
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
		if not self._storage[component.name] then
			self._storage[component.name] = {}
		end

		self:_Update(component.name, id, self._storage[component.name][id], component.data)
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

	SignalCache[self] = {}

	return setmetatable(self, Metatable) :: _World
end

-->> World methods
type Methods = typeof(World)

-->> World public properties
type Properties = {}
type _Properties = {
	_storage: Types.Storage,
	_missing: {true},
	_nextId: number,
	_size: number
}

-->> World classes
export type World = Methods & Properties
export type _World = World & _Properties

return Constructor