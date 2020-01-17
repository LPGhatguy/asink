local Cancelable = {}
Cancelable.__index = Cancelable

local function createCancelable(completed, value)
	return setmetatable({
		[Cancelable] = true,
		__completed = completed,
		__value = value,
	}, Cancelable)
end

function Cancelable.completed(value)
	return createCancelable(true, value)
end

function Cancelable.canceled()
	return createCancelable(false)
end

function Cancelable.isCancelable(value)
	return type(value) == "table" and value[Cancelable]
end

function Cancelable:unpack()
	return self.__completed, self.__value
end

function Cancelable:unwrapOrDie()
	assert(Cancelable.isCancelable(self), "'self' must be a Cancelable")
	assert(message == nil or type(message) == "string", "'message' must be nil or a string")

	if not self.__completed then
		if message ~= nil then
			error(("Cancelable:unwrapOrDie() failed: %s"):format(message), 2)
		else
			error("Cancelable:unwrapOrDie() failed", 2)
		end
	end

	return self.__value
end

function Cancelable:isCompleted()
	return self.__completed
end

function Cancelable:isCanceled()
	return not self.__completed
end

function Cancelable:map(functor)
	assert(Cancelable.isCancelable(self), "'self' must be a Cancelable")

	if self.__completed then
		return Cancelable.completed((functor(self.__value)))
	else
		return self
	end
end

function Cancelable:andThen(functor)
	assert(Cancelable.isCancelable(self), "'self' must be a Cancelable")

	if self.__completed then
		local cancelable = functor(self.__value)
		assert(Cancelable.isCancelable(cancelable))

		return cancelable
	else
		return self
	end
end

function Cancelable:__tostring()
	if self.__completed then
		return ("Cancelable(completed: %s)"):format(tostring(self.__value))
	else
		return "Cancelable(canceled)"
	end
end

return Cancelable