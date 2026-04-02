--[[
	PlayerData class - Manages individual player progression data
	Encapsulates all player state including money, inventory, quotas, placements,
	level progression and prestige.

	Structure:
	- money              : Current cash balance
	- level              : Current player level (1-50, illimité après Maître Prestige)
	- exp                : EXP total cumulé depuis le dernier prestige
	- prestigeLevel      : Palier de prestige actuel (0-10, permanent)
	- isMasterPrestige   : true une fois le Maître Prestige obtenu (permanent, irréversible)
	- inventory          : Spawners disponibles pour placement {Common = X, ...}
	- generatorInventory : Générateurs débloqués via quotas {GeneratorType = X}
	- quotaProgress      : Progression de collecte vers générateurs {Rarity = X}
	- placedSpawners     : Spawners actifs sur le plot [{SlotName, Rarity}]
	- placedGenerators   : Générateurs actifs sur le plot [{SlotName, GeneratorType, Rarity}]
	- brainrotInventory  : Brainrots dans l'inventaire (non placés sur socles)
	- discoveredBrainrots: Brainrots découverts au moins une fois, par variante {Normal={}, Gold={}, Diamond={}}

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
	self.money  = 100  -- Starting cash

	-- ─── Progression ─────────────────────────────────────────────────────────
	self.level           = 1
	self.exp             = 0
	self.prestigeLevel   = 0      -- 0 = pas encore de prestige
	self.isMasterPrestige = false  -- Devient true après le Maître Prestige

	-- ─── Spawner inventory ───────────────────────────────────────────────────
	self.inventory = {
		Common    = 0,
		Uncommon  = 0,
		Rare      = 0,
		Epic      = 0,
		Legendary = 0,
	}

	-- ─── Generator inventory ─────────────────────────────────────────────────
	self.generatorInventory = {}

	-- ─── Quota progress ──────────────────────────────────────────────────────
	self.quotaProgress = {}

	-- ─── Physical spawners on plot ───────────────────────────────────────────
	self.placedSpawners = {}

	-- ─── Physical generators on plot ─────────────────────────────────────────
	self.placedGenerators = {}

	-- ─── Brainrots in inventory (picked up but not placed on display) ─────────
	self.brainrotInventory = {}

	-- ─── Brainrots découverts (persistant, par variante) ─────────────────────
	self.discoveredBrainrots = { Normal = {}, Gold = {}, Diamond = {} }

	return self
end

-- Loads existing player data from DataStore
-- @param userId: number - Player's user ID
-- @param savedData: table - Data retrieved from DataStore
-- @return PlayerData - Loaded player data instance
function PlayerData.load(userId, savedData)
	local self = setmetatable({}, PlayerData)

	self.userId = userId
	self.money  = savedData.money or 100

	-- ─── Progression (rétrocompatibilité : les anciens comptes auront level=1) ──
	self.level            = savedData.level            or 1
	self.exp              = savedData.exp              or 0
	self.prestigeLevel    = savedData.prestigeLevel    or 0
	self.isMasterPrestige = savedData.isMasterPrestige or false

	self.inventory          = savedData.inventory         or { Common = 0, Uncommon = 0, Rare = 0, Epic = 0, Legendary = 0 }
	self.generatorInventory = savedData.generatorInventory or {}
	self.quotaProgress      = savedData.quotaProgress     or {}
	self.placedSpawners     = savedData.placedSpawners    or {}
	self.placedGenerators   = savedData.placedGenerators  or {}
	self.brainrotInventory   = savedData.brainrotInventory or {}

	-- Rétrocompatibilité : anciens comptes n'ont pas discoveredBrainrots
	local saved = savedData.discoveredBrainrots or {}
	self.discoveredBrainrots = {
		Normal  = saved.Normal  or {},
		Gold    = saved.Gold    or {},
		Diamond = saved.Diamond or {},
	}

	return self
end

-- Serializes player data for DataStore storage
-- @return table - Data ready for saving
function PlayerData:Serialize()
	return {
		money             = self.money,
		level             = self.level,
		exp               = self.exp,
		prestigeLevel     = self.prestigeLevel,
		isMasterPrestige  = self.isMasterPrestige,
		inventory         = self.inventory,
		generatorInventory = self.generatorInventory,
		quotaProgress     = self.quotaProgress,
		placedSpawners    = self.placedSpawners,
		placedGenerators  = self.placedGenerators,
		brainrotInventory    = self.brainrotInventory,
		discoveredBrainrots  = self.discoveredBrainrots,
	}
end

-- ─── Money ───────────────────────────────────────────────────────────────────

function PlayerData:AddMoney(amount)
	self.money = self.money + amount
end

function PlayerData:RemoveMoney(amount)
	if self.money >= amount then
		self.money = self.money - amount
		return true
	end
	return false
end

function PlayerData:GetMoney()
	return self.money
end

-- Alias pour RemoveMoney, utilisé par MoneyService
function PlayerData:DeductMoney(amount)
	return self:RemoveMoney(amount)
end

-- ─── Spawner inventory ────────────────────────────────────────────────────────

function PlayerData:HasInInventory(rarity)
	return self.inventory[rarity] and self.inventory[rarity] > 0
end

function PlayerData:AddToInventory(rarity, count)
	count = count or 1
	self.inventory[rarity] = (self.inventory[rarity] or 0) + count
end

function PlayerData:RemoveFromInventory(rarity, count)
	count = count or 1
	if self.inventory[rarity] and self.inventory[rarity] >= count then
		self.inventory[rarity] = self.inventory[rarity] - count
		return true
	end
	return false
end

-- ─── Generator inventory ─────────────────────────────────────────────────────

function PlayerData:AddGenerator(rarity, count)
	count = count or 1
	self.generatorInventory[rarity] = (self.generatorInventory[rarity] or 0) + count
end

function PlayerData:RemoveGenerator(rarity, count)
	count = count or 1
	if self.generatorInventory[rarity] and self.generatorInventory[rarity] >= count then
		self.generatorInventory[rarity] = self.generatorInventory[rarity] - count
		return true
	end
	return false
end

-- ─── Brainrot inventory ───────────────────────────────────────────────────────

function PlayerData:AddBrainrot(name, modelName, rarity, revenuePerSecond, variant)
	table.insert(self.brainrotInventory, {
		Name             = name,
		ModelName        = modelName or "",
		Rarity           = rarity,
		RevenuePerSecond = revenuePerSecond,
		Variant          = variant or "Normal",
	})
end

-- Marque un brainrot comme découvert (au moins une fois) pour la page Index
-- @param name    : string — nom du brainrot (ex. "Lirili Larila")
-- @param variant : string — "Normal" | "Gold" | "Diamond"
function PlayerData:DiscoverBrainrot(name, variant)
	local v = variant or "Normal"
	local list = self.discoveredBrainrots[v]
	if not list then return end
	for _, existing in ipairs(list) do
		if existing == name then return end  -- déjà découvert
	end
	table.insert(list, name)
end

function PlayerData:RemoveBrainrot(name)
	for i, b in ipairs(self.brainrotInventory) do
		if b.Name == name then
			table.remove(self.brainrotInventory, i)
			return true
		end
	end
	return false
end

-- ─── Quota ────────────────────────────────────────────────────────────────────

function PlayerData:IncrementQuota(rarity)
	self.quotaProgress[rarity] = (self.quotaProgress[rarity] or 0) + 1
end

function PlayerData:GetQuotaProgress(rarity)
	return self.quotaProgress[rarity] or 0
end

function PlayerData:ResetQuota(rarity)
	self.quotaProgress[rarity] = 0
end

return PlayerData
