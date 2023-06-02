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
--   flamenco687 - June 2nd, 2023 - Modified for Puzzle.                      --
-- -----------------------------------------------------------------------------

-- The currently idle thread to run the next handler on
local freeRunnerThread = nil

-- Function which acquires the currently idle handler runner thread, runs the
-- function callback on it, and then releases the thread, returning it to being the
-- currently idle one.
-- If there was a currently idle runner thread already, that's okay, that old
-- one will just get thrown and eventually GCed.
local function acquireRunnerThreadAndCallEventHandler(callback: (...any) -> (...any), ...: any)
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

--[=[
	@within Signal
	@interface SignalConnection
	.Connected boolean
	.Disconnect (SignalConnection) -> ()

	Represents a connection to a signal.
	```lua
	local connection = signal:Connect(function() end)
	print(connection.Connected) --> true
	connection:Disconnect()
	print(connection.Connected) --> false
	```
]=]

-- Connection class
local Connection = {}
local ConnectionMetatable = { __index = Connection }

local function ConnectionConstructor(signal: Signal, callback: (...any) -> (...any)): Connection
    local self: ConnectionProperties & _ConnectionProperties = {
        Connected = true,
        _signal = signal,
        _callback = callback,
        _next = false,
    }
    return setmetatable(self, ConnectionMetatable) :: _Connection
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

		while previous and previous._next ~= self do
			previous = previous._next
		end

		if previous then
			previous._next = self._next
		end
	end

    if self._signal._destroyOnLastConnection and not self._signal._handlerListHead then self._signal:Destroy() end
end

function Connection.Destroy(self: _Connection)
    self:Disconnect()
end

-- Make Connection strict
setmetatable(Connection, {
	__index = function(_, key)
		error(("Attempt to get Connection::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(_, key)
		error(("Attempt to set Connection::%s (not a valid member)"):format(tostring(key)), 2)
	end,
})

--[=[
	@within Signal
	@type Connectioncallback (...any) -> ()

	A function connected to a signal.
]=]

--[=[
	@class Signal

	Signals allow events to be dispatched and handled.

	For example:
	```lua
	local signal = Signal.new()

	signal:Connect(function(msg)
		print("Got message:", msg)
	end)

	signal:Fire("Hello world!")
	```
]=]
local Signal = {}
local SignalMetatable = { __index = Signal }

--[=[
	Constructs a new Signal

	@return Signal
]=]
local function SignalConstructor(destroyOnLastConnection: true?): Signal
	local self: SignalProperties & _SignalProperties = {
        _handlerListHead = false,
        _proxyHandler = nil,
        _destroyOnLastConnection = destroyOnLastConnection
	}
	return setmetatable(self, SignalMetatable) :: _Signal
end

--[=[
	Constructs a new Signal that wraps around an RBXScriptSignal.

	@param rbxScriptSignal RBXScriptSignal -- Existing RBXScriptSignal to wrap
	@return Signal

	For example:
	```lua
	local signal = Signal.Wrap(workspace.ChildAdded)
	signal:Connect(function(part) print(part.Name .. " added") end)
	Instance.new("Part").Parent = workspace
	```
]=]
function Signal.Wrap(rbxScriptSignal: RBXScriptSignal): Signal
	if typeof(rbxScriptSignal) ~= "RBXScriptSignal" then
        error("Argument #1 to Signal.Wrap must be a RBXScriptSignal; got " .. typeof(rbxScriptSignal))
    end

	local signal = SignalConstructor()

	signal._proxyHandler = rbxScriptSignal:Connect(function(...)
		signal:Fire(...)
	end)

	return signal
end

--[=[
	@param callback Connectioncallback
	@return SignalConnection

	Connects a function to the signal, which will be called anytime the signal is fired.
	```lua
	signal:Connect(function(msg, num)
		print(msg, num)
	end)

	signal:Fire("Hello", 25)
	```
]=]
function Signal.Connect(self: _Signal, callback: (...any) -> (...any)): Connection
	local connection = ConnectionConstructor(self, callback)

	if self._handlerListHead then
		connection._next = self._handlerListHead
		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end

	return connection
end

--[=[
	@param callback Connectioncallback
	@return SignalConnection

	Connects a function to the signal, which will be called the next time the signal fires. Once
	the connection is triggered, it will disconnect itself.
	```lua
	signal:Once(function(msg, num)
		print(msg, num)
	end)

	signal:Fire("Hello", 25)
	signal:Fire("This message will not go through", 10)
	```
]=]
function Signal.Once(self: _Signal, callback: (...any) -> (...any))
	local connection: Connection
	local done = false

	connection = self:Connect(function(...)
		if done then
			return
		end

		done = true
		connection:Disconnect()
		callback(...)
	end)

	return connection
end

function Signal.GetConnections(self: _Signal)
	local items = {}
	local item = self._handlerListHead

	while item do
		table.insert(items, item)
		item = item._next
	end

	return items
end

-- Disconnect all handlers. Since we use a linked list it suffices to clear the
-- reference to the head handler.
--[=[
	Disconnects all connections from the signal.
	```lua
	signal:DisconnectAll()
	```
]=]
function Signal.DisconnectAll(self: _Signal)
	local item = self._handlerListHead

	while item do
		item.Connected = false
		item = item._next
	end

	self._handlerListHead = nil

    if self._destroyOnLastConnection then self:Destroy() end
end

-- Signal:Fire(...) implemented by running the handler functions on the
-- coRunnerThread, and any time the resulting thread yielded without returning
-- to us, that means that it yielded to the Roblox scheduler and has been taken
-- over by Roblox scheduling, meaning we have to make a new coroutine runner.
--[=[
	@param ... any

	Fire the signal, which will call all of the connected functions with the given arguments.
	```lua
	signal:Fire("Hello")

	-- Any number of arguments can be fired:
	signal:Fire("Hello", 32, {Test = "Test"}, true)
	```
]=]
function Signal.Fire(self: _Signal, ...: any)
	local item = self._handlerListHead

	while item do
		if item.Connected then
			if not freeRunnerThread then
				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
                -- Get the freeRunnerThread to the first yield
				coroutine.resume(freeRunnerThread)
			end

			task.spawn(freeRunnerThread, item._callback, ...)
		end
		item = item._next
	end
end

--[=[
	@param ... any

	Same as `Fire`, but uses `task.defer` internally & doesn't take advantage of thread reuse.
	```lua
	signal:FireDeferred("Hello")
	```
]=]
function Signal.FireDeferred(self: _Signal, ...: any)
	local item = self._handlerListHead

	while item do
		task.defer(item._callback, ...)
		item = item._next
	end
end

--[=[
	@return ... any
	@yields

	Yields the current thread until the signal is fired, and returns the arguments fired from the signal.
	Yielding the current thread is not always desirable. If the desire is to only capture the next event
	fired, using `Once` might be a better solution.
	```lua
	task.spawn(function()
		local msg, num = signal:Wait()
		print(msg, num) --> "Hello", 32
	end)
	signal:Fire("Hello", 32)
	```
]=]
function Signal.Wait(self: _Signal)
	local waitingCoroutine = coroutine.running()

	local connection: Connection
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

	local proxyHandler = rawget(self, "_proxyHandler")

	if proxyHandler then
		proxyHandler:Disconnect()
	end
end

-- Make signal strict
setmetatable(Signal, {
	__index = function(_, key)
		error(("Attempt to get Signal::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(_, key)
		error(("Attempt to set Signal::%s (not a valid member)"):format(tostring(key)), 2)
	end,
})

-->> Connection classes
export type Connection = ConnectionMethods & ConnectionProperties
export type _Connection = ConnectionMethods & _ConnectionProperties

-->> Connection methods
export type ConnectionMethods = typeof(Connection)

-->> Connection properties
export type ConnectionProperties = {
    Connected: boolean
}
export type _ConnectionProperties = ConnectionProperties & {
    _signal: Signal,
    _callback: (...any) -> (...any),
    _next: boolean
}

-->> Signal classes
export type Signal = SignalMethods & SignalProperties
export type _Signal = SignalMethods & _SignalProperties

-->> Signal methods
export type SignalMethods = typeof(Signal)

-->> Signal properties
export type SignalProperties = {}
export type _SignalProperties = SignalProperties & {
    _handlerListHead: Connection | false,
    _proxyHandler: RBXScriptConnection?,
    _destroyOnLastConnection: true?
}

return SignalConstructor