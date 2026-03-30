--[[
	Gestion des transactions du shop et des achats de spawners
	Valide les achats et traite les transactions de manière serveur-autoritaire

	Découplage via Signal :
	  Après un achat réussi, émet "SpawnerPurchased" au lieu d'appeler
	  PlacementService.GiveSpawnerTool directement.
	  PlacementService s'abonne dans son Init().
]]

local ShopService = {}

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local AntiExploitService = require(game.ServerScriptService.Services.Core.AntiExploitService)
local Signal             = require(game.ServerScriptService.Framework.Signal)
local Network            = require(ReplicatedStorage.Shared.Network)

local _SpawnerConfig     = nil
local _MoneyService      = nil
local _PlayerDataService = nil
local _OnNotification    = nil

-- Initialise le service
function ShopService.Init(SpawnerConfig, MoneyService, PlayerDataService)
	_SpawnerConfig     = SpawnerConfig
	_MoneyService      = MoneyService
	_PlayerDataService = PlayerDataService

	_OnNotification = ReplicatedStorage
		:WaitForChild("RemoteInterface")
		:WaitForChild("Events")
		:WaitForChild(Network.Events.OnNotification)
end

-- Traite un achat de spawner avec validation complète
-- @param userId : number - ID du joueur
-- @param rarity : string - Rareté du spawner à acheter
-- @return boolean, string - succès + message
function ShopService.PurchaseSpawner(userId, rarity)
	if not AntiExploitService.CheckRateLimit(userId, "PurchaseSpawner") then
		return false, "Trop de requêtes, attends un peu"
	end

	if not AntiExploitService.ValidateRarity(rarity) then
		AntiExploitService.LogSuspiciousActivity(userId, "PurchaseSpawner", "Rareté invalide : " .. tostring(rarity))
		return false, "Rareté invalide"
	end

	if not _SpawnerConfig[rarity] then
		return false, "Type de spawner invalide"
	end

	local price       = _SpawnerConfig[rarity].BasePrice
	local playerData  = _PlayerDataService.GetPlayerData(userId)
	local rebirthLevel = playerData.rebirthLevel

	if rebirthLevel < _SpawnerConfig[rarity].RequiredRebirth then
		local player = game.Players:GetPlayerByUserId(userId)
		if player and _OnNotification then
			_OnNotification:FireClient(player, "Rebirth requis pour débloquer ce spawner !", "ERROR")
		end
		return false, "Rebirth requis !"
	end

	if not _MoneyService.HasEnoughMoney(userId, price) then
		local player = game.Players:GetPlayerByUserId(userId)
		if player and _OnNotification then
			_OnNotification:FireClient(player, "Pas assez d'argent !", "ERROR")
		end
		return false, "Pas assez d'argent !"
	end

	-- Transaction
	_MoneyService.DeductMoney(userId, price)
	playerData:AddToInventory(rarity)

	-- Découplé : PlacementService écoute "SpawnerPurchased" dans son Init()
	local player = game.Players:GetPlayerByUserId(userId)
	if player then
		Signal.Fire("SpawnerPurchased", player, rarity)
		if _OnNotification then
			_OnNotification:FireClient(player, rarity .. " spawner acheté !", "SUCCESS")
		end
	end

	return true, "Achat réussi"
end

-- Retourne le prix d'une rareté de spawner
function ShopService.GetSpawnerPrice(rarity)
	if _SpawnerConfig[rarity] then
		return _SpawnerConfig[rarity].BasePrice
	end
	return nil
end

return ShopService
