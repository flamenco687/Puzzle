local Types = {}

export type Dictionary<Value> = {
    [string]: Value
}

export type Map<Key, Value> = {
	[Key]: Value
}

function Types.Component(value: any, dataIsTable: boolean?): true?
	if type(value) == "table" and (if not dataIsTable then value.data ~= nil else type(value.data) == "table") and type(value.name) == "string" then
		return true
	end
end

-->> Components

export type Component<T> = {
	data: T,
	name: string
}

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