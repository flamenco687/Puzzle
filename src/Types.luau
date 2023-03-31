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

Types.Component = t.interface( { data = t.any, name = t.string } )

export type Assembler = <T>(data: T) -> Component<T>

-->> Storage

export type Storage = {
	[string]: { --> Entities per Component
		[number]: any --> Data per Id
	}
}

Types.Storage = t.interface( { [t.string] = t.array(t.any) } )

return Types