export type Dictionary = {
    [string]: any
}

export type Map = {
	[any]: any
}

export type ComponentInfo<T> = {
	data: T,
	name: string
}

export type ComponentAssociations = {
	[string]: {
		[number]: any
	}
}

return nil