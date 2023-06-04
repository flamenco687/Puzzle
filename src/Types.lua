local t = require(script.Parent.Parent.t)

local Types = {}

export type Dictionary<Value> = {
    [string]: Value
}

export type Map<Key, Value> = {
	[Key]: Value
}

-->> Components

export type Component<T> = {
	data: T,
	name: string
}

Types.Component = t.interface({data = t.any, name = t.string})
Types.Components = t.tuple(Types.Component)

export type Assembler<T> = (data: T) -> Component<T>

function Types.Assembler(assembler: any): boolean
	if getmetatable(assembler :: any) and getmetatable(assembler :: any)._isAssembler then return true else return false end
end

-->> Storage

export type Storage = {
	[string]: { --> Ids per Component
		[number]: any --> Data per Id
	}
}

return Types