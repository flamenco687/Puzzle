--!strict

--> Modules

local Signal = require(script.Parent.Signal)

local Types = require(script.Parent.Types)
local None = require(script.Parent.None)

--> QueryResult

export type QueryResult = {
	-- Public methods
	Without: (self: QueryResult, ...Types.Assembler<any>) -> QueryResult
}

type _QueryResultProperties = {
	_world: _World,
	_queryResultId: string,
	_with: {Types.Assembler<any>},
	_without: {Types.Assembler<any>}?
}

export type _QueryResult = _QueryResultProperties & {
	-- Public methods
	Without: (self: _QueryResult, ...Types.Assembler<any>) -> QueryResult
}

local QueryResult = {}
local QueryResultMetatable = { __index = QueryResult, _isQueryResult = true }

--> QueryResult: Metamethods

function QueryResultMetatable.__iter(self: _QueryResult)
	local id = 0

	local function Iter()
		id += 1

		if id == self._world._nextId then return end -- Terminates the loop
		if self._world._missing[id] then return Iter() end -- Continues the loop

		if self._without then
			for _, assembler in self._without do
				if self._world:Get(id, assembler) then return Iter() end -- Excludes components
			end
		end

		local data = {}

		for order, assembler in self._with do
			data[order] = self._world:Get(id, assembler)
		end

		if #data < #self._with then return Iter() end -- Ensures that all components are present

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

--> QueryResult: Public methods

local function SearchQueryResultId(currentId: string, assemblers: {Types.Assembler<any>})
	local queryResultId = currentId

	for index, assembler in assemblers do
		if not Types.Assembler(assembler) then error("SearchQueryResultId() -> Argument #"..1 + index.." expected assembler, got "..typeof(assembler), 1) end
		queryResultId = queryResultId .. tostring(assembler)
	end

	return queryResultId
end

function QueryResult.Without(self: _QueryResult, ...: Types.Assembler<any>): QueryResult
	local without: {Types.Assembler<any>} = {...}
	local queryResultId = SearchQueryResultId(self._queryResultId .. "-", without)

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
	local queryResultId = SearchQueryResultId("", with)

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

---> World

export type World = {
	-- Public methods
	OnChange: (self: World, index: number | Types.Assembler<any>) -> Signal.Signal,
	Has: (self: World, id: number) -> boolean,
	Query: (self: World, ...Types.Assembler<any>) -> QueryResult,
	SpawnAt: (self: World, id: number, ...Types.Component<any>) -> number,
	Spawn: (self: World, ...Types.Component<any>) -> number,
	Despawn: (self: World, id: number) -> (),
	Get: (self: World, id: number, ...Types.Assembler<any>?) -> (...any | Types.Dictionary<any>),
	Set: (self: World, id: number, ...Types.Component<any>) -> (),
	Update: (self: World, id: number, ...Types.Component<{[any]: any}>) -> (),
	Remove: (self: World, id: number, ...Types.Assembler<any>) -> (),
}

type _WorldProperties = {
	_storage: Types.Storage,
	_missing: {true},
	_nextId: number,
	_size: number
}

export type _World = _WorldProperties & {
	-- Private methods
	_FireListeners: (self: _World, component: string, id: number, oldValue: any?, newValue: any?) -> (),
	_Set: (self: _World, component: string, id: number, value: any) -> (),
	-- Public methods
	OnChange: (self: _World, index: number | Types.Assembler<any>) -> Signal.Signal,
	Has: (self: _World, id: number) -> boolean,
	Query: (self: _World, ...Types.Assembler<any>) -> QueryResult,
	SpawnAt: (self: _World, id: number, ...Types.Component<any>) -> number,
	Spawn: (self: _World, ...Types.Component<any>) -> number,
	Despawn: (self: _World, id: number) -> (),
	Get: (self: _World, id: number, ...Types.Assembler<any>?) -> (...any | Types.Dictionary<any>),
	Set: (self: _World, id: number, ...Types.Component<any>) -> (),
	Update: (self: _World, id: number, ...Types.Component<{[any]: any}>) -> (),
	Remove: (self: _World, id: number, ...Types.Assembler<any>) -> (),
}

local World = {}
local Metatable = { __index = World, _isWorld = true } -- Avoids inserting metamethods inside the methods table

type SignalCache = {
	[_World]: {
		[number | string]: Signal.Signal
	}
}

local SignalCache: SignalCache = {}

--> World: Private methods

function World._FireListeners(self: _World, component: string, id: number, oldValue: any?, newValue: any?)
	local componentSignal, entitySignal = SignalCache[self][component], SignalCache[self][id]

	if componentSignal then componentSignal:Fire(id, oldValue, newValue) end
	if entitySignal then entitySignal:Fire(component, oldValue, newValue) end
end

function World._Set(self: _World, component: string, id: number, value: any)
	if not self._storage[component] and value ~= nil then
		self._storage[component] = {}
	end

	local oldValue = self._storage[component][id]

	self._storage[component][id] = value
	self:_FireListeners(component, id, oldValue, value)
end

--> World: Public methods

function World.Query(self: _World, ...: Types.Assembler<any>): QueryResult
	return QueryResultConstructor(self, ...)
end

function World.Has(self: _World, id: number): boolean
	if type(id) ~= "number" then error("Has() -> Argument #1 expected number, got " .. typeof(id), 2) end
	return if id < self._nextId and id > 0 and not self._missing[id] then true else false
end

function World.OnChange(self: _World, idOrAssembler: number | Types.Assembler<any>): Signal.Signal
	if type(idOrAssembler) ~= ("number" or "table") then error("OnChange() -> Argument #1 expected number or assembler, got " .. typeof(idOrAssembler), 2) end

	local index: number | string

	if type(idOrAssembler) == "table" and not Types.Assembler(idOrAssembler) then
		error("OnChange() -> Argument #1 expected assembler, got " .. typeof(index), 2)
	else
		index = tostring(idOrAssembler)
	end

	if not SignalCache[self][index] then
		SignalCache[self][index] = Signal(true)
	end

	return SignalCache[self][index]
end

function World.SpawnAt(self: _World, id: number, ...: Types.Component<any>): number
	if type(id) ~= "number" then error("SpawnAt() -> Argument #1 expected number, got " .. typeof(id), 2) end
	if self:Has(id) then error("SpawnAt() -> Desired entity (".. id ..") does already exist", 2) end

	local components: {Types.Component<any>} = {...}

	for index, component in components do
		if not Types.Component(component) then error("SpawnAt() -> Argument #".. 1 + index .." expected component, got " .. typeof(component), 2) end
		self:_Set(component.name, id, component.data)
	end

	if self._missing[id] then
		self._missing[id] = nil
	end

	-- If the new entity skips entities,
	-- those must be marked as missing

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

function World.Despawn(self: _World, id: number): ()
	if type(id) ~= "number" then error("Despawn() -> Argument #1 expected number, got " .. typeof(id), 2) end
	if not self:Has(id) then error("Despawn() -> Desired entity (".. id ..") does not exist", 2) end

	for component in self._storage do
		self:_Set(component, id, nil)

		if #self._storage[component] == 0 then -- Remove component key in storage if no more entities have it
			self._storage[component] = nil
		end
	end

	if #self._missing > id then -- Mark the entity as missing if there are more ahead of it
		self._missing[id] = true
	end

	self._size -= 1

	-- When the last listed entity is despawned, the nextId
	-- must be resetted to the last existing entity. This
	-- involves having to remove all the missing entities
	-- found between the despawned entity and the last one.

	if id == self._nextId - 1 then
		if self._size < id then -- Missing entities exist
			for possibleEntity = id - 1, 1, -1 do
				if self._missing[possibleEntity] then -- possibleEntity is missing
					self._missing[possibleEntity] = nil
				else
					self._nextId = possibleEntity + 1 -- possibleEntity is the last entity
					break
				end
			end
		else
			self._nextId -= 1
		end
	end
end

function World.Get(self: _World, id: number, ...: Types.Assembler<any>?): ...any | Types.Dictionary<any>
	if type(id) ~= "number" then error("Get() -> Argument #1 expected number, got " .. typeof(id), 2) end

	local assemblers = if ... then {...} else nil
	local componentsToReturn = if assemblers then table.create(#assemblers) :: {any} else {} :: Types.Dictionary<any>

	if assemblers then -- Returns a tuple of component data
		for index, assembler in assemblers :: {Types.Assembler<any>} do
			if not Types.Assembler(assembler) then error("Get() -> Argument #".. 1 + index .." expected assembler, got " .. typeof(assembler), 2) end
			if not self._storage[tostring(assembler)] then return nil :: any end

			local data = self._storage[tostring(assembler)][id];
			(componentsToReturn :: {any})[index] = data
		end

		return unpack(componentsToReturn :: {any})
	else -- Returns a dictionary with component data
		for component in self._storage do
			local data = self._storage[component][id];
			(componentsToReturn :: Types.Dictionary<any>)[component] = data
		end
		return componentsToReturn
	end
end

function World.Set(self: _World, id: number, ...: Types.Component<any>): ()
	if type(id) ~= "number" then error("Set() -> Argument #1 expected number, got " .. typeof(id), 2) end

	local components: {Types.Component<any>} = {...}

	for index, component in components do
		if not Types.Component(component) then error("Set() -> Argument #".. 1 + index .." expected component, got " .. typeof(component), 2) end
		self:_Set(component.name, id, component.data)
	end
end

function World.Update(self: _World, id: number, ...: Types.Component<{[any]: any}>): ()
	if type(id) ~= "number" then error("Update() -> Argument #1 expected number, got " .. typeof(id), 2) end

	local components: {Types.Component<{[any]: any}>} = {...}

	for index, component in components do
		if not Types.Component(component, true) then error("Set() -> Argument #".. 1 + index .." expected component, got " .. typeof(component), 2) end

		if type(self._storage[component.name][id]) == "table" then
			for _, value in component.data do
				self:_Set(component.name, id, if value == None then nil else value)
			end
		else
			self:_Set(component.name, id, component.data)
		end
	end
end

function World.Remove(self: _World, id: number, ...: Types.Assembler<any>): ()
	if type(id) ~= "number" then error("Remove() -> Argument #1 expected number, got " .. typeof(id), 2) end

	local assemblers: {Types.Assembler<any>} = {...}

	for index, assembler in assemblers do
		if not Types.Assembler(assembler) then error("Remove() -> Argument #".. 1 + index .." expected assembler, got " .. typeof(assembler), 2) end
		if not self._storage[tostring(assembler)] then continue end
		self:_Set(tostring(assembler), id, nil)
	end
end

local function WorldConstructor(): World
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

return WorldConstructor