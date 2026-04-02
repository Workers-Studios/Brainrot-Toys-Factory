--[[
	Handles client-server communication via RemoteFunctions
	Connects RemoteFunctions to appropriate service methods with validation
	
	Main RemoteFunctions:
	- PurchaseSpawner: Handles spawner purchases from shop
	- PlaceSpawner: Reserved for future manual placement UI
	- RequestPlayerData: Reserved for future client UI data requests
	
	All functions validate player identity and delegate to services
]]

local RemoteFunctionHandler = {}

local AntiExploitService = require(game.ServerScriptService.Services.Core.AntiExploitService)

local _ShopService = nil
local _PlacementService = nil
local _PlayerDataService = nil

-- Get RemoteFunctions from ReplicatedStorage
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteInterface = ReplicatedStorage:WaitForChild("RemoteInterface")
local Functions = RemoteInterface:WaitForChild("Functions")

local PurchaseSpawner = Functions:WaitForChild("PurchaseSpawner")
local PlaceSpawner = Functions:WaitForChild("PlaceSpawner")
local RequestPlayerData = Functions:WaitForChild("RequestPlayerData")

-- Initializes handler and connects RemoteFunctions to services
-- @param ShopService: service - Shop and transaction service
-- @param PlacementService: service - Spawner placement service
-- @param PlayerDataService: service - Player data management service
function RemoteFunctionHandler.Init(ShopService, PlacementService, PlayerDataService)
	_ShopService = ShopService
	_PlacementService = PlacementService
	_PlayerDataService = PlayerDataService

	-- Connect PurchaseSpawner RemoteFunction
	-- Allows client to purchase spawners from shop
	PurchaseSpawner.OnServerInvoke = function(player, rarity)
		if not AntiExploitService.ValidateRarity(rarity) then
			AntiExploitService.LogSuspiciousActivity(player.UserId, "PurchaseSpawner", "Invalid rarity: " .. tostring(rarity))
			return false, "Invalid input"
		end

		local userId = player.UserId
		local success, message = _ShopService.PurchaseSpawner(userId, rarity)
		return success, message
	end

	-- Connect PlaceSpawner RemoteFunction (reserved for future use)
	-- Will allow manual placement via UI instead of ProximityPrompts
	PlaceSpawner.OnServerInvoke = function(player, rarity, slotName)
		if not AntiExploitService.CheckRateLimit(player.UserId, "PlaceSpawner") then
			return false, "Too many requests"
		end

		if not AntiExploitService.ValidateString(slotName, 30) then
			AntiExploitService.LogSuspiciousActivity(player.UserId, "PlaceSpawner", "Invalid slot: " .. tostring(slotName))
			return false, "Invalid slot"
		end

		if not AntiExploitService.ValidateRarity(rarity) then
			AntiExploitService.LogSuspiciousActivity(player.UserId, "PlaceSpawner", "Invalid rarity: " .. tostring(rarity))
			return false, "Invalid spawner type"
		end

		return false, "Not yet implemented"
	end

	-- Renvoie les données nécessaires au GUI Index/Inventaire
	RequestPlayerData.OnServerInvoke = function(player)
		local playerData = _PlayerDataService.GetPlayerData(player.UserId)
		if not playerData then return nil end
		return {
			discoveredBrainrots = playerData.discoveredBrainrots,
			brainrotInventory   = playerData.brainrotInventory,
		}
	end

	print("RemoteFunctionHandler initialized")
end

return RemoteFunctionHandler