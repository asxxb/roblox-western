--!strict
--[[
	Signal.luau
	High-performance, pure Luau typed Signal (observer) implementation.
	Features: Safe disconnected nodes, fast iteration, and zero external dependencies.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	Destroy: (self: Signal<T...>) -> (),
}

type Node<T...> = {
	Handler: (T...) -> (),
	Next: Node<T...>?,
	Prev: Node<T...>?,
	Connected: boolean,
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({
		_head = nil :: Node<T...>?,
		_tail = nil :: Node<T...>?,
	}, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal.Connect<T...>(self: any, handler: (T...) -> ()): Connection
	local node: Node<T...> = {
		Handler = handler,
		Next = nil,
		Prev = self._tail,
		Connected = true,
	}

	if self._tail then
		self._tail.Next = node
	else
		self._head = node
	end
	self._tail = node

	local connection: Connection
	connection = {
		Connected = true,
		Disconnect = function()
			if not connection.Connected then
				return
			end
			connection.Connected = false
			node.Connected = false

			if node.Prev then
				node.Prev.Next = node.Next
			else
				self._head = node.Next
			end

			if node.Next then
				node.Next.Prev = node.Prev
			else
				self._tail = node.Prev
			end
		end,
	}

	return connection
end

function Signal.Once<T...>(self: any, handler: (T...) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal.Fire<T...>(self: any, ...: T...)
	local current = self._head
	while current do
		local nextNode = current.Next
		if current.Connected then
			task.spawn(current.Handler, ...)
		end
		current = nextNode
	end
end

function Signal.Wait<T...>(self: any): T...
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.Destroy<T...>(self: any)
	local current = self._head
	while current do
		current.Connected = false
		current = current.Next
	end
	self._head = nil
	self._tail = nil
end

return Signal
