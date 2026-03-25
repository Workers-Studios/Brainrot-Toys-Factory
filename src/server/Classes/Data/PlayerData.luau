--[[
	PlayerData class - Manages individual player progression data
	Encapsulates all player state including money, inventory, quotas, and placements
	
	Structure:
	- money: Current cash balance
	- inventory: Spawners available for placement {Common = X, Rare = Y, ...}
	- generatorInventory: Generators unlocked via quotas {GeneratorType = {Common = X, ...}}
	- quotaProgress: Collection progress toward generators {ToyType = {Common = X, ...}}
	- placedSpawners: Active spawners on plot [{SlotName = "...", Rarity = "..."}]
	- placedGenerators: Active generators [{SlotName = "...", GeneratorType = "...", Rarity = "..."}]
	
	All modifications trigger auto-save via PlayerDataService
]]

local PlayerData = {}
PlayerData.__index = PlayerData

-- Creates new PlayerData instance with default values
-- @param userId: number - Player's Roblox user ID
-- @return PlayerData - New player data instance
function PlayerData.new(userId)
	local self = setmetatable({}, PlayerData)
	
	self.userId = userId
	self.money = 100  -- Starting cash
	self.rebirthLevel = 0

	-- Spawner inventory (items that can be placed on slots)
	self.inventory = {
		Common    = 0,
		Uncommon  = 0,
		Rare      = 0,
		Epic      = 0,
		Legendary = 0,
	}
	
	-- Generator inventory (unlocked via quotas)
	self.generatorInventory = {
		-- Format: [GeneratorType] = count
		-- Example: Common_Generator = 2, Rare_Generator = 1
	}

	-- Quota progress toward unlocking generators
	self.quotaProgress = {
		-- Format: [Rarity] = currentCount
		-- Example: Common = 5, Rare = 2
	}
	
	-- Physical spawners placed on plot
	self.placedSpawners = {
		-- Array of {SlotName = "SpawnerSlots1", Rarity = "Common"}
	}
	
	-- Physical generators placed on plot
	self.placedGenerators = {
		-- Array of {SlotName = "GeneratorSlot1", GeneratorType = "...", Rarity = "Common"}
	}

	-- Brainrots dans l'inventaire (récupérés depuis les socles, pas encore replacés)
	self.brainrotInventory = {}

	return self
end

-- Loads existing player data from DataStore
-- @param userId: number - Player's user ID
-- @param savedData: table - Data retrieved from DataStore
-- @return PlayerData - Loaded player data instance
function PlayerData.load(userId, savedData)
	local self = setmetatable({}, PlayerData)
	
	self.userId = userId
	self.money = savedData.money or 100
	self.rebirthLevel = savedData.rebirthLevel or 0
	self.inventory = savedData.inventory or {Common = 0, Uncommon = 0, Rare = 0, Epic = 0, Legendary = 0}
	self.generatorInventory = savedData.generatorInventory or {}
	self.quotaProgress = savedData.quotaProgress or {}
	self.placedSpawners = savedData.placedSpawners or {}
	self.placedGenerators  = savedData.placedGenerators  or {}
	self.brainrotInventory = savedData.brainrotInventory or {}

	return self
end

-- Serializes player data for DataStore storage
-- @return table - Data ready for saving
function PlayerData:Serialize()
	return {
		money = self.money,
		rebirthLevel = self.rebirthLevel,
		inventory = self.inventory,
		generatorInventory = self.generatorInventory,
		quotaProgress = self.quotaProgress,
		placedSpawners = self.placedSpawners,
		placedGenerators  = self.placedGenerators,
		brainrotInventory = self.brainrotInventory,
	}
end

-- Adds money to player balance
-- @param amount: number - Money to add
function PlayerData:AddMoney(amount)
	self.money = self.money + amount
end

-- Removes money from player balance (with validation)
-- @param amount: number - Money to remove
-- @return boolean - true if successful, false if insufficient funds
function PlayerData:RemoveMoney(amount)
	if self.money >= amount then
		self.money = self.money - amount
		return true
	end
	return false
end

-- Returns current money balance
-- @return number - Current money amount
function PlayerData:GetMoney()
	return self.money
end

-- Alias pour RemoveMoney, utilisé par MoneyService
-- @param amount: number - Money to deduct
-- @return boolean - true if successful
function PlayerData:DeductMoney(amount)
	return self:RemoveMoney(amount)
end

-- Checks if player has item in inventory
-- @param rarity: string - Item rarity to check
-- @return boolean - true if player has at least 1
function PlayerData:HasInInventory(rarity)
	return self.inventory[rarity] and self.inventory[rarity] > 0
end

-- Adds spawner to inventory
-- @param rarity: string - Spawner rarity
-- @param count: number - Amount to add (default 1)
function PlayerData:AddToInventory(rarity, count)
	count = count or 1
	self.inventory[rarity] = (self.inventory[rarity] or 0) + count
end

-- Removes spawner from inventory
-- @param rarity: string - Spawner rarity
-- @param count: number - Amount to remove (default 1)
-- @return boolean - true if successful
function PlayerData:RemoveFromInventory(rarity, count)
	count = count or 1
	if self.inventory[rarity] and self.inventory[rarity] >= count then
		self.inventory[rarity] = self.inventory[rarity] - count
		return true
	end
	return false
end

-- Adds an egg to inventory
-- @param rarity: string - Rarity of the egg (ex: "Common", "Rare")
-- @param count: number - Amount to add (default 1)
function PlayerData:AddGenerator(rarity, count)
	count = count or 1
	self.generatorInventory[rarity] = (self.generatorInventory[rarity] or 0) + count
end

-- Removes an egg from inventory
-- @param rarity: string - Rarity of the egg (ex: "Common", "Rare")
-- @param count: number - Amount to remove (default 1)
-- @return boolean - true if successful
function PlayerData:RemoveGenerator(rarity, count)
	count = count or 1
	if self.generatorInventory[rarity] and self.generatorInventory[rarity] >= count then
		self.generatorInventory[rarity] = self.generatorInventory[rarity] - count
		return true
	end
	return false
end

-- Ajoute un brainrot récupéré dans l'inventaire
function PlayerData:AddBrainrot(name, modelName, rarity, revenuePerSecond)
	table.insert(self.brainrotInventory, {
		Name             = name,
		ModelName        = modelName or "",
		Rarity           = rarity,
		RevenuePerSecond = revenuePerSecond,
	})
end

-- Retire un brainrot de l'inventaire (premier trouvé par nom)
-- @return boolean - true si trouvé et retiré
function PlayerData:RemoveBrainrot(name)
	for i, b in ipairs(self.brainrotInventory) do
		if b.Name == name then
			table.remove(self.brainrotInventory, i)
			return true
		end
	end
	return false
end

-- Increments quota progress for a rarity
-- @param rarity: string - Rarity of toy collected
function PlayerData:IncrementQuota(rarity)
	self.quotaProgress[rarity] = (self.quotaProgress[rarity] or 0) + 1
end

-- Gets current quota progress
-- @param rarity: string - Rarity tier
-- @return number - Current progress count
function PlayerData:GetQuotaProgress(rarity)
	return self.quotaProgress[rarity] or 0
end

-- Resets quota for a specific rarity
-- @param rarity: string - Rarity tier
function PlayerData:ResetQuota(rarity)
	self.quotaProgress[rarity] = 0
end

return PlayerData