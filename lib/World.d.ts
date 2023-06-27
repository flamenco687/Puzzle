import { Signal, DestroyProcedures, Component, assembler } from ".";

interface World {
	// eslint-disable-next-line @typescript-eslint/no-misused-new
	new (destroyProcedures?: DestroyProcedures): World;
	// Methods
	Size(): number;
	Has(id: number): boolean;
	OnChange(idOrassembler: number | assembler<unknown>): Signal;
	SpawnAt(id: number, ...components: LuaTuple<[Component<unknown>]>): number;
	Spawn(...components: LuaTuple<[Component<unknown>]>): number;
	Despawn(id: number): {};
	Get(id: number, ...assemblers: LuaTuple<[assembler<unknown>]>): LuaTuple<[unknown]> | Map<string, unknown>;
	Set(id: number, ...components: LuaTuple<[Component<unknown>]>): {};
	Update(id: number, ...components: LuaTuple<[Component<unknown>]>): {};
	Remove(id: number, ...assemblers: LuaTuple<[assembler<unknown>]>): {};
}

declare const World: World;
export = World;
