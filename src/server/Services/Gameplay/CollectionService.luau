--[[
	Gestion de la collecte de toys et du système de quota
	Les toys sont identifiés par leur rareté uniquement

	Workflow : toy collecté → quota incrémenté → quota atteint → œuf distribué

	Couplages via Signal (pas de require direct sur d'autres services) :
	  Écoute  "ToyReachedCollection" → émis par ConveyorService
	  Émet    "QuotaComplete"        → écouté par PlacementService
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal  = require(game.ServerScriptService.Framework.Signal)
local Network = require(ReplicatedStorage.Shared.Network)

local CollectionService = {}

local _PlayerDataService = nil
local _ToyConfig         = nil
local _quotaRequirements = {}  -- [rarity] = nombre requis
local _processingQuota   = {}  -- [userId_rarity] = true : guard contre concurrence

local _OnQuotaUpdated = nil

-- Initialise le service
function CollectionService.Init(PlayerDataService, ToyConfig, _GeneratorService)
	_PlayerDataService = PlayerDataService
	_ToyConfig         = ToyConfig

	_OnQuotaUpdated = ReplicatedStorage
		:WaitForChild("RemoteInterface")
		:WaitForChild("Events")
		:WaitForChild(Network.Events.OnQuotaUpdated)

	for rarity, data in pairs(ToyConfig) do
		_quotaRequirements[rarity] = data.QuotaToGenerator
	end

	-- Écouter la zone de collecte — ConveyorService émet cet événement
	Signal.Connect("ToyReachedCollection", CollectionService.OnToyCollected)

	print("CollectionService initialized")
end

-- Traite un toy qui a atteint la zone de collecte
function CollectionService.OnToyCollected(toy)
	if not toy then return end

	local part = toy
	if toy:IsA("Model") then
		part = toy.PrimaryPart or toy:FindFirstChildWhichIsA("BasePart")
		if not part then toy:Destroy(); return end
	elseif not toy:IsA("BasePart") then
		return
	end

	local rarity = part:GetAttribute("ToyRarity")
	local userId = part:GetAttribute("OwnerId")

	if not rarity or not userId then toy:Destroy(); return end
	if not _ToyConfig[rarity]    then toy:Destroy(); return end

	CollectionService.IncrementQuota(userId, rarity)
	CollectionService.CheckQuotaComplete(userId, rarity)

	toy:Destroy()
end

-- Incrémente le quota d'une rareté et notifie le client
function CollectionService.IncrementQuota(userId, rarity)
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return 0 end

	if not playerData.quotaProgress[rarity] then
		playerData.quotaProgress[rarity] = 0
	end
	playerData.quotaProgress[rarity] += 1

	local player   = game.Players:GetPlayerByUserId(userId)
	local maxQuota = _quotaRequirements[rarity]
	if player and maxQuota and _OnQuotaUpdated then
		_OnQuotaUpdated:FireClient(player, rarity, playerData.quotaProgress[rarity], maxQuota)
	end

	return playerData.quotaProgress[rarity]
end

-- Vérifie si le quota est atteint et émet la récompense
function CollectionService.CheckQuotaComplete(userId, rarity)
	local key = userId .. "_" .. rarity
	if _processingQuota[key] then return false end

	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return false end

	local required = _quotaRequirements[rarity]
	local current  = playerData.quotaProgress[rarity] or 0
	if current < required then return false end

	_processingQuota[key] = true

	_PlayerDataService.AddGenerator(userId, rarity)

	local player = game.Players:GetPlayerByUserId(userId)
	if player then
		-- Découplé : PlacementService écoute "QuotaComplete" dans son Init()
		Signal.Fire("QuotaComplete", player, rarity)
	end

	playerData.quotaProgress[rarity] = 0
	_PlayerDataService.SavePlayer(userId)

	if player and _OnQuotaUpdated then
		_OnQuotaUpdated:FireClient(player, rarity, 0, required)
	end

	_processingQuota[key] = nil
	return true
end

return CollectionService
