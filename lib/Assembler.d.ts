import { assembler } from ".";

interface Assembler {
	new <T>(name: string): assembler<T>;
}

declare const Assembler: Assembler;
export = Assembler;
