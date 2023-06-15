--!strict

--> Modules

local Signal = require(script.Parent.Signal)

local Types = require(script.Parent.Types)

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

--> World

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

--[=[
	@within World
	@type DestroyProcedures { [string]: (object: any, world: _World?) -> () }
]=]
type DestroyProcedures = {
	[string]: (object: any, world: _World?) -> ()
}

type _WorldProperties = {
	--[=[
		@within World
		@readonly
		@private

		@prop _destroyProcedures DestroyProcedures
	]=]
	_destroyProcedures: DestroyProcedures,

	--[=[
		@within World
		@readonly
		@private

		@prop _storage Types.Storage
	]=]
	_storage: Types.Storage,

	--[=[
		@within World
		@readonly
		@private

		@prop _missing {true?}
	]=]
	_missing: {true?},

	--[=[
		@within World
		@readonly
		@private

		@prop _nextId number
	]=]
	_nextId: number,

	--[=[
		@within World
		@readonly
		@private

		@prop _size number
	]=]
	_size: number
}

export type _World = _WorldProperties & {
	-- Private methods
	_FireListeners: (self: _World, component: string, id: number, oldValue: any?, newValue: any?) -> (),
	_Destroy: (self: _World, object: any) -> (),
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

--[=[
	@class World

	Main world class
]=]
local World = {}
local Metatable = { __index = World, _isWorld = true } -- Avoids inserting metamethods inside the methods table

type SignalCache = {
	[_World]: {
		[number | string]: Signal.Signal
	}
}

local SignalCache: SignalCache = {}

--> World: Private methods

--[=[
	@within World
	@private

	Fires Signal listeners for a component, and subsequentialy, an entity change.

	@method _FireListeners
	@param component string
	@param id number
	@param oldValue any?
	@param newValue any?
]=]
function World._FireListeners(self: _World, component: string, id: number, oldValue: any?, newValue: any?)
	local componentSignal, entitySignal = SignalCache[self][component], SignalCache[self][id]

	if componentSignal then componentSignal:Fire(id, oldValue, newValue) end
	if entitySignal then entitySignal:Fire(component, oldValue, newValue) end
end

--[=[
	@within World
	@private

	Handles destroy procedures for the given object. This object usually is the old value of a component.

	@method _Destroy
	@param object any
]=]
function World._Destroy(self: _World, object: any): ()
	if self._destroyProcedures[typeof(object)] then
		self._destroyProcedures[typeof(object)](object, self :: _World?)
	end
end

--[=[
	@within World
	@private

	Internally sets a new component value for the given entity, handling destroys and signal firing in the process.

	@method _Set
	@param component string
	@param id number
	@param value any
]=]
function World._Set(self: _World, component: string, id: number, value: any): ()
	if not self._storage[component] and value ~= nil then
		self._storage[component] = {}
	end

	local oldValue = self._storage[component][id]
	self:_Destroy(self._storage[component][id])

	self._storage[component][id] = value
	self:_FireListeners(component, id, oldValue, value)
end

--> World: Public methods

--[=[
	@within World

	Returns a QueryResult based on the given assemblers.

	@method Query
	@param ... Types.Assembler<any>
	@return QueryResult
]=]
function World.Query(self: _World, ...: Types.Assembler<any>): QueryResult
	return QueryResultConstructor(self, ...)
end

--[=[
	@within World

	Checks if the world contains the requested entity or not.

	@method Has
	@param id number
	@return boolean
]=]
function World.Has(self: _World, id: number): boolean
	if type(id) ~= "number" then error("Has() -> Argument #1 expected number, got " .. typeof(id), 2) end
	return if id < self._nextId and id > 0 and not self._missing[id] then true else false
end

--[=[
	@within World

	Returns a Signal that fires its listeners on component or entity changes.

	@method OnChange
	@param idOrAssembler number | Types.Assembler<any>
	@return Signal
]=]
function World.OnChange(self: _World, idOrAssembler: number | Types.Assembler<any>): Signal.Signal
	if type(idOrAssembler) ~= "number" and type(idOrAssembler) ~= "table" then error("OnChange() -> Argument #1 expected number or assembler, got " .. typeof(idOrAssembler), 2) end

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


--[=[
	@within World

	Spawns an entity at the given position.

	@method SpawnAt
	@param id number
	@param ... Types.Component<any>
	@return number
]=]
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


--[=[
	@within World

	Spawns an entity with the world's next id.

	@method Spawn
	@param ... Types.Component<any>
	@return number
]=]
function World.Spawn(self: _World, ...: Types.Component<any>): number
	return self:SpawnAt(self._nextId, ...)
end

--[=[
	@within World

	Despawns a given entity destroying all of its components.

	@method Despawn
	@param id number
]=]
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

--[=[
	@within World

	Returns some or all of the components data from the desired entity.

	@method Get
	@param id number
	@param ... Types.Assembler<any>? -- If set, the function will return a tuple of components in this order
	@return ...any | Types.Dictionary<any>
]=]
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

--[=[
	@within World

	Sets a new value for the given components.

	@method Set
	@param id number
	@param ... Types.Component<any>
]=]
function World.Set(self: _World, id: number, ...: Types.Component<any>): ()
	if type(id) ~= "number" then error("Set() -> Argument #1 expected number, got " .. typeof(id), 2) end

	local components: {Types.Component<any>} = {...}

	for index, component in components do
		if not Types.Component(component) then error("Set() -> Argument #".. 1 + index .." expected component, got " .. typeof(component), 2) end
		self:_Set(component.name, id, component.data)
	end
end

--[=[
	@within World

	Updates existing table components with the new keys from the given components. If the table component does not already exist, this acts just as [World:Set]

	@method Update
	@param id number
	@param ... Types.Component<{[any] : any}>
]=]
function World.Update(self: _World, id: number, ...: Types.Component<{[any]: any}>): ()
	if type(id) ~= "number" then error("Update() -> Argument #1 expected number, got " .. typeof(id), 2) end

	local components: {Types.Component<{[any]: any}>} = {...}

	for index, component in components do
		if not Types.Component(component, true) then error("Set() -> Argument #".. 1 + index .." expected component, got " .. typeof(component), 2) end

		if self._storage[component.name] and type(self._storage[component.name][id]) == "table" then
			local oldValue = self._storage[component.name][id]

			for key, value in component.data do
				self:_Destroy(self._storage[component.name][id][key])
				self._storage[component.name][id][key] = value
			end

			self:_FireListeners(component.name, id, oldValue, self._storage[component.name][id])
		else
			self:_Set(component.name, id, component.data)
		end
	end
end

--[=[
	@within World

	Removes the given components from the entity.

	@method Update
	@param id number
	@param ... Types.Assembler<any>
]=]
function World.Remove(self: _World, id: number, ...: Types.Assembler<any>): ()
	if type(id) ~= "number" then error("Remove() -> Argument #1 expected number, got " .. typeof(id), 2) end

	local assemblers: {Types.Assembler<any>} = {...}

	for index, assembler in assemblers do
		if not Types.Assembler(assembler) then error("Remove() -> Argument #".. 1 + index .." expected assembler, got " .. typeof(assembler), 2) end
		if not self._storage[tostring(assembler)] then continue end
		self:_Set(tostring(assembler), id, nil)
	end
end

local function DestroyTable(object: {[any]: any}, world: _World)
	if type(object.Destroy) == "function" then
		object:Destroy()
	elseif type(object.Disconnect) == "function" then
		object:Disconnect()
	else
		for _, child in object do
			world:_Destroy(child)
		end
		setmetatable(object, nil)
	end
end

--[=[
	@within World

	Constructs a new World.

	@function WorldConstructor
	@param destroyProcedures DestroyProcedures?
	@return World
]=]
local function WorldConstructor(destroyProcedures: DestroyProcedures?): World
	local properties: _WorldProperties = {
		_destroyProcedures = if destroyProcedures then destroyProcedures else {
			["table"] = DestroyTable,

			["thread"] = function(object: thread)
				task.cancel(object)
			end,

			["function"] = function(object: (...any) -> ...any)
				object()
			end,

			["Instance"] = function(object: Instance)
				object:Destroy()
			end,

			["RBXScriptConnection"] = function(object: RBXScriptConnection)
				object:Disconnect()
			end
		},
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