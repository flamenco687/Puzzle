-- This file provides compatibility for TypeScript syntax (new Class).
-- It is recommended for Lua code to directly require the modules so
-- that syntactic sugar can be applied when constructing objects.
return {
	Signal = { new = function(destroyOnLastConnection) return require(script.Signal)(destroyOnLastConnection) end },

	Assembler = { new = function(name) return require(script.Assembler)(name) end },
	World = { new = function(destroyProcedures) return require(script.World)(destroyProcedures) end },

	None = require(script.None)
}
