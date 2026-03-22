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
-- @param generatorType: string - Generator type
-- @param rarity: string - Generator rarity
-- @return boolean - true if successful, false if PlayerData not found
function PlayerDataService.AddGenerator(userId, generatorType, rarity)
	local playerData = PlayerDataService.GetPlayerData(userId)
	if playerData then
		playerData:AddGenerator(generatorType, rarity)
		return true
	end
	return false
end

-- Removes a generator from player's inventory
-- @param userId: number - Player's user ID
-- @param generatorType: string - Generator type
-- @param rarity: string - Generator rarity
-- @return boolean - true if removed, false if unavailable or PlayerData not found
function PlayerDataService.RemoveGenerator(userId, generatorType, rarity)
	local playerData = PlayerDataService.GetPlayerData(userId)
	if playerData then
		return playerData:RemoveGenerator(generatorType, rarity)
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

-- Saves player data to DataStore
-- @param userId: number - Player's user ID
-- @return boolean - true if saved successfully, false if PlayerData not found
function PlayerDataService.SavePlayer(userId)
	if not _playerDataCache[userId] then
		-- Joueur jamais chargé (kick prématuré, etc.), pas une vraie erreur
		return false
	end

	local playerData = _playerDataCache[userId]
	local serializedData = playerData:Serialize()

	return _DataService.SavePlayerData(userId, serializedData)
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