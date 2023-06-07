--!strict

--->> Modules

local t = require(script.Parent.Parent.t)
local Signal = require(script.Parent.Signal)

local Types = require(script.Parent.Types)
local None = require(script.Parent.None)

--->> QueryResult

export type QueryResult = {
	-->> Public methods
	Without: (self: QueryResult, ...Types.Assembler<any>) -> QueryResult
}

type _QueryResultProperties = {
	_world: _World,
	_queryResultId: string,
	_with: {Types.Assembler<any>},
	_without: {Types.Assembler<any>}?
}

export type _QueryResult = _QueryResultProperties & {
	-->> Public methods
	Without: (self: _QueryResult, ...Types.Assembler<any>) -> QueryResult
}

local QueryResult = {}
local QueryResultMetatable = { __index = QueryResult, _isQueryResult = true }

function QueryResultMetatable.__iter(self: _QueryResult)
	local id = 0

	local function Iter()
		id += 1

		if id == self._world._nextId then return end --> Terminates the loop
		if self._world._missing[id] then return Iter() end --> Continues the loop

		if self._without then
			for _, assembler in self._without do
				if self._world:Get(id, assembler) then return Iter() end --> Excludes components
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

type QueryResultCache = {
	[_World]: {
		[string]: QueryResult | _QueryResult
	}
}

local QueryResultCache: QueryResultCache = {}

function QueryResult.Without(self: _QueryResult, ...: Types.Assembler<any>): QueryResult
	local without: {Types.Assembler<any>} = {...}
	local queryResultId = self._queryResultId .. "-"

	for index, assembler in without do
		if not Types.Assembler(assembler) then error("Without() -> Argument #"..1 + index.." expected assembler, got "..typeof(assembler), 2) end
		queryResultId = queryResultId .. tostring(assembler)
	end

	if QueryResultCache[self._world][queryResultId] then
		return QueryResultCache[self._world][queryResultId]
	end

	local properties: _QueryResultProperties = {
		_world = self._world,
		_queryResultId = queryResultId,
		_with = self._with,
		_without = without,
	}

	local queryResultWithout: _QueryResult = setmetatable(properties, QueryResultMetatable) :: any

	QueryResultCache[self._world][queryResultId] = queryResultWithout

	return queryResultWithout :: QueryResult
end

local function QueryResultConstructor(world: _World, ...: Types.Assembler<any>): QueryResult
	local with: {Types.Assembler<any>} = {...}
	local queryResultId = ""

	for index, assembler in with do
		if not Types.Assembler(assembler) then error("Query() -> Argument #"..1 + index.." expected assembler, got "..typeof(assembler), 3) end
		queryResultId = queryResultId .. tostring(assembler)
	end

	if QueryResultCache[world][queryResultId] then
		return QueryResultCache[world][queryResultId]
	end

	local properties: _QueryResultProperties = {
		_world = world,
		_queryResultId = queryResultId,
		_with = with,
	}

	local self: _QueryResult = setmetatable(properties, QueryResultMetatable) :: any

	QueryResultCache[world][queryResultId] = self

	return self :: QueryResult
end

--->> World

export type World = {
	-->> Public methods
	OnChange: (self: World, index: number | Types.Assembler<any>) -> Signal.Signal,
	Has: (self: World, id: number) -> boolean,
	Query: (self: World, ...Types.Assembler<any>) -> QueryResult,
	SpawnAt: (self: World, id: number, ...Types.Component<any>) -> number,
	Spawn: (self: World, ...Types.Component<any>) -> number,
	Despawn: (self: World, id: number) -> true,
	Get: (self: World, id: number, ...Types.Assembler<any>?) -> (...any | Types.Dictionary<any>),
	Set: (self: World, id: number, ...Types.Component<any>) -> true
}

type _WorldProperties = {
	_storage: Types.Storage,
	_missing: {true},
	_nextId: number,
	_size: number
}

export type _World = _WorldProperties & {
	-->> Private methods
	_NotifyOfChange: (self: _World, component: string, id: number, oldValue: any?, newValue: any?) -> (),
	-->> Public methods
	OnChange: (self: _World, index: number | Types.Assembler<any>) -> Signal.Signal,
	Has: (self: _World, id: number) -> boolean,
	Query: (self: _World, ...Types.Assembler<any>) -> QueryResult,
	SpawnAt: (self: _World, id: number, ...Types.Component<any>) -> number,
	Spawn: (self: _World, ...Types.Component<any>) -> number,
	Despawn: (self: _World, id: number) -> true,
	Get: (self: _World, id: number, ...Types.Assembler<any>?) -> (...any | Types.Dictionary<any>),
	Set: (self: _World, id: number, ...Types.Component<any>) -> true
}

local World = {}
local Metatable = { __index = World, _isWorld = true } --> Avoids inserting metamethods inside the methods table

type SignalCache = {
	[_World]: {
		[number | string]: Signal.Signal
	}
}

local SignalCache: SignalCache = {}

-->> Private methods

function World._NotifyOfChange(self: _World, component: string, id: number, oldValue: any?, newValue: any?)
	local componentSignal, entitySignal = SignalCache[self][component], SignalCache[self][id]

	if componentSignal then componentSignal:Fire(id, oldValue, newValue) end
	if entitySignal then entitySignal:Fire(component, oldValue, newValue) end
end

-->> Publich methods

function World.OnChange(self: _World, idOrAssembler: number | Types.Assembler<any>): Signal.Signal
	if not t.union(t.number, t.table)(idOrAssembler) then error("OnChange() -> Argument #1 expected number or assembler, got "..typeof(idOrAssembler), 2) end

	local index: number | string

	if typeof(idOrAssembler) == "table" and not Types.Assembler(idOrAssembler) then
		error("OnChange() -> Argument #1 expected assembler, got "..typeof(index), 2)
	else
		index = tostring(idOrAssembler)
	end

	if not SignalCache[self][index] then
		SignalCache[self][index] = Signal(true)
	end

	return SignalCache[self][index]
end

function World.Has(self: _World, id: number): boolean
	if not t.number(id) then error("Has() -> Argument #1 expected number, got "..typeof(id), 2) end
	return if id < self._nextId and id > 0 and not self._missing[id] then true else false
end

function World.Query(self: _World, ...: Types.Assembler<any>): QueryResult
	return QueryResultConstructor(self, ...)
end

function World.SpawnAt(self: _World, id: number, ...: Types.Component<any>): number
	if not t.number(id) then error("SpawnAt() -> Argument #1 expected number, got "..typeof(id), 2) end
	if not Types.Components(...) then error("Spawn() -> Arguments expected components tuple, got "..typeof(...), 2) end

	local components: {Types.Component<any>} = {...}

	for _, component in components do
		if not self._storage[component.name] then
			self._storage[component.name] = {}
		end

		self._storage[component.name][id] = component.data
		self:_NotifyOfChange(component.name, id, nil, component.data)
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

function World.Despawn(self: _World, id: number): true
	if not t.number(id) then error("Despawn() -> Argument #1 expected number, got "..typeof(id), 2) end

	for component in self._storage do
		self:_NotifyOfChange(component, id, self._storage[component][id], nil)
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
			if not Types.Assembler(assembler) then error("Get() -> Argument #"..1 + index.." expected assembler, got "..typeof(assembler), 2) end
			if not self._storage[tostring(assembler)] then return nil :: any end

			local data = self._storage[tostring(assembler)][id];
			(componentsToReturn :: {any})[index] = data
		end

		return table.unpack(componentsToReturn :: {any})
	else
		for component in self._storage do
			local data = self._storage[component][id];
			(componentsToReturn :: Types.Dictionary<any>)[component] = data
		end
		return componentsToReturn
	end
end

function World.Set(self: _World, id: number, ...: Types.Component<any>)
	if not t.number(id) then error("Set() -> Argument #1 expected number, got "..typeof(id), 2) end

	local components: {Types.Component<any>} = {...}

	for index, component in components do
		if not Types.Component(component) then error("Set() -> Argument #"..1 + index.." expected component, got "..typeof(component), 2) end

		if not self._storage[component.name] then
			self._storage[component.name] = {}
		end

		self:_NotifyOfChange(component.name, id, self._storage[component.name][id], component.data)
		self._storage[component.name][id] = component.data
	end
end

function World.Update(self: _World, id: number, ...: Types.Component<{[any]: any}>)
	if not t.number(id) then error("Update() -> Argument #1 expected number, got "..typeof(id), 2) end

	local components: {Types.Component<{[any]: any}>} = {...}

	for index, component in components do
		if not Types.TableComponent(component) then error("Set() -> Argument #"..1 + index.." expected component, got "..typeof(component), 2) end

		if not self._storage[component.name] then
			self._storage[component.name] = {}
		end

		local oldValue = self._storage[component.name][id]

		if type(self._storage[component.name][id]) == "table" then
			for key, value in component.data do
				self._storage[component.name][id][key] = if value == None then nil else value
			end
		else
			self._storage[component.name][id] = component.data
		end

		self:_NotifyOfChange(component.name, id, oldValue, self._storage[component.name][id])
	end
end

function World.Remove(self: _World, id: number, ...: Types.Assembler<any>): true
	if not t.number(id) then error("Remove() -> Argument #1 expected number, got "..typeof(id), 2) end

	local assemblers: {Types.Assembler<any>} = {...}

	for index, assembler in assemblers do
		if not Types.Assembler(assembler) then error("Remove() -> Argument #"..1 + index.." expected assembler, got "..typeof(assembler), 2) end
		if not self._storage[tostring(assembler)] then continue end

		self:_NotifyOfChange(tostring(assembler), id, self._storage[tostring(assembler)][id], nil)
		self._storage[tostring(assembler)][id] = nil
	end

	return true
end

local function Constructor(): World
	local properties: _WorldProperties = {
		_storage = {},
		_missing = {},
		_nextId = 1,
		_size = 0
	}

	local self: _World = setmetatable(properties, Metatable) :: any

	SignalCache[self] = {}
	QueryResultCache[self] = {}

	return self :: World
end

return Constructor