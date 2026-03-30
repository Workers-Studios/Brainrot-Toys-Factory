--[[
	Classe PlayerData — gestion de la progression individuelle d'un joueur
	Encapsule tout l'état joueur : argent, inventaire, quotas, placements

	Structure :
	- money             : solde actuel
	- inventory         : spawners disponibles {[rarity] = count}
	- generatorInventory: œufs débloqués via quotas {[rarity] = count}
	- quotaProgress     : progression de collecte {[rarity] = count}
	- placedSpawners    : spawners posés sur le plot [{SlotName, Rarity}]
	- placedGenerators  : générateurs posés [{SlotName, Rarity, BrainrotName, ...}]
	- brainrotInventory : brainrots en inventaire (récupérés depuis les socles)

	Scalabilité : l'inventaire de départ est généré depuis Enums.RarityList —
	ajouter une rareté dans Enums suffit, pas besoin de modifier ce fichier.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Enums)

local PlayerData = {}
PlayerData.__index = PlayerData

-- Génère un inventaire par défaut pour toutes les raretés connues
local function defaultInventory()
	local inv = {}
	for _, rarity in ipairs(Enums.RarityList) do
		inv[rarity] = 0
	end
	return inv
end

-- Crée une nouvelle instance PlayerData avec les valeurs par défaut
-- @param userId: number - Roblox user ID du joueur
function PlayerData.new(userId)
	local self = setmetatable({}, PlayerData)

	self.userId           = userId
	self.money            = 100
	self.rebirthLevel     = 0
	self.inventory        = defaultInventory()
	self.generatorInventory = {}
	self.quotaProgress    = {}
	self.placedSpawners   = {}
	self.placedGenerators = {}
	self.brainrotInventory = {}

	return self
end

-- Charge des données existantes depuis le DataStore
-- @param userId    : number - Roblox user ID
-- @param savedData : table  - Données récupérées du DataStore
function PlayerData.load(userId, savedData)
	local self = setmetatable({}, PlayerData)

	self.userId             = userId
	self.money              = savedData.money             or 100
	self.rebirthLevel       = savedData.rebirthLevel      or 0
	self.inventory          = savedData.inventory         or defaultInventory()
	self.generatorInventory = savedData.generatorInventory or {}
	self.quotaProgress      = savedData.quotaProgress      or {}
	self.placedSpawners     = savedData.placedSpawners     or {}
	self.placedGenerators   = savedData.placedGenerators   or {}
	self.brainrotInventory  = savedData.brainrotInventory  or {}

	return self
end

-- Sérialise les données pour le DataStore
function PlayerData:Serialize()
	return {
		money              = self.money,
		rebirthLevel       = self.rebirthLevel,
		inventory          = self.inventory,
		generatorInventory = self.generatorInventory,
		quotaProgress      = self.quotaProgress,
		placedSpawners     = self.placedSpawners,
		placedGenerators   = self.placedGenerators,
		brainrotInventory  = self.brainrotInventory,
	}
end

-- ── Argent ────────────────────────────────────────────────────────────────────

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

-- Alias pour RemoveMoney (utilisé par MoneyService)
function PlayerData:DeductMoney(amount)
	return self:RemoveMoney(amount)
end

-- ── Inventaire spawners ────────────────────────────────────────────────────────

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

-- ── Inventaire œufs (générateurs) ────────────────────────────────────────────

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

-- ── Brainrots ─────────────────────────────────────────────────────────────────

function PlayerData:AddBrainrot(name, modelName, rarity, revenuePerSecond)
	table.insert(self.brainrotInventory, {
		Name             = name,
		ModelName        = modelName or "",
		Rarity           = rarity,
		RevenuePerSecond = revenuePerSecond,
	})
end

-- Retire le premier brainrot trouvé par nom
function PlayerData:RemoveBrainrot(name)
	for i, b in ipairs(self.brainrotInventory) do
		if b.Name == name then
			table.remove(self.brainrotInventory, i)
			return true
		end
	end
	return false
end

-- ── Quota ─────────────────────────────────────────────────────────────────────

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
