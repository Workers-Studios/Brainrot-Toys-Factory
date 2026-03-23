--[[
	Manages in-memory PlayerData instances and provides access layer
	Acts as intermediary between services and PlayerData class/DataService
	
	Main responsibilities:
	- Load player data from DataStore and cache in memory
	- Provide access methods to PlayerData operations
	- Save player data back to DataStore
	- Clean up memory on player disconnect
	
	Cache structure: {[userId] = PlayerData instance}
]]

local PlayerDataService = {}

local _playerDataCache = {}
local _DataService = nil
local _PlayerData = nil
local _pendingSaves = {}  -- [userId] = task thread (debounce)

local SAVE_DEBOUNCE = 6  -- seconds (DataStore min interval per key)

-- Initializes service with required dependencies
-- @param DataService: service - Data persistence service
-- @param PlayerData: class - PlayerData OOP class
function PlayerDataService.Init(DataService, PlayerData)
	_DataService = DataService
	_PlayerData = PlayerData
end

-- Loads player data from DataStore and caches in memory
-- @param userId: number - Player's user ID
-- @return PlayerData - Cached PlayerData instance
function PlayerDataService.LoadPlayer(userId)
	local loadedData = _DataService.LoadPlayerData(userId)
	local playerData

	if loadedData then
		playerData = _PlayerData.load(userId, loadedData)
	else
		playerData = _PlayerData.new(userId)
	end

	_playerDataCache[userId] = playerData

	return playerData
end

-- Adds a generator to player's inventory
-- @param userId: number - Player's user ID
-- @param generatorType: string - Generator type (ex: "Common_Generator")
-- @return boolean - true if successful, false if PlayerData not found
function PlayerDataService.AddGenerator(userId, generatorType)
	local playerData = PlayerDataService.GetPlayerData(userId)
	if playerData then
		playerData:AddGenerator(generatorType)
		return true
	end
	return false
end

-- Removes a generator from player's inventory
-- @param userId: number - Player's user ID
-- @param generatorType: string - Generator type (ex: "Common_Generator")
-- @return boolean - true if removed, false if unavailable or PlayerData not found
function PlayerDataService.RemoveGenerator(userId, generatorType)
	local playerData = PlayerDataService.GetPlayerData(userId)
	if playerData then
		return playerData:RemoveGenerator(generatorType)
	end
	return false
end

-- Returns player's generator inventory
-- @param userId: number - Player's user ID
-- @return table|nil - Generator inventory or nil if PlayerData not found
function PlayerDataService.GetGeneratorInventory(userId)
	local playerData = PlayerDataService.GetPlayerData(userId)
	if playerData then
		return playerData.generatorInventory
	end
	return nil
end

-- Saves player data to DataStore (debounced - max 1 save per SAVE_DEBOUNCE seconds)
-- @param userId: number - Player's user ID
-- @return boolean - true if scheduled, false if PlayerData not found
function PlayerDataService.SavePlayer(userId)
	if not _playerDataCache[userId] then
		return false
	end

	-- Cancel existing pending save and reschedule
	if _pendingSaves[userId] then
		task.cancel(_pendingSaves[userId])
		_pendingSaves[userId] = nil
	end

	_pendingSaves[userId] = task.delay(SAVE_DEBOUNCE, function()
		_pendingSaves[userId] = nil
		local playerData = _playerDataCache[userId]
		if playerData then
			_DataService.SavePlayerData(userId, playerData:Serialize())
		end
	end)

	return true
end

-- Saves player data immediately (used on disconnect / critical events)
-- Cancels any pending debounced save first
-- @param userId: number - Player's user ID
-- @return boolean - true if saved, false if PlayerData not found
function PlayerDataService.SavePlayerImmediate(userId)
	-- Cancel debounced save if pending
	if _pendingSaves[userId] then
		task.cancel(_pendingSaves[userId])
		_pendingSaves[userId] = nil
	end

	if not _playerDataCache[userId] then
		return false
	end

	local playerData = _playerDataCache[userId]
	return _DataService.SavePlayerData(userId, playerData:Serialize())
end

-- Returns cached PlayerData instance
-- @param userId: number - Player's user ID
-- @return PlayerData|nil - Cached instance or nil if not found
function PlayerDataService.GetPlayerData(userId)
	return _playerDataCache[userId]
end

-- Removes player from memory cache
-- @param userId: number - Player's user ID
function PlayerDataService.RemovePlayer(userId)
	_playerDataCache[userId] = nil
end

return PlayerDataService