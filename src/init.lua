local Signal = require(script.Signal)

--[=[
	@within Types
	@readonly

	@prop Signal Signal
]=]

--[=[
	@within Types
	@readonly

	@prop Assembler Assembler
]=]

--[=[
	@within Types
	@readonly

	@prop World World
]=]

--[=[
	@within Types
	@readonly

	@prop None None

	None is a unique symbol that replaces `nil` values in components. Some components may be used just as tags, with `data == nil`, but
	missing components are also internally shown as `nil`. None is used as a marker value in these cases.

	Since it is a unique table, `None` represents `nil` always and anywhere. If working with [World:Get], expected `nil` component values
	will appear as `None`.

	:::caution
	```lua
	local function ValueShouldBeNil(componentValue: Puzzle.None)
		if componentValue then
			-- Normally, this conditional would have failed but None is a positive value
			print("The component value is not nil but None!")
		end
	end
	```
	:::
]=]

--[=[
	@class Types

	Types serves as storage for types & functions used across the
	library. Internally, Types (**Puzzle**) is the parent of all the modules.

	---

	All types used in Puzzle are exported for use in other modules which also re-export them, making it possible to use types both from this
	module and from the required module. Scripts of the library modules are also exposed for them to be required.

	This is a recommended structure for systems that run Puzzle:

	```lua
	local Puzzle = require(Path.To.Puzzle)

	-- Note that returned modules by Puzzle are given as to-be required scripts
	local Assembler = require(Puzzle.Assembler)
	local World = require(Puzzle.World)

	local Assembler: Puzzle.Assembler<Color3> = Assembler "Color"

	-- If dealing with argument or variable types, use Puzzle.Type preferably
	local function PuzzleWorld(world: Puzzle.World) end

	-- The main class can also be used for types but it looks odd
	local function WorldWorld(world: World.World) end
	```
]=]
local Types = {
    Signal = script.Signal,

    Assembler = script.Assembler,
    World = script.World,

    None = script.None
}

--> QueryResult

--[=[
	@within QueryResult
	@readonly
	@private

	@prop _world World
]=]

--[=[
	@within QueryResult
	@readonly
	@private

	@prop _queryResultId string
]=]

--[=[
	@within QueryResult
	@readonly
	@private

	@prop _with {Assembler<any>}
]=]

--[=[
	@within QueryResult
	@readonly
	@private

	@prop _without {Assembler<any>}?
]=]
export type _QueryResultProperties = {
	_world: _World,
	_queryResultId: string,
	_with: {Assembler<any>},
	_without: {Assembler<any>}?
}

export type QueryResult = {
	-- Public methods
	Without: (self: QueryResult, ...Assembler<any>) -> QueryResult
}

export type _QueryResult = _QueryResultProperties & {
	-- Public methods
	Without: (self: _QueryResult, ...Assembler<any>) -> QueryResult
}

--> World

--[=[
	@within World
	@private

	@type Storage {[string]: {[number]: any}}
]=]
type Storage = {
	[string]: { --> Ids per component
		[number]: any --> Data per id
	}
}

--[=[
	@within World

	@type DestroyProcedures {[string]: (object: any, world: World?) -> ()}
]=]
export type DestroyProcedures = {
	[string]: (object: any, world: _World?) -> ()
}

--[=[
	@within World
	@readonly
	@private

	@prop _destroyProcedures DestroyProcedures
]=]

--[=[
	@within World
	@readonly
	@private

	@prop _storage Types.Storage
]=]

--[=[
	@within World
	@readonly
	@private

	@prop _missing {true?}
]=]

--[=[
	@within World
	@readonly
	@private

	@prop _nextId number
]=]

--[=[
	@within World
	@readonly
	@private

	@prop _size number
]=]
export type _WorldProperties = {
	_destroyProcedures: DestroyProcedures,
	_storage: Storage,
	_missing: {true?},
	_nextId: number,
	_size: number
}

export type World = {
	-- Public methods
	OnChange: (self: World, index: number | Assembler<any>) -> Signal.Signal,
	Has: (self: World, id: number) -> boolean,
	Query: (self: World, ...Assembler<any>) -> QueryResult,
	SpawnAt: (self: World, id: number, ...Component<any>) -> number,
	Spawn: (self: World, ...Component<any>) -> number,
	Despawn: (self: World, id: number) -> (),
	Get: (self: World, id: number, ...Assembler<any>?) -> (...any | Dictionary<any>),
	Set: (self: World, id: number, ...Component<any>) -> (),
	Update: (self: World, id: number, ...Component<{[any]: any}>) -> (),
	Remove: (self: World, id: number, ...Assembler<any>) -> (),
}

export type _World = _WorldProperties & {
	-- Private methods
	_FireListeners: (self: _World, component: string, id: number, oldValue: any?, newValue: any?) -> (),
	_Destroy: (self: _World, object: any) -> (),
	_Set: (self: _World, component: string, id: number, value: any) -> (),
	-- Public methods
	OnChange: (self: _World, index: number | Assembler<any>) -> Signal.Signal,
	Has: (self: _World, id: number) -> boolean,
	Query: (self: _World, ...Assembler<any>) -> QueryResult,
	SpawnAt: (self: _World, id: number, ...Component<any>) -> number,
	Spawn: (self: _World, ...Component<any>) -> number,
	Despawn: (self: _World, id: number) -> (),
	Get: (self: _World, id: number, ...Assembler<any>?) -> (...any | Dictionary<any>),
	Set: (self: _World, id: number, ...Component<any>) -> (),
	Update: (self: _World, id: number, ...Component<{[any]: any}>) -> (),
	Remove: (self: _World, id: number, ...Assembler<any>) -> (),
}

--> Generics

export type Dictionary<Value> = {
    [string]: Value
}

export type Map<Key, Value> = {
	[Key]: Value
}

--> Component and Assembler

--[=[
	@within Types
	@interface Component
	.data T
	.name string
]=]
export type Component<T> = {
	data: T,
	name: string
}

--[=[
    @within Types

    @tag Assert

    Checks if the given value is a component. Additionally, check if the component data is a table by passing the second argument.

    @function Component
    @param value any
    @param dataIsTable boolean?
    @return boolean
]=]
function Types.Component(value: any, dataIsTable: boolean?): boolean
	if type(value) == "table" and (if not dataIsTable then value.data ~= nil else type(value.data) == "table") and type(value.name) == "string" then
		return true else return false
	end
end

--[=[
	@within Assembler

	@type Assembler<T> (data: T) -> Component<T>
]=]
export type Assembler<T> = (data: T) -> Component<T>

--[=[
	@within Assembler
	@readonly
	@private

	@prop _name string
]=]
export type _Assembler<T> = {
	_name: string
}

--[=[
    @within Types

    @tag Assert

    Checks if the given value is an assembler.

    @function Assembler
    @param assembler any
    @return boolean
]=]
function Types.Assembler(value: any): boolean
	if getmetatable(value) and getmetatable(value)._isAssembler then return true else return false end
end

return Types