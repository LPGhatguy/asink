local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Asink = require(ReplicatedStorage.Asink)

-- You might write a cancelable HTTP get function like this using Asink.
local function httpGet(url)
	local future, resolve = Asink.Future.new()

	-- exec creates a coroutine with your code in it, and hands it to the engine
	-- Errors go to normal output and leave this thread alone
	Asink.Runtime.exec(function()
		-- Exceptions are considered fatal, so we'll wrap this call and
		-- communicate failure with a Result instead.
		local success, response = pcall(function()
			return HttpService:GetAsync(url)
		end)

		if success then
			-- this is a mouthful
			resolve(Asink.Result.ok(Asink.Cancelable.completed(response)))
		else
			resolve(Asink.Result.error(response))
		end
	end)

	local function cancel()
		resolve(Asink.Cancelable.canceled())
	end

	return future, cancel
end

local example, cancelExample = httpGet("https://example.com")

-- All of the types involved implement __tostring for easy diagnostics.
print("future at start:", example)

-- we can do monad things to the result like Haskell but without do-notation:
example:map(function(result)
	-- The request might've failed, so we map on the result...
	return result:map(function(cancelable)
		-- The request might've been canceled, so we map on the cancelable...
		return cancelable:map(function(responseBody)
			print("Response:", responseBody)
		end)
	end)
end)

-- we can also unwrap each bit carefully, kinda like Go:
example
	:map(function(result)
		local success, cancelable = result:unpack()

		if not success then
			return nil
		end

		local success, responseBody = cancelable:unpack()

		if not success then
			return nil
		end

		-- yay, a successful response.
		return responseBody
	end)
	:map(function(responseBody)
		if responseBody ~= nil then
			print("Response was", #responseBody, "bytes long")
		else
			print("something happened")
		end
	end)

-- we can also await+unwrap everything and die on error, like bad Rust code.
local responseBody = example:await():unwrapOrDie():unwrapOrDie()