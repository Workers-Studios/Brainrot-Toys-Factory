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
		Common    = 1,  -- Start with 1 free common spawner
		Uncommon  = 0,
		Rare      = 0,
		Epic      = 0,
		Legendary = 0,
	}
	
	-- Generator inventory (unlocked via quotas)
	self.generatorInventory = {
		-- Format: [GeneratorType][Rarity] = count
		-- Example: Tralalero_Tralala_Generator = {Common = 1, Rare = 0, ...}
	}
	
	-- Quota progress toward unlocking generators
	self.quotaProgress = {
		-- Format: [ToyType][Rarity] = currentCount
		-- Example: TralaleroTralala = {Common = 5, Rare = 2, ...}
	}
	
	-- Physical spawners placed on plot
	self.placedSpawners = {
		-- Array of {SlotName = "SpawnerSlots1", Rarity = "Common"}
	}
	
	-- Physical generators placed on plot
	self.placedGenerators = {
		-- Array of {SlotName = "GeneratorSlot1", GeneratorType = "...", Rarity = "Common"}
	}
	
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
	self.inventory = savedData.inventory or {Common = 1, Uncommon = 0, Rare = 0, Epic = 0, Legendary = 0}
	self.generatorInventory = savedData.generatorInventory or {}
	self.quotaProgress = savedData.quotaProgress or {}
	self.placedSpawners = savedData.placedSpawners or {}
	self.placedGenerators = savedData.placedGenerators or {}
	
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
		placedGenerators = self.placedGenerators
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

-- Adds generator to inventory
-- @param generatorType: string - Type of generator
-- @param rarity: string - Generator rarity
-- @param count: number - Amount to add (default 1)
function PlayerData:AddGenerator(generatorType, rarity, count)
	count = count or 1
	
	-- Initialize generator type if doesn't exist
	if not self.generatorInventory[generatorType] then
		self.generatorInventory[generatorType] = {
			Common = 0,
			Rare = 0,
			Epic = 0,
			Legendary = 0
		}
	end
	
	self.generatorInventory[generatorType][rarity] = 
		(self.generatorInventory[generatorType][rarity] or 0) + count
end

-- Removes generator from inventory
-- @param generatorType: string - Type of generator
-- @param rarity: string - Generator rarity
-- @param count: number - Amount to remove (default 1)
-- @return boolean - true if successful
function PlayerData:RemoveGenerator(generatorType, rarity, count)
	count = count or 1
	
	if self.generatorInventory[generatorType] and 
	   self.generatorInventory[generatorType][rarity] and
	   self.generatorInventory[generatorType][rarity] >= count then
		self.generatorInventory[generatorType][rarity] = 
			self.generatorInventory[generatorType][rarity] - count
		return true
	end
	
	return false
end

-- Increments quota progress for a toy type and rarity
-- @param toyType: string - Type of toy collected
-- @param rarity: string - Rarity of toy collected
function PlayerData:IncrementQuota(toyType, rarity)
	-- Initialize toy type if doesn't exist
	if not self.quotaProgress[toyType] then
		self.quotaProgress[toyType] = {
			Common = 0,
			Rare = 0,
			Epic = 0,
			Legendary = 0
		}
	end
	
	self.quotaProgress[toyType][rarity] = 
		(self.quotaProgress[toyType][rarity] or 0) + 1
end

-- Gets current quota progress
-- @param toyType: string - Type of toy
-- @param rarity: string - Rarity tier
-- @return number - Current progress count
function PlayerData:GetQuotaProgress(toyType, rarity)
	if self.quotaProgress[toyType] and self.quotaProgress[toyType][rarity] then
		return self.quotaProgress[toyType][rarity]
	end
	return 0
end

-- Resets quota for a specific toy type and rarity
-- @param toyType: string - Type of toy
-- @param rarity: string - Rarity tier
function PlayerData:ResetQuota(toyType, rarity)
	if self.quotaProgress[toyType] then
		self.quotaProgress[toyType][rarity] = 0
	end
end

return PlayerData