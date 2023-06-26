--!strict

--> Modules

local Types = require(script.Parent.Types)

local None = require(script.Parent.None)

--> Assembler

export type Assembler<T> = Types.Assembler<T>
export type _Assembler<T> = Types._Assembler<T>

--[=[
	@within Assembler
	@readonly
	@private

	@tag Metatable

	@prop _isAssembler true
]=]

--[=[
	@class Assembler

	Assemblers are the factories of components, they assemble them.

	---

	Assemblers act as a function that takes an input data and outputs a [Types.Component] containing that data.
	These components can then be used by the [World]. Assemblers can also be useful if the component name is needed.
	because it inherits from the assembler and can be retrieved with `tostring(assembler)`.

	```lua
	local Position: Puzzle.Assembler<Vector3> = Assembler "Position"

	print(tostring(Position)) -- "Position"

	world:Spawn(
		Position(Vector3.new(6, 8, 7)) -- The assembler is used to create a component with data
	)

	world:Get(1, Position) -- The assembler is used to search for the name of the desired component
	```
]=]
local Assembler = { _isAssembler = true }

--> Assembler: Metamethods

--[=[
	@within Assembler

	@method __call
	@param data T
	@return Component<T>
]=]
function Assembler.__call<T>(self: _Assembler<T>, data: T): Types.Component<T>
	return {data = if data == nil then None :: any else data, name = self._name}
end

--[=[
	@within Assembler

	@function __tostring
	@param self Assembler
	@return string
]=]
function Assembler.__tostring<T>(self: _Assembler<T>): string
	return self._name
end

--[=[
	@within Assembler

	@tag Constructor

	:::info Puzzle constructors are special
	Constructors are returned by the module and called like *local functions* instead of acting like class functions.

	```lua
	local Assembler = require(Puzzle.Assembler)
	local assembler = Assembler "Name"
	```
	:::

	Constructs a new Assembler.

	@function Constructor
	@param name string
	@return Assembler
]=]
local function Constructor<T>(name: string): Assembler<T>
	if type(name) ~= "string" then error("New Assembler -> Argument #1 expected string, got "..typeof(name), 2) end

	local self: _Assembler<T> = {
		_name = name,
	}

	return setmetatable(self, Assembler) :: any
end

return Constructor