local t = require(script.Parent.Parent.t)

local Types = {}

export type Dictionary = {
    [string]: any
}

export type Map = {
	[any]: any
}

export type Component<T> = {
	data: T,
	name: string
}

Types.Component = t.interface({
	data = t.any,
	name = t.string
})

export type ComponentAssociations = {
	[string]: {
		[number]: any
	}
}

Types.ComponentAssociations = t.interface({ [t.string] = t.array(t.any) })

export type Assembler = <T>(data: T) -> Component<T>

return Types