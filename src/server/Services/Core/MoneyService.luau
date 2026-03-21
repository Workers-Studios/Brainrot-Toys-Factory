--[[
	Manages player money operations and notifies clients of changes
	Acts as intermediary between services and PlayerData for economy operations
	
	Main responsibilities:
	- Add/deduct money with validation
	- Check if player has sufficient funds
	- Notify client UI of money changes via RemoteEvent
	
	All operations validate PlayerData existence before execution
]]

local MoneyService = {}

local AntiExploitService = require(game.ServerScriptService.Services.Core.AntiExploitService)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnMoneyChanged = ReplicatedStorage:WaitForChild("RemoteInterface"):WaitForChild("Events"):WaitForChild("OnMoneyChanged")

local _PlayerDataService = nil
local _OnMoneyChanged = nil

-- Initializes service and caches RemoteEvent reference
-- @param PlayerDataService: service - Player data management service
function MoneyService.Init(PlayerDataService)
	_PlayerDataService = PlayerDataService
	_OnMoneyChanged = OnMoneyChanged
end

-- Adds money to player and notifies client
-- @param userId: number - Player's user ID
-- @param amount: number - Amount to add
-- @return boolean - true if successful, false if PlayerData not found
function MoneyService.AddMoney(userId, amount)
	if not AntiExploitService.ValidateAmount(amount, 0, 1000000) then
		warn("Invalid amount: " .. tostring(amount) .. " for userId: " .. tostring(userId) .. "")
		return
	end
	
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then
		return
	end

	playerData:AddMoney(amount)

	-- Notify client of money change
	local player = game.Players:GetPlayerByUserId(userId)
	if player then
		_OnMoneyChanged:FireClient(player, playerData.money)
	end
end

-- Checks if player has enough money for a transaction
-- @param userId: number - Player's user ID
-- @param amount: number - Amount to check
-- @return boolean - true if player has sufficient funds
function MoneyService.HasEnoughMoney(userId, amount)
	local playerData = _PlayerDataService.GetPlayerData(userId)

	if playerData:GetMoney() >= amount then
		return true
	else
		return false
	end
end

-- Deducts money from player if sufficient funds available
-- @param userId: number - Player's user ID
-- @param amount: number - Amount to deduct
-- @return boolean - true if deducted, false if insufficient funds or PlayerData not found
function MoneyService.DeductMoney(userId, amount)
	if not AntiExploitService.ValidateAmount(amount, 0, 1000000) then
		return false
	end
	
	local playerData = _PlayerDataService.GetPlayerData(userId)

	if MoneyService.HasEnoughMoney(userId, amount) then
		playerData:DeductMoney(amount)
		_OnMoneyChanged:FireClient(game.Players:GetPlayerByUserId(userId), playerData.money)
		return true
	else
		return false
	end
end

-- Returns player's current money
-- @param userId: number - Player's user ID
-- @return number|nil - Current money amount or nil if PlayerData not found
function MoneyService.GetMoney(userId)
	local playerData = _PlayerDataService.GetPlayerData(userId)

	if playerData then
		return playerData:GetMoney()
	end
end

return MoneyService