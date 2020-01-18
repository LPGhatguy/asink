local RunService = game:GetService("RunService")

local pollConnection = nil
local rejectionHandlers = {}
local trackedTasks = {}

local Runtime = {}

function Runtime.addFutureRejectionHandler(handler)
	assert(type(handler) == "function", "Future rejection handler must be a function")

	local newHandlers = {
		[handler] = true
	}

	for existing in pairs(rejectionHandlers) do
		newHandlers[existing] = true
	end

	rejectionHandlers = newHandlers

	return function()
		local newHandlers = {}

		for existing in pairs(rejectionHandlers) do
			if existing ~= handler then
				newHandlers[existing] = true
			end
		end

		rejectionHandlers = newHandlers
	end
end

-- Alternative to `spawn` or `coroutine.wrap` that runs immediately, but
-- propagates errors to the engine instead of swallowing them or killing the
-- containing thread.
function Runtime.exec(functor)
	local bindable = Instance.new("BindableEvent")
	bindable.Event:Connect(functor)
	bindable:Fire()
	bindable:Destroy()
end

-- Start the Asink runtime if it isn't already running.
--
-- The runtime will monitor outstanding tasks that yielded at some point and
-- watch them for errors. It isn't strictly necessary for the happy path, but is
-- necessary to let Lua code know about fatal errors in Futures.
function Runtime.__start()
	if pollConnection ~= nil then
		return
	end

	pollConnection = RunService.Stepped:Connect(function()
		if next(trackedTasks) == nil and pollConnection ~= nil then
			pollConnection:Disconnect()
			pollConnection = nil
			return
		end

		local nextTaskSet = {}

		for task in pairs(trackedTasks) do
			local status = coroutine.status(task.co)

			if status == "dead" then
				if task.completed then
					-- This task completed without a hitch.
				else
					-- This task died a gruesome death.
					-- Someone else will have received an error.
					local message = debug.traceback(task.co)
					Runtime.__fireFutureRejection(message)
				end
			else
				-- This task is still outstanding, carry it over.
				nextTaskSet[task] = true
			end
		end

		trackedTasks = nextTaskSet
	end)
end

function Runtime.__runFutureListener(listener, value)
	local task = {
		completed = false,
		co = nil,
	}

	task.co = coroutine.create(function(...)
		listener(...)
		task.completed = true
	end)
	local success, result = coroutine.resume(task.co, value)

	if not success then
		local message = debug.traceback(task.co, tostring(result))
		Runtime.__fireFutureRejection(message)
		return
	end

	-- If the listener yielded, we'll track the task to monitor it for errors.
	if coroutine.status(task.co) == "suspended" then
		trackedTasks[task] = true
		Runtime.__start()
	end
end

function Runtime.__fireFutureRejection(errorMessage)
	local handlers = rejectionHandlers

	local bindable = Instance.new("BindableEvent")

	if next(handlers) ~= nil then
		for handler in pairs(handlers) do
			local connection = bindable.Event:Connect(handler)
			bindable:Fire()
			connection:Disconnect()
		end
	else
		bindable.Event:Connect(function()
			error(string.format("Future error: %s", errorMessage), 0)
		end)
		bindable:Fire()
	end

	bindable:Destroy()
end

return Runtime