"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[305],{75797:e=>{e.exports=JSON.parse('{"functions":[{"name":"Without","desc":"Returns a QueryResult without including the given assemblers.","params":[{"name":"...","desc":"","lua_type":"Assembler<any>"}],"returns":[{"desc":"","lua_type":"QueryResult"}],"function_type":"method","source":{"line":106,"path":"src/World.lua"}},{"name":"Constructor","desc":"","params":[{"name":"...","desc":"","lua_type":"Assembler<any>"}],"returns":[{"desc":"","lua_type":"QueryResult"}],"function_type":"static","tags":["Constructor"],"private":true,"source":{"line":138,"path":"src/World.lua"}}],"properties":[{"name":"_world","desc":"","lua_type":"World","private":true,"readonly":true,"source":{"line":88,"path":"src/Types.lua"}},{"name":"_queryResultId","desc":"","lua_type":"string","private":true,"readonly":true,"source":{"line":96,"path":"src/Types.lua"}},{"name":"_with","desc":"","lua_type":"{Assembler<any>}","private":true,"readonly":true,"source":{"line":104,"path":"src/Types.lua"}},{"name":"_without","desc":"","lua_type":"{Assembler<any>}?","private":true,"readonly":true,"source":{"line":112,"path":"src/Types.lua"}},{"name":"_isQueryResult","desc":"","lua_type":"true","tags":["Metatable"],"private":true,"readonly":true,"source":{"line":25,"path":"src/World.lua"}}],"types":[{"name":"QueryResultCache","desc":"","lua_type":"{[World]: {[string]: QueryResult}}","private":true,"source":{"line":76,"path":"src/World.lua"}}],"name":"QueryResult","desc":"QueryResults are the main way of interacting with [World] data in systems.\\n\\n---\\n\\nQueryResults are iterable objects which return the results of a **component query**, a list of requested components and their associated\\nids generated by [`World:Query`](World#Query).","source":{"line":36,"path":"src/World.lua"}}')}}]);