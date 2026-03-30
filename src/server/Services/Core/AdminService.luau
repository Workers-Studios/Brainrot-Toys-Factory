--[[
	Système de commandes admin avec support UI
	Seuls les utilisateurs autorisés peuvent exécuter des commandes via RemoteEvents sécurisés

	Commandes :
	- GiveMoney   : ajouter de l'argent à un joueur
	- SetMoney    : définir l'argent d'un joueur à une valeur exacte
	- GiveSpawner : donner un spawner à un joueur
]]

local AdminService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Network)
local Enums   = require(ReplicatedStorage.Shared.Enums)

local _PlayerDataService = nil
local _MoneyService      = nil

-- IDs admin autorisés
local ADMIN_USER_IDS = {
	10244275965, -- DorianABDS
}

local function isAdmin(userId)
	for _, adminId in ipairs(ADMIN_USER_IDS) do
		if userId == adminId then return true end
	end
	return false
end

-- Initialise le service et connecte les remotes
function AdminService.Init(PlayerDataService, MoneyService)
	_PlayerDataService = PlayerDataService
	_MoneyService      = MoneyService

	local adminFolder = ReplicatedStorage.RemoteInterface:WaitForChild("Admin")

	local isAdminRemote = adminFolder:WaitForChild(Network.Admin.IsAdmin)
	isAdminRemote.OnServerInvoke = function(player)
		return isAdmin(player.UserId)
	end

	local executeCommandRemote = adminFolder:WaitForChild(Network.Admin.ExecuteCommand)
	executeCommandRemote.OnServerEvent:Connect(function(player, commandType, targetName, value)
		AdminService.ExecuteCommand(player, commandType, targetName, value)
	end)

	print("AdminService initialized")
end

-- Exécute une commande admin
-- @param admin       : Player - Admin exécutant la commande
-- @param commandType : string - Type (GiveMoney, SetMoney, GiveSpawner)
-- @param targetName  : string - Nom du joueur cible
-- @param value       : any    - Valeur de la commande (montant ou rareté)
function AdminService.ExecuteCommand(admin, commandType, targetName, value)
	if not isAdmin(admin.UserId) then
		warn("Tentative de commande non autorisée depuis", admin.Name)
		return
	end

	local target = game.Players:FindFirstChild(targetName)
	if not target then
		warn("Admin: joueur introuvable :", targetName)
		return
	end

	if commandType == "GiveMoney" then
		local amount = tonumber(value)
		if not amount or amount <= 0 then
			warn("Admin: montant invalide")
			return
		end
		_MoneyService.AddMoney(target.UserId, amount)
		print(string.format("✅ Admin %s a donné %d$ à %s", admin.Name, amount, targetName))

	elseif commandType == "SetMoney" then
		local amount = tonumber(value)
		if not amount or amount < 0 then
			warn("Admin: montant invalide")
			return
		end
		local playerData = _PlayerDataService.GetPlayerData(target.UserId)
		if playerData then
			playerData.money = amount
			local onMoneyChanged = ReplicatedStorage.RemoteInterface.Events
				:FindFirstChild(Network.Events.OnMoneyChanged)
			if onMoneyChanged then
				onMoneyChanged:FireClient(target, amount)
			end
			_PlayerDataService.SavePlayer(target.UserId)
			print(string.format("✅ Admin %s a fixé l'argent de %s à %d$", admin.Name, targetName, amount))
		end

	elseif commandType == "GiveSpawner" then
		local rarity = value
		-- Enums.RaritySet valide toutes les raretés connues (y compris Uncommon)
		if not Enums.RaritySet[rarity] then
			warn("Admin: rareté invalide :", rarity)
			return
		end
		local playerData = _PlayerDataService.GetPlayerData(target.UserId)
		if playerData then
			playerData:AddToInventory(rarity)
			_PlayerDataService.SavePlayer(target.UserId)
			print(string.format("✅ Admin %s a donné un spawner %s à %s", admin.Name, rarity, targetName))
		end
	end
end

return AdminService
