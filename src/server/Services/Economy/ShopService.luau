--[[
	Manages shop transactions and spawner purchases
	Validates purchase requirements and handles money transactions

	Main responsibilities:
	- Validate spawner purchase requests (prestige level, funds)
	- Process transactions via MoneyService
	- Add purchased items to player inventory
	- Notify client of transaction results

	All transactions are server-authoritative and validated
]]

local ShopService = {}

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local AntiExploitService = require(game.ServerScriptService.Services.Core.AntiExploitService)
local PlacementService   = require(game.ServerScriptService.Services.Gameplay.PlacementService)
local LevelService       = require(script.Parent.Parent.Progression.LevelService)
local LevelConfig        = require(ReplicatedStorage.Shared.LevelConfig)

local _SpawnerConfig      = nil
local _MoneyService       = nil
local _PlayerDataService  = nil
local _OnNotification     = game:GetService("ReplicatedStorage")
	:WaitForChild("RemoteInterface")
	:WaitForChild("Events")
	:WaitForChild("OnNotification")

-- Initializes service with required dependencies
function ShopService.Init(SpawnerConfig, MoneyService, PlayerDataService)
	_SpawnerConfig     = SpawnerConfig
	_MoneyService      = MoneyService
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

	if _SpawnerConfig[rarity] == nil then
		return false, "Invalid spawner type"
	end

	local price      = _SpawnerConfig[rarity].BasePrice
	local playerData = _PlayerDataService.GetPlayerData(userId)
	local player     = game.Players:GetPlayerByUserId(userId)

	-- ─── Vérifier le niveau de Prestige requis ───────────────────────────────
	local requiredPrestige = _SpawnerConfig[rarity].RequiredPrestige or 0
	if playerData.prestigeLevel < requiredPrestige then
		if _OnNotification and player then
			_OnNotification:FireClient(
				player,
				string.format("Prestige %d requis pour débloquer ce spawner !", requiredPrestige),
				"ERROR"
			)
		end
		return false, string.format("Prestige %d required", requiredPrestige)
	end

	-- ─── Vérifier les fonds ──────────────────────────────────────────────────
	if not _MoneyService.HasEnoughMoney(userId, price) then
		if _OnNotification and player then
			_OnNotification:FireClient(player, "Tu n'as pas assez d'argent !", "ERROR")
		end
		return false, "You don't have enough money!"
	end

	-- ─── Traiter la transaction ──────────────────────────────────────────────
	_MoneyService.DeductMoney(userId, price)
	playerData:AddToInventory(rarity)

	-- Récompense EXP pour l'achat
	LevelService.AddExp(userId, LevelConfig.ExpRewards.SpawnerPurchased[rarity] or 0)

	-- Donner le tool au joueur
	if player then
		PlacementService.GiveSpawnerTool(player, rarity)
	end

	if _OnNotification and player then
		_OnNotification:FireClient(player, rarity .. " spawner acheté !", "SUCCESS")
	end

	return true, "Purchase successful"
end

-- Returns price for a spawner rarity
function ShopService.GetSpawnerPrice(rarity)
	if _SpawnerConfig[rarity] then
		return _SpawnerConfig[rarity].BasePrice
	end
	return nil
end

return ShopService
