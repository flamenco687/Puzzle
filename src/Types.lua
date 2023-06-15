local Types = {}

--> Generics

export type Dictionary<Value> = {
    [string]: Value
}

export type Map<Key, Value> = {
	[Key]: Value
}

function Types.Component(value: any, dataIsTable: boolean?): boolean
	if type(value) == "table" and (if not dataIsTable then value.data ~= nil else type(value.data) == "table") and type(value.name) == "string" then
		return true else return false
	end
end

--> Components & Assemblers

export type Component<T> = {
	data: T,
	name: string
}

export type Assembler<T> = (data: T) -> Component<T>

function Types.Assembler(assembler: any): boolean
	if getmetatable(assembler) and getmetatable(assembler)._isAssembler then return true else return false end
end

--> Storage

export type Storage = {
	[string]: { --> Ids per component
		[number]: any --> Data per id
	}
}

return Types