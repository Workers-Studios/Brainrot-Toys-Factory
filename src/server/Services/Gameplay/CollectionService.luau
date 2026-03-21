--[[
	Manages toy collection and quota progression system
	Tracks when toys reach collection zone and increments quotas toward generator rewards
	
	Main responsibilities:
	- Register toy ownership for tracking
	- Detect toys entering collection zone
	- Increment collection quotas per toy type and rarity
	- Award generators when quotas are reached
	- Notify client UI of quota progress
	
	Quota workflow: Collect toys → reach quota → receive generator in inventory
]]

local CollectionService = {}

local _PlayerDataService = nil
local _GeneratorService = nil
local _ToyConfig = nil
local _quotaRequirements = {}
local _toyOwners = {}
local _lastSaveQuota = {}
local _OnNotification = game:GetService("ReplicatedStorage"):WaitForChild("RemoteInterface"):WaitForChild("Events"):WaitForChild("OnNotification")

-- Initializes service and loads quota requirements
-- @param PlayerDataService: service - Player data management service
-- @param ToyConfig: table - Toy configuration data
-- @param GeneratorService: service - Generator management service
function CollectionService.Init(PlayerDataService, ToyConfig, GeneratorService)
	_PlayerDataService = PlayerDataService
	_GeneratorService = GeneratorService
	_ToyConfig = ToyConfig

	-- Cache quota requirements from ToyConfig
	for toyName, toyData in pairs(ToyConfig) do
		_quotaRequirements[toyName] = toyData.QuotaToGenerator
	end

	-- Connect collection zone trigger
	--local collectionPart = workspace.Collection:FindFirstChild("CollectionZone")
	--collectionPart.Touched:Connect(function(hit)
	--	CollectionService.OnToyCollected(hit)
	--end)

	print("CollectionService initialized")
end

-- Handles toy collection when entering collection zone
-- @param toy: BasePart - The toy that was collected
function CollectionService.OnToyCollected(toy)
	-- Validate toy
	if not toy or not toy:IsA("BasePart") then
		return
	end

	-- Get toy metadata
	local toyType = toy:GetAttribute("ToyType")
	local toyRarity = toy:GetAttribute("ToyRarity")
	local spawnerRarity = toy:GetAttribute("SpawnerRarity")  -- ⭐ NOUVEAU
	local userId = toy:GetAttribute("OwnerId")

	if not toyType or not toyRarity or not spawnerRarity or not userId then
		warn("Invalid toy metadata")
		toy:Destroy()
		return
	end

	-- Get toy configuration
	local toyConfig = _ToyConfig[toyType]
	if not toyConfig then
		warn("Toy config not found for type:", toyType)
		toy:Destroy()
		return
	end

	-- ⭐ DOUBLE RARETÉ: Calculer valeur
	local sellValue = toyConfig.SellValue[toyRarity][spawnerRarity]
	if not sellValue then
		warn("Sell value not found for", toyType, toyRarity, "from spawner", spawnerRarity)
		toy:Destroy()
		return
	end

	-- Give money to player
	local MoneyService = require(script.Parent.Parent.Core.MoneyService)
	MoneyService.AddMoney(userId, sellValue)

	-- Increment quota
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if playerData then
		playerData:IncrementQuota(toyType, toyRarity)
	end

	-- Destroy toy
	toy:Destroy()

	print("✅ Toy collected:", toyType, toyRarity, "from", spawnerRarity, "spawner →", sellValue, "$")
end

-- Increments collection quota for a toy type and rarity
-- @param userId: number - Player's user ID
-- @param toyType: string - Type of toy collected
-- @param rarity: string - Rarity of toy collected
-- @return number - Current quota count after increment
function CollectionService.IncrementQuota(userId, toyType, rarity)
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then
		return 0
	end

	-- Initialize quota structure if first time
	if not playerData.quotaProgress[toyType] then
		playerData.quotaProgress[toyType] = {
			Common = 0,
			Rare = 0,
			Epic = 0,
			Legendary = 0
		}
	end

	-- Increment quota
	playerData.quotaProgress[toyType][rarity] += 1

	-- Batch save (every 5 toys)
	if not _lastSaveQuota[userId] then
		_lastSaveQuota[userId] = 0
	end

	_lastSaveQuota[userId] += 1

	if _lastSaveQuota[userId] >= 5 then
		_PlayerDataService.SavePlayer(userId)
		_lastSaveQuota[userId] = 0
	end

	-- Notify client UI
	local OnQuotaUpdated = game:GetService("ReplicatedStorage").RemoteInterface.Events.OnQuotaUpdated
	local player = game.Players:GetPlayerByUserId(userId)
	local maxQuota = _quotaRequirements[toyType][rarity]

	if player then
		OnQuotaUpdated:FireClient(player, toyType, rarity, playerData.quotaProgress[toyType][rarity], maxQuota)
	end

	return playerData.quotaProgress[toyType][rarity]
end

-- Checks if quota is complete and awards generator
-- @param userId: number - Player's user ID
-- @param toyType: string - Type of toy
-- @param rarity: string - Rarity of toy
-- @return boolean - true if quota was completed, false otherwise
function CollectionService.CheckQuotaComplete(userId, toyType, rarity)
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then
		return false
	end

	local requiredQuota = _quotaRequirements[toyType][rarity]
	local currentQuota = playerData.quotaProgress[toyType][rarity]

	-- Check if quota not yet reached
	if currentQuota < requiredQuota then
		return false
	end

	print("Quota reached!", toyType, rarity, currentQuota, "/", requiredQuota)

	-- Award generator to inventory
	local generatorType = _ToyConfig[toyType].GeneratorType
	_PlayerDataService.AddGenerator(userId, generatorType, rarity)
	print("Generator added to inventory:", generatorType, rarity)

	-- Reset quota
	playerData.quotaProgress[toyType][rarity] = 0

	-- Save immediately to prevent exploit
	_PlayerDataService.SavePlayer(userId)
	print("Data saved after quota completion")

	-- Notify client of quota reset
	local OnQuotaUpdated = game:GetService("ReplicatedStorage").RemoteInterface.Events.OnQuotaUpdated
	local player = game.Players:GetPlayerByUserId(userId)
	if player then
		OnQuotaUpdated:FireClient(player, toyType, rarity, 0, requiredQuota)
	end

	return true
end

-- Registers toy ownership for tracking
-- @param toy: BasePart - The toy object
-- @param userId: number - Owner's user ID
function CollectionService.RegisterToyOwner(toy, userId)
	_toyOwners[toy] = userId
end

return CollectionService