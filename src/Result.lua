local Result = {}

Result.__index = Result

function Result.new(success, value)
	assert(type(success) == "boolean")

	return setmetatable({
		[Result] = true,
		__success = success,
		__value = value,
	}, Result)
end

function Result.ok(value)
	return Result.new(true, value)
end

function Result.error(value)
	return Result.new(false, value)
end

function Result.isResult(value)
	return type(value) == "table" and value[Result]
end

function Result:unpack()
	assert(Result.isResult(self), "'self' must be a Result")

	return self.__success, self.__value
end

function Result:unwrapOrDie(message)
	assert(Result.isResult(self), "'self' must be a Result")
	assert(message == nil or type(message) == "string", "'message' must be nil or a string")

	if not self.__success then
		if message ~= nil then
			error(("Result:unwrapOrDie() failed with %s: %s"):format(tostring(self.__value), message), 2)
		else
			error(("Result:unwrapOrDie() failed with %s"):format(tostring(self.__value)), 2)
		end
	end

	return self.__value
end

function Result:unwrapErrorOrDie(message)
	assert(Result.isResult(self), "'self' must be a Result")
	assert(message == nil or type(message) == "string", "'message' must be nil or a string")

	if self.__success then
		if message ~= nil then
			error(("Result:unwrapErrorOrDie() failed with %s: %s"):format(tostring(self.__value), message), 2)
		else
			error(("Result:unwrapErrorOrDie() failed with %s"):format(tostring(self.__value)), 2)
		end
	end

	return self.__value
end

function Result:isOk()
	return self.__success
end

function Result:isError()
	return not self.__success
end

-- Result<T, E>
-- param functor: T -> U
-- returns Result<U, E>
function Result:map(functor)
	assert(Result.isResult(self), "'self' must be a Result")

	if self.__success then
		return Result.ok(functor(self.__value))
	else
		return self
	end
end

-- Result<T, E>
-- param functor: E -> F
-- returns Result<T, F>
function Result:mapError(functor)
	assert(Result.isResult(self), "'self' must be a Result")

	if self.__success then
		return self
	else
		return Result.error(functor(self.__value))
	end
end

-- Result<T, E>
-- param functor: T -> Result<U, E>
-- returns Result<U, E>
function Result:andThen(functor)
	assert(Result.isResult(self), "'self' must be a Result")

	if self.__success then
		local result = functor(self.__value)
		assert(Result.isResult(result))

		return result
	else
		return self
	end
end

-- Result<T, E>
-- param functor: E -> Result<T, F>
-- returns Result<T, F>
function Result:orElse(functor)
	assert(Result.isResult(self), "'self' must be a Result")

	if self.__success then
		return self
	else
		local result = functor(self.__value)
		assert(Result.isResult(result))

		return result
	end
end

function Result:__tostring()
	if self.__success then
		return ("Result(success: %s)"):format(tostring(self.__value))
	else
		return ("Result(failure: %s)"):format(tostring(self.__value))
	end
end

return Result