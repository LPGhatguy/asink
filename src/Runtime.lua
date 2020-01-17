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

function Runtime.exec(functor)
	local bindable = Instance.new("BindableEvent")
	bindable.Event:Connect(functor)
	bindable:Fire()
	bindable:Destroy()
end

function Runtime.__start(task)
	trackedTasks[task] = true

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
					return
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

	if coroutine.status(co) == "suspended" then
		Runtime.__start(task)
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