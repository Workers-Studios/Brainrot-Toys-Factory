--[[
	Data persistence layer using Roblox DataStoreService
	Handles saving and loading player data with retry logic
	
	Main responsibilities:
	- Initialize DataStore connection
	- Save player data with automatic retry on failure
	- Load player data with automatic retry on failure
	- Handle DataStore API errors gracefully
	
	Retry strategy: 3 attempts with exponential backoff (1s, 2s, 4s)
	Key format: "Player_{userId}"
]]

local DataService = {}

local DataStoreService = game:GetService("DataStoreService")

local _dataStore = nil
local _maxRetries = 3
local _retryDelays = {1, 2, 4}  -- Exponential backoff in seconds

-- Initializes DataStore connection
function DataService.Init()
	_dataStore = DataStoreService:GetDataStore("PlayerData")
	print("DataService initialized")
end

-- Saves player data to DataStore with retry logic
-- @param userId: number - Player's user ID
-- @param dataTable: table - Serialized player data
-- @return boolean - true if saved successfully, false after all retries failed
function DataService.SavePlayerData(userId, dataTable)
	local key = "Player_" .. userId

	for attempt = 1, _maxRetries do
		local success, error = pcall(function()
			_dataStore:SetAsync(key, dataTable)
		end)

		if success and userId then
			print("Save successful for", userId)
			return true
		else
			warn("Save error for", userId, "attempt", attempt, ":", error)

			-- Wait before retrying (exponential backoff)
			if attempt < _maxRetries then
				task.wait(_retryDelays[attempt])
			end
		end
	end

	warn("All retries failed for", userId)
	return false
end

-- Loads player data from DataStore with retry logic
-- @param userId: number - Player's user ID
-- @return table|nil - Player data or nil if not found/error
function DataService.LoadPlayerData(userId)
	local key = "Player_" .. userId

	for attempt = 1, _maxRetries do
		local success, result = pcall(function()
			return _dataStore:GetAsync(key)
		end)

		if success and userId then
			print("Load successful for", userId)
			return result
		else
			warn("Load error for", userId, "attempt", attempt, ":", result)

			-- Wait before retrying (exponential backoff)
			if attempt < _maxRetries then
				task.wait(_retryDelays[attempt])
			end
		end
	end

	return nil
end

return DataService