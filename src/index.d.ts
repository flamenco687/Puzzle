import Signal = require("./Signal");

import Assembler = require("./Assembler");
import World = require("./World");

import None from "./None";

// World
type DestroyProcedures = { ["string"]: (object: unknown) => {} };

// Components
interface Component<T> {
	data: T;
	name: string;
}
type assembler<T> = (data: T) => Component<T>;

// Signal
declare class Connection {
	Disconnect(): {};
}

export { Signal, Assembler, World, None, DestroyProcedures, Component, assembler, Connection };
