import { Connection } from ".";

interface Signal {
	// eslint-disable-next-line @typescript-eslint/no-misused-new
	new (destroyOnLastConnection?: true): Signal;
	// Methods
	Wrap(this: void, rbxScriptSignal: RBXScriptSignal): Signal;
	Connect(callback: Callback): Connection;
	Once(callback: Callback): Connection;
	GetConnections(): [Connection];
	Disconnectall(): {};
	Fire(...any: LuaTuple<[unknown]>): {};
	FireDeferred(...any: LuaTuple<[unknown]>): {};
	Wait(): thread;
	Destroy(): {};
}

declare const Signal: Signal;
export = Signal;
