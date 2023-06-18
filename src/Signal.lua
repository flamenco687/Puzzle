--!strict

-- -----------------------------------------------------------------------------
--               Batched Yield-Safe Signal Implementation                     --
-- This is a Signal class which has effectively identical behavior to a       --
-- normal RBXScriptSignal, with the only difference being a couple extra      --
-- stack frames at the bottom of the stack trace when an error is thrown.     --
-- This implementation caches runner coroutines, so the ability to yield in   --
-- the signal handlers comes at minimal extra cost over a naive signal        --
-- implementation that either always or never spawns a thread.                --
--                                                                            --
-- API:                                                                       --
--   local Signal = require(THIS MODULE)                                      --
--   local sig = Signal.new()                                                 --
--   local connection = sig:Connect(function(arg1, arg2, ...) ... end)        --
--   sig:Fire(arg1, arg2, ...)                                                --
--   connection:Disconnect()                                                  --
--   sig:DisconnectAll()                                                      --
--   local arg1, arg2, ... = sig:Wait()                                       --
--                                                                            --
-- License:                                                                   --
--   Licensed under the MIT license.                                          --
--                                                                            --
-- Authors:                                                                   --
--   stravant - July 31st, 2021 - Created the file.                           --
--   sleitnick - August 3rd, 2021 - Modified for Knit.                        --
--   flamenco687 - June 4th, 2023 - Modified for Puzzle.                      --
-- -----------------------------------------------------------------------------

-- The currently idle thread to run the next handler on
local freeRunnerThread = nil

-- Function which acquires the currently idle handler runner thread, runs the
-- function callback on it, and then releases the thread, returning it to being the
-- currently idle one.
-- If there was a currently idle runner thread already, that's okay, that old
-- one will just get thrown and eventually GCed.
local function acquireRunnerThreadAndCallEventHandler(callback: Callback, ...: any)
	local acquiredRunnerThread = freeRunnerThread
	freeRunnerThread = nil
	callback(...)
	-- The handler finished running, this runner thread is free again.
	freeRunnerThread = acquiredRunnerThread
end

-- Coroutine runner that we create coroutines of. The coroutine can be
-- repeatedly resumed with functions to run followed by the argument to run
-- them with.
local function runEventHandlerInFreeThread()
	-- Note: We cannot use the initial set of arguments passed to
	-- runEventHandlerInFreeThread for a call to the handler, because those
	-- arguments would stay on the stack for the duration of the thread's
	-- existence, temporarily leaking references. Without access to raw bytecode
	-- there's no way for us to clear the "..." references from the stack.

	while true do
		acquireRunnerThreadAndCallEventHandler(coroutine.yield())
	end
end

--> Connection

--[=[
	@within Signal

	@type Callback (...any) -> ()
]=]
type Callback = (...any) -> ()

export type ConnectionProperties = {
	Connected: boolean
}

export type _ConnectionProperties = {
	Connected: boolean,
	_signal: _Signal,
	_callback: Callback,
	_next: _Connection | false
}

export type Connection = ConnectionProperties & {
	Disconnect: (self: Connection) -> (),
}

export type _Connection = _ConnectionProperties & {
	Disconnect: (self: _Connection) -> (),
}

--[=[
	@within Signal

	@interface Connection
	.Connected boolean
	.Disconnect (Connection) -> () -- Method

	Represents a connection between a [Callback] and a [Signal].
	```lua
	local connection = signal:Connect(function() end)

	print(connection.Connected) --> true
	connection:Disconnect()
	print(connection.Connected) --> false
	```
]=]
local Connection = {}
local ConnectionMetatable = { __index = Connection }

local function ConnectionConstructor(signal: _Signal, callback: Callback): Connection
    local properties: _ConnectionProperties = {
        Connected = true,
        _signal = signal,
        _callback = callback,
        _next = false
    }

	local self: _Connection = setmetatable(properties, ConnectionMetatable) :: any

    return self :: Connection
end

function Connection.Disconnect(self: _Connection)
	if not self.Connected then
		return
	end

	self.Connected = false

	-- Unhook the node, but DON'T clear it. That way any fire calls that are
	-- currently sitting on this node will be able to iterate forwards off of
	-- it, but any subsequent fire calls will not hit it, and it will be GCed
	-- when no more fire calls are sitting on it.
	if self._signal._handlerListHead == self then
		self._signal._handlerListHead = self._next
	else
		local previous = self._signal._handlerListHead

		while previous and (previous :: _Connection)._next ~= self do
			previous = (previous :: _Connection)._next
		end

		if previous then
			(previous :: _Connection)._next = self._next
		end
	end

    if self._signal._destroyOnLastConnection and not self._signal._handlerListHead then self._signal:Destroy() end
end

--> Signal

--[=[
	@within Signal
	@private

	@prop _handlerListHead Connection | false
]=]

--[=[
	@within Signal
	@private

	@prop _proxyHandler RBXScriptConnection?
]=]

--[=[
	@within Signal
	@private

	@prop _destroyOnLastConnection true?
]=]
export type _SignalProperties = {
	_handlerListHead: _Connection | false,
	_proxyHandler: RBXScriptConnection?,
	_destroyOnLastConnection: true?
}

export type Signal = {
	Wrap: (rbxScriptSignal: RBXScriptSignal) -> (),
	-- Methods
	Fire: (self: Signal, ...any) -> (),
	FireDeferred: (self: Signal, ...any) -> (),
	Connect: (self: Signal, callback: (...any) -> ()) -> Connection,
	Once: (self: Signal, callback: (...any) -> ()) -> Connection,
	DisconnectAll: (self: Signal) -> (),
	GetConnections: (self: Signal) -> { Connection },
	Destroy: (self: Signal) -> (),
	Wait: (self: Signal) -> ...any,
}

export type _Signal = _SignalProperties & {
	Wrap: (rbxScriptSignal: RBXScriptSignal) -> (),
	-- Methods
	Fire: (self: _Signal, ...any) -> (),
	FireDeferred: (self: _Signal, ...any) -> (),
	Connect: (self: _Signal, callback: (...any) -> (...any)) -> Connection,
	Once: (self: _Signal, callback: (...any) -> (...any)) -> Connection,
	DisconnectAll: (self: _Signal) -> (),
	GetConnections: (self: _Signal) -> { Connection },
	Destroy: (self: _Signal) -> (),
	Wait: (self: _Signal) -> ...any,
}

--[=[
	@class Signal

	Signals allow events to be dispatched and handled.

	---

	```lua
	local signal = Signal()

	signal:Connect(function(message)
		print("Got message:", message)
	end)

	signal:Fire("Hello world!")
	```
]=]
local Signal = {}
local SignalMetatable = { __index = Signal }

--[=[
	@within Signal

	@tag Constructor

	@function Constructor
	@param destroyOnLastConnection true?
	@return Signal

	:::info Puzzle constructors are special
	Constructors are returned by the module and called like *local functions* instead of acting like class functions.

	```lua
	local signal = Signal()
	```
	:::
]=]
local function SignalConstructor(destroyOnLastConnection: true?): Signal
	local properties: _SignalProperties = {
        _handlerListHead = false,
        _destroyOnLastConnection = destroyOnLastConnection
	}

	local self: _Signal = setmetatable(properties, SignalMetatable) :: any

	return self :: Signal
end

--[=[
	@within Signal

	@function Wrap
	@param rbxScriptSignal RBXScriptSignal -- Existing RBXScriptSignal to wrap
	@return Signal

	Constructs a new Signal that wraps around an RBXScriptSignal.

	```lua
	local signal = Signal.Wrap(workspace.ChildAdded)

	signal:Connect(function(instance)
		print(instance.Name .. " added")
	end)

	Instance.new("Part", workspace)
	```
]=]
function Signal.Wrap(rbxScriptSignal: RBXScriptSignal)
	if typeof(rbxScriptSignal) ~= "RBXScriptSignal" then
        error("Argument #1 to Signal.Wrap must be a RBXScriptSignal; got " .. typeof(rbxScriptSignal))
    end

	local signal = SignalConstructor() :: _Signal

	signal._proxyHandler = rbxScriptSignal:Connect(function(...)
		signal:Fire(...)
	end)

	return signal
end

--[=[
	@within Signal

	@method Connect
	@param callback Callback
	@return Connection

	Connects a function to the signal, which will be called anytime the signal is fired.

	```lua
	signal:Connect(function(message, number)
		print(message, number)
	end)

	signal:Fire("Hello", 25)
	```
]=]
function Signal.Connect(self: _Signal, callback: Callback)
	local connection = ConnectionConstructor(self, callback) :: _Connection

	if self._handlerListHead then
		connection._next = self._handlerListHead
		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end

	return connection
end

--[=[
	@within Signal

	@method Once
	@param callback Callback
	@return Connection

	Connects a function to the signal, which will be called the next time the signal fires. Once
	the connection is triggered, it will disconnect itself.

	```lua
	signal:Once(function(message, number)
		print(message, number)
	end)

	signal:Fire("Hello", 25)
	signal:Fire("This message will not go through", 10)
	```
]=]
function Signal.Once(self: _Signal, callback: Callback)
	local connection
	local done = false

	connection = self:Connect(function(...)
		if done then
			return
		end

		done = true
		connection:Disconnect()
		callback(...)
	end) :: _Connection

	return connection
end

--[=[
	@within Signal

	@method GetConnections
	@return {Connection}

	Gets all connections from the signal.

	```lua
	signal:Connect(function(A) end)
	signal:Connect(function(B) end)

	print(#signal:GetConnections()) -- 2
	```
]=]
function Signal.GetConnections(self: _Signal)
	local items: {Connection} = {}
	local item = self._handlerListHead

	while item do
		table.insert(items, item :: _Connection)
		item = (item :: _Connection)._next
	end

	return items
end

-- Disconnect all handlers. Since we use a linked list it suffices to clear the
-- reference to the head handler.
--[=[
	@within Signal

	@method DisconnectAll

	Disconnects all connections from the signal.

	```lua
	signal:Connect(function(A) end)
	signal:Connect(function(B) end)

	signal:DisconnectAll()
	```
]=]
function Signal.DisconnectAll(self: _Signal)
	if self._destroyOnLastConnection then self:Destroy() end

	local item = self._handlerListHead :: _Connection

	while item do
		item.Connected = false
		item = item._next :: _Connection
	end

	self._handlerListHead = false
end

-- Signal:Fire(...) implemented by running the handler functions on the
-- coRunnerThread, and any time the resulting thread yielded without returning
-- to us, that means that it yielded to the Roblox scheduler and has been taken
-- over by Roblox scheduling, meaning we have to make a new coroutine runner.
--[=[
	@within Signal

	@method Fire
	@param ... any

	Fire the signal, which will call all of the connected functions with the given arguments.

	```lua
	signal:Fire("Hello")

	-- Any number of arguments can be fired:
	signal:Fire("Hello", 32, {Test = "Test"}, true)
	```
]=]
function Signal.Fire(self: _Signal, ...: any)
	local item = self._handlerListHead :: _Connection

	while item do
		if item.Connected then
			if not freeRunnerThread then
				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread) :: any
                -- Get the freeRunnerThread to the first yield
				coroutine.resume(freeRunnerThread :: any)
			end

			task.spawn(freeRunnerThread :: any, item._callback, ...)
		end
		item = item._next :: _Connection
	end
end

--[=[
	@within Signal

	@method FireDeferred
	@param ... any

	Same as [`Signal:Fire`](Signal#Fire), but uses [`task.defer`](https://create.roblox.com/docs/reference/engine/libraries/task#task.defer) internally & doesn't take advantage of thread reuse.

	```lua
	signal:FireDeferred("Hello")
	```
]=]
function Signal.FireDeferred(self: _Signal, ...: any)
	local item = self._handlerListHead :: _Connection

	while item do
		task.defer(item._callback, ...)
		item = item._next :: _Connection
	end
end

--[=[
	@within Signal

	@method Wait
	@return ... any
	@yields

	Yields the current thread until the signal is fired, and returns the arguments fired from the signal.
	Yielding the current thread is not always desirable. If the desire is to only capture the next event
	fired, using [`Signal:Once`](Signal#Once) might be a better solution.

	```lua
	task.spawn(function()
		local message, number = signal:Wait()
		print(message, number) --> "Hello", 32
	end)

	signal:Fire("Hello", 32)
	```
]=]
function Signal.Wait(self: _Signal)
	local waitingCoroutine = coroutine.running()

	local connection
	local done = false

	connection = self:Connect(function(...)
		if done then
			return
		end

		done = true
		connection:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)

	return coroutine.yield()
end

--[=[
	@within Signal

	@method Destroy

	Cleans up the signal.

	Technically, this is only necessary if the signal is created using
	`Signal.Wrap`. Connections should be properly GC'd once the signal
	is no longer referenced anywhere. However, it is still good practice
	to include ways to strictly clean up resources. Calling `Destroy`
	on a signal will also disconnect all connections immediately.

	```lua
	signal:Destroy()
	```
]=]
function Signal.Destroy(self: _Signal)
	self:DisconnectAll()

	local proxyHandler = rawget(self :: {}, "_proxyHandler")

	if proxyHandler then
		proxyHandler:Disconnect()
	end
end

return SignalConstructor