--[[
	Admin commands system with UI support
	Only authorized users can execute admin commands via secure RemoteEvents
	
	Commands:
	- GiveMoney: Add money to player
	- SetMoney: Set player money to exact amount
	- GiveSpawner: Give spawner to player inventory
]]

local AdminService = {}

local _PlayerDataService = nil
local _MoneyService = nil

-- Users Admin ID
local ADMIN_USER_IDS = {
	10244275965, -- DorianABDS 
}

-- Checks if player is admin
-- @param userId: number - Player's user ID
-- @return boolean - true if admin
local function isAdmin(userId)
	for _, adminId in ipairs(ADMIN_USER_IDS) do
		if userId == adminId then
			return true
		end
	end
	return false
end

-- Initializes admin service and creates RemoteEvents
-- @param PlayerDataService: service
-- @param MoneyService: service
function AdminService.Init(PlayerDataService, MoneyService)
	_PlayerDataService = PlayerDataService
	_MoneyService = MoneyService

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remoteInterface = ReplicatedStorage:WaitForChild("RemoteInterface")

	-- Create Admin folder in RemoteInterface
	local adminFolder = Instance.new("Folder")
	adminFolder.Name = "Admin"
	adminFolder.Parent = remoteInterface

	-- Create RemoteFunction to check if player is admin
	local isAdminRemote = Instance.new("RemoteFunction")
	isAdminRemote.Name = "IsAdmin"
	isAdminRemote.Parent = adminFolder

	isAdminRemote.OnServerInvoke = function(player)
		return isAdmin(player.UserId)
	end

	-- Create RemoteEvent for admin commands
	local executeCommandRemote = Instance.new("RemoteEvent")
	executeCommandRemote.Name = "ExecuteCommand"
	executeCommandRemote.Parent = adminFolder

	executeCommandRemote.OnServerEvent:Connect(function(player, commandType, targetName, value)
		AdminService.ExecuteCommand(player, commandType, targetName, value)
	end)

	print("AdminService initialized")
end

-- Executes admin command from UI
-- @param admin: Player - Admin who sent command
-- @param commandType: string - Command type (GiveMoney, SetMoney, GiveSpawner)
-- @param targetName: string - Target player name
-- @param value: any - Command value (amount or rarity)
function AdminService.ExecuteCommand(admin, commandType, targetName, value)
	-- Verify admin
	if not isAdmin(admin.UserId) then
		warn("Unauthorized command attempt from", admin.Name)
		return
	end

	-- Find target player
	local target = game.Players:FindFirstChild(targetName)
	if not target then
		warn("Admin: Player not found:", targetName)
		return
	end

	-- Execute command
	if commandType == "GiveMoney" then
		local amount = tonumber(value)
		if not amount or amount <= 0 then
			warn("Admin: Invalid amount")
			return
		end

		_MoneyService.AddMoney(target.UserId, amount)
		print(string.format("✅ Admin %s gave %d$ to %s", admin.Name, amount, targetName))

	elseif commandType == "SetMoney" then
		local amount = tonumber(value)
		if not amount or amount < 0 then
			warn("Admin: Invalid amount")
			return
		end

		local playerData = _PlayerDataService.GetPlayerData(target.UserId)
		if playerData then
			playerData.money = amount
			local OnMoneyChanged = game:GetService("ReplicatedStorage").RemoteInterface.Events.OnMoneyChanged
			OnMoneyChanged:FireClient(target, amount)
			print(string.format("✅ Admin %s set %s money to %d$", admin.Name, targetName, amount))
		end

	elseif commandType == "GiveSpawner" then
		local rarity = value
		local validRarities = {"Common", "Rare", "Epic", "Legendary"}

		if not table.find(validRarities, rarity) then
			warn("Admin: Invalid rarity")
			return
		end

		local playerData = _PlayerDataService.GetPlayerData(target.UserId)
		if playerData then
			playerData:AddToInventory(rarity)
			_PlayerDataService.SavePlayer(target.UserId)
			print(string.format("✅ Admin %s gave %s spawner to %s", admin.Name, rarity, targetName))
		end
	end
end

return AdminService