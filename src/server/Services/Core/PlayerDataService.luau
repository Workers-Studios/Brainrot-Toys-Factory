--[[
	Manages in-memory PlayerData instances and provides access layer
	Acts as intermediary between services and PlayerData class/DataService

	Main responsibilities:
	- Load player data from DataStore and cache in memory
	- Provide access methods to PlayerData operations
	- Save player data back to DataStore (debounced to avoid throttling)
	- Clean up memory on player disconnect

	Cache structure: {[userId] = PlayerData instance}

	SavePlayer          : debounced (6s delay) — pour les saves fréquentes
	SavePlayerImmediate : bypass le debounce — pour les events critiques (déconnexion, quota complété)
]]

local PlayerDataService = {}

local _playerDataCache = {}
local _DataService     = nil
local _PlayerData      = nil
local _pendingSaves    = {}  -- [userId] = task thread (debounce)

local SAVE_DEBOUNCE = 6  -- seconds (DataStore min interval per key)

-- Initializes service with required dependencies
-- @param DataService: service - Data persistence service
-- @param PlayerData: class - PlayerData OOP class
function PlayerDataService.Init(DataService, PlayerData)
	_DataService = DataService
	_PlayerData  = PlayerData
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

-- Adds an egg (generator) to player's inventory
-- @param userId  : number - Player's user ID
-- @param rarity  : string - Egg rarity (ex: "Common", "Rare")
-- @return boolean - true if successful
function PlayerDataService.AddGenerator(userId, rarity)
	local playerData = PlayerDataService.GetPlayerData(userId)
	if playerData then
		playerData:AddGenerator(rarity)
		return true
	end
	return false
end

-- Removes an egg (generator) from player's inventory
-- @param userId  : number - Player's user ID
-- @param rarity  : string - Egg rarity (ex: "Common", "Rare")
-- @return boolean - true if removed, false if unavailable
function PlayerDataService.RemoveGenerator(userId, rarity)
	local playerData = PlayerDataService.GetPlayerData(userId)
	if playerData then
		return playerData:RemoveGenerator(rarity)
	end
	return false
end

-- Ajoute un brainrot récupéré dans l'inventaire persistant
function PlayerDataService.AddBrainrot(userId, name, modelName, rarity, revenuePerSecond)
	local playerData = PlayerDataService.GetPlayerData(userId)
	if playerData then
		playerData:AddBrainrot(name, modelName, rarity, revenuePerSecond)
		return true
	end
	return false
end

-- Retire un brainrot de l'inventaire persistant
function PlayerDataService.RemoveBrainrot(userId, name)
	local playerData = PlayerDataService.GetPlayerData(userId)
	if playerData then
		return playerData:RemoveBrainrot(name)
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
-- Stocke le thread dans _pendingSaves pour pouvoir l'annuler proprement
-- @param userId: number - Player's user ID
function PlayerDataService.SavePlayer(userId)
	if _pendingSaves[userId] then return end  -- déjà une save planifiée

	_pendingSaves[userId] = task.delay(SAVE_DEBOUNCE, function()
		_pendingSaves[userId] = nil
		local playerData = _playerDataCache[userId]
		if playerData then
			_DataService.SavePlayerData(userId, playerData:Serialize())
		end
	end)
end

-- Saves player data immediately, en annulant toute save déboncée en attente
-- Pour les events critiques : déconnexion
-- @param userId: number - Player's user ID
-- @return boolean - true if saved successfully
function PlayerDataService.SavePlayerImmediate(userId)
	-- Annuler la save déboncée en attente (maintenant possible car on stocke le thread)
	if _pendingSaves[userId] then
		task.cancel(_pendingSaves[userId])
		_pendingSaves[userId] = nil
	end

	local playerData = _playerDataCache[userId]
	if not playerData then
		return false
	end

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
