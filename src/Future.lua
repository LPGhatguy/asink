local Runtime = require(script.Parent.Runtime)

local Future = {}

Future.__index = Future

local function addListener(future, listener)
	if future.__resolved then
		Runtime.__runFutureListener(listener, future.__value)
		return
	end

	table.insert(future.__listeners, listener)
end

local function resolveFuture(future, value)
	if future.__resolved then
		return
	end

	future.__resolved = true
	future.__value = value

	for _, listener in ipairs(future.__listeners) do
		Runtime.__runFutureListener(listener, value)
	end
end

function Future.new()
	local future = setmetatable({
		[Future] = true,
		__resolved = false,
		__value = nil,
		__listeners = {},
	}, Future)

	local function resolve(value)
		resolveFuture(future, value)
	end

	return future, resolve
end

function Future.resolved(value)
	local future, resolve = Future.new()
	resolve(value)

	return future
end

function Future.isFuture(value)
	return type(value) == "table" and value[Future]
end

function Future:isResolved()
	return self.__resolved
end

function Future:unwrapOrDie()
	assert(Future.isFuture(self), "'self' must be a Future")

	if not self.__resolved then
		error("Future was not resolved.", 2)
	end

	return self.__value
end

function Future.all(futures)
	local outerFuture, resolve = Future.new()
	local result = {}
	local resolvedCount = 0

	for index, future in ipairs(futures) do
		addListener(future, function(value)
			resolvedCount = resolvedCount + 1
			result[index] = value

			if resolvedCount == #futures then
				resolve(result)
			end
		end)
	end

	if #futures == 0 then
		resolve(result)
	end

	return outerFuture
end

function Future:await()
	assert(Future.isFuture(self), "'self' must be a Future")

	if self.__resolved then
		return self.__value
	end

	local bindable = Instance.new("BindableEvent")

	local function listener()
		bindable:Fire()
	end

	addListener(self, listener)

	bindable.Event:Wait()

	return self.__value
end

-- Future<T>
-- param functor: T -> U
-- returns Future<U>
function Future:map(functor)
	assert(Future.isFuture(self), "'self' must be a Future")

	local newFuture, newResolve = Future.new()

	local function listener()
		local newValue = functor(self.__value)
		newResolve(newValue)
	end

	addListener(self, listener)

	return newFuture
end

-- Future<T>
-- param functor: T -> Future<U>
-- returns Future<U>
function Future:andThen(functor)
	assert(Future.isFuture(self), "'self' must be a Future")

	local newFuture, newResolve = Future.new()

	local function listener()
		local chainedFuture = functor(self.__value)

		assert(Future.isFuture(chainedFuture))

		chainedFuture:map(function(value)
			newResolve(value)
		end)
	end

	addListener(self, listener)

	return newFuture
end

function Future:__tostring()
	if self.__resolved then
		return ("Future(resolved: %s)"):format(tostring(self.__value))
	else
		return "Future(unresolved)"
	end
end

return Future