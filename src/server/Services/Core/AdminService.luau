--[[
	Admin commands system with UI support
	Only authorized users can execute admin commands via secure RemoteEvents
	
	Commands:
	- GiveMoney: Add money to player
	- SetMoney: Set player money to exact amount
	- GiveSpawner: Give spawner to player inventory
]]

local AdminService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local _PlayerDataService = nil
local _MoneyService      = nil
local _LevelService      = nil
local _PrestigeService   = nil

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
function AdminService.Init(PlayerDataService, MoneyService, LevelService, PrestigeService)
	_PlayerDataService = PlayerDataService
	_MoneyService      = MoneyService
	_LevelService      = LevelService
	_PrestigeService   = PrestigeService

	local adminFolder = ReplicatedStorage.RemoteInterface:WaitForChild("Admin")

	-- Connecter les handlers sur les remotes pré-créées par ServerInit
	local isAdminRemote = adminFolder:WaitForChild("IsAdmin")
	isAdminRemote.OnServerInvoke = function(player)
		return isAdmin(player.UserId)
	end

	local executeCommandRemote = adminFolder:WaitForChild("ExecuteCommand")
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
			_PlayerDataService.SavePlayer(target.UserId)
			print(string.format("✅ Admin %s set %s money to %d$", admin.Name, targetName, amount))
		end

	elseif commandType == "GiveSpawner" then
		local rarity = value
		local validRarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary"}

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

	elseif commandType == "AddExp" then
		local amount = tonumber(value)
		if not amount or amount <= 0 then
			warn("Admin: Invalid exp amount")
			return
		end
		if not _LevelService then warn("Admin: LevelService unavailable") return end
		_LevelService.AddExp(target.UserId, amount)
		print(string.format("✅ Admin %s gave %d EXP to %s", admin.Name, amount, targetName))

	elseif commandType == "SetLevel" then
		local level = tonumber(value)
		if not level or level < 1 then
			warn("Admin: Invalid level")
			return
		end
		if not _LevelService then warn("Admin: LevelService unavailable") return end
		local playerData = _PlayerDataService.GetPlayerData(target.UserId)
		if playerData then
			level = math.floor(level)
			local LevelConfig = require(ReplicatedStorage.Shared.LevelConfig)
			local maxLevel = playerData.isMasterPrestige and math.huge or LevelConfig.MaxLevel
			level = math.clamp(level, 1, maxLevel)
			playerData.level = level
			-- Set EXP to the exact threshold for this level so AddExp works correctly
			playerData.exp = 0
			_PlayerDataService.SavePlayer(target.UserId)
			-- Notify client via LevelService
			_LevelService.SendInitialData(target.UserId)
			print(string.format("✅ Admin %s set %s to level %d", admin.Name, targetName, level))
		end

	elseif commandType == "SetPrestige" then
		local prestigeLevel = tonumber(value)
		if not prestigeLevel or prestigeLevel < 0 then
			warn("Admin: Invalid prestige level")
			return
		end
		local PrestigeConfig = require(ReplicatedStorage.Shared.PrestigeConfig)
		prestigeLevel = math.floor(math.min(prestigeLevel, PrestigeConfig.MaxPrestige))
		local playerData = _PlayerDataService.GetPlayerData(target.UserId)
		if playerData then
			playerData.prestigeLevel = prestigeLevel
			playerData.isMasterPrestige = false
			_PlayerDataService.SavePlayer(target.UserId)
			if _PrestigeService then
				_PrestigeService.SendInitialData(target.UserId)
			end
			print(string.format("✅ Admin %s set %s prestige to %d", admin.Name, targetName, prestigeLevel))
		end

	elseif commandType == "GiveBrainrot" then
		local rarity = value
		local validRarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary"}
		if not table.find(validRarities, rarity) then
			warn("Admin: Invalid rarity for brainrot")
			return
		end
		local playerData = _PlayerDataService.GetPlayerData(target.UserId)
		if playerData then
			-- Add a placeholder brainrot entry to brainrotInventory
			table.insert(playerData.brainrotInventory, {
				Name   = "Admin_" .. rarity,
				Rarity = rarity,
			})
			_PlayerDataService.SavePlayer(target.UserId)
			print(string.format("✅ Admin %s gave %s brainrot to %s", admin.Name, rarity, targetName))
		end
	end
end

return AdminService