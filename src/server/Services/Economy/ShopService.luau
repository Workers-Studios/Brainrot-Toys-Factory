--[[
	Manages shop transactions and spawner purchases
	Validates purchase requirements and handles money transactions
	
	Main responsibilities:
	- Validate spawner purchase requests (rebirth level, funds)
	- Process transactions via MoneyService
	- Add purchased items to player inventory
	- Notify client of transaction results
	
	All transactions are server-authoritative and validated
]]

local ShopService = {}

local AntiExploitService = require(game.ServerScriptService.Services.Core.AntiExploitService)

local _SpawnerConfig = nil
local _MoneyService = nil
local _PlayerDataService = nil
local _OnNotification = game:GetService("ReplicatedStorage"):WaitForChild("RemoteInterface"):WaitForChild("Events"):WaitForChild("OnNotification")

-- Initializes service with required dependencies
-- @param SpawnerConfig: table - Spawner configuration data
-- @param MoneyService: service - Money transaction service
-- @param PlayerDataService: service - Player data management service
function ShopService.Init(SpawnerConfig, MoneyService, PlayerDataService)
	_SpawnerConfig = SpawnerConfig
	_MoneyService = MoneyService
	_PlayerDataService = PlayerDataService
end

-- Processes spawner purchase with validation
-- @param userId: number - Player's user ID
-- @param rarity: string - Spawner rarity to purchase
-- @return boolean, string - Success status and message
function ShopService.PurchaseSpawner(userId, rarity)
	if not AntiExploitService.CheckRateLimit(userId, "PurchaseSpawner") then
		return false, "Too many requests, please wait"
	end

	if not AntiExploitService.ValidateRarity(rarity) then
		AntiExploitService.LogSuspiciousActivity(userId, "PurchaseSpawner", "Invalid rarity: " .. tostring(rarity))
		return false, "Invalid rarity"
	end
	
	-- Validate spawner type exists
	if _SpawnerConfig[rarity] == nil then
		return false, "Invalid spawner type"
	end

	local price = _SpawnerConfig[rarity].BasePrice
	local playerData = _PlayerDataService.GetPlayerData(userId)
	local rebirthLevel = playerData.rebirthLevel

	-- Check rebirth level requirement
	if rebirthLevel < _SpawnerConfig[rarity].RequiredRebirth then
		if _OnNotification then
			_OnNotification:FireClient(game.Players:GetPlayerByUserId(userId), "You need to rebirth to unlock this spawner!", "ERROR")
		end
		return false, "You need to rebirth to unlock this spawner!"
	end

	-- Check sufficient funds
	if not _MoneyService.HasEnoughMoney(userId, price) then
		if _OnNotification then
			_OnNotification:FireClient(game.Players:GetPlayerByUserId(userId), "You don't have enough money!", "ERROR")
		end
		return false, "You don't have enough money!"
	end

	-- Process transaction
	_MoneyService.DeductMoney(userId, price)
	playerData:AddToInventory(rarity)

	-- Notify success
	if _OnNotification then
		_OnNotification:FireClient(game.Players:GetPlayerByUserId(userId), "You have successfully purchased " .. rarity .. " spawner!", "SUCCESS")
	end

	return true, "Purchase successful"
end

-- Returns price for a spawner rarity
-- @param rarity: string - Spawner rarity
-- @return number|nil - Price or nil if rarity doesn't exist
function ShopService.GetSpawnerPrice(rarity)
	if _SpawnerConfig[rarity] then
		return _SpawnerConfig[rarity].BasePrice
	else
		return nil
	end
end

return ShopService