--[[
	Gestion de la collecte de toys et du système de quota
	Les toys sont identifiés par leur rareté uniquement (plus de "type")

	Workflow : collecter des toys → remplir le quota par rareté → recevoir un oeuf générateur
]]

local CollectionService = {}

local _PlayerDataService = nil
local _GeneratorService  = nil
local _ToyConfig         = nil
local _quotaRequirements = {}  -- [rarity] = nombre requis
local _toyOwners         = {}
local _processingQuota   = {}  -- [userId_rarity] = true : guard contre appels concurrents

local _OnNotification = game:GetService("ReplicatedStorage")
	:WaitForChild("RemoteInterface")
	:WaitForChild("Events")
	:WaitForChild("OnNotification")

-- Initialise le service
-- @param PlayerDataService : service - données joueur
-- @param ToyConfig         : table   - config des toys par rareté
-- @param GeneratorService  : service - service de génération d'argent
function CollectionService.Init(PlayerDataService, ToyConfig, GeneratorService)
	_PlayerDataService = PlayerDataService
	_GeneratorService  = GeneratorService
	_ToyConfig         = ToyConfig

	-- Cache des quotas requis par rareté
	for rarity, data in pairs(ToyConfig) do
		_quotaRequirements[rarity] = data.QuotaToGenerator
	end

	print("CollectionService initialized")
end

-- Appelé quand un toy touche la zone de collecte
-- @param toy : BasePart - le toy collecté
function CollectionService.OnToyCollected(toy)
	if not toy then return end

	-- Chercher la BasePart principale (si c'est un Model, prendre le PrimaryPart)
	local part = toy
	if toy:IsA("Model") then
		part = toy.PrimaryPart or toy:FindFirstChildWhichIsA("BasePart")
		if not part then toy:Destroy(); return end
	elseif not toy:IsA("BasePart") then
		return
	end

	local rarity = part:GetAttribute("ToyRarity")
	local userId = part:GetAttribute("OwnerId")

	if not rarity or not userId then
		toy:Destroy()
		return
	end

	if not _ToyConfig[rarity] then
		toy:Destroy()
		return
	end

	CollectionService.IncrementQuota(userId, rarity)
	CollectionService.CheckQuotaComplete(userId, rarity)

	toy:Destroy()
end

-- Incrémente le quota d'une rareté pour un joueur
-- @param userId : number - ID du joueur
-- @param rarity : string - rareté du toy collecté
-- @return number - quota actuel après incrément
function CollectionService.IncrementQuota(userId, rarity)
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return 0 end

	-- Initialise si nécessaire
	if not playerData.quotaProgress[rarity] then
		playerData.quotaProgress[rarity] = 0
	end

	playerData.quotaProgress[rarity] += 1

	-- Pas de save ici : le quota est sauvegardé lors de la complétion ou au disconnect

	-- Notifier le client
	local OnQuotaUpdated = game:GetService("ReplicatedStorage").RemoteInterface.Events.OnQuotaUpdated
	local player = game.Players:GetPlayerByUserId(userId)
	local maxQuota = _quotaRequirements[rarity]

	if player and maxQuota then
		OnQuotaUpdated:FireClient(player, rarity, playerData.quotaProgress[rarity], maxQuota)
	end

	return playerData.quotaProgress[rarity]
end

-- Vérifie si le quota est atteint et distribue la récompense
-- @param userId : number - ID du joueur
-- @param rarity : string - rareté à vérifier
-- @return boolean - true si quota complété
function CollectionService.CheckQuotaComplete(userId, rarity)
	-- Guard contre double-exécution concurrente pour le même joueur+rareté
	local key = userId .. "_" .. rarity
	if _processingQuota[key] then return false end

	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return false end

	local required = _quotaRequirements[rarity]
	local current  = playerData.quotaProgress[rarity] or 0

	if current < required then return false end

	_processingQuota[key] = true  -- Verrouiller avant tout yield potentiel

	-- Récompense : oeuf de la rareté du toy collecté
	_PlayerDataService.AddGenerator(userId, rarity)

	local player = game.Players:GetPlayerByUserId(userId)
	if player then
		local PlacementService = require(script.Parent.PlacementService)
		PlacementService.GiveEggTool(player, rarity)

		if _OnNotification then
			_OnNotification:FireClient(player, "Oeuf " .. rarity .. " obtenu !", "SUCCESS")
		end
	end

	-- Reset quota
	playerData.quotaProgress[rarity] = 0

	-- Save déboncé (le debounce suffit, pas besoin d'immédiat ici)
	_PlayerDataService.SavePlayer(userId)

	-- Notifier le client du reset
	local OnQuotaUpdated = game:GetService("ReplicatedStorage").RemoteInterface.Events.OnQuotaUpdated
	if player then
		OnQuotaUpdated:FireClient(player, rarity, 0, required)
	end

	_processingQuota[key] = nil  -- Déverrouiller

	return true
end

-- Enregistre le propriétaire d'un toy
-- @param toy    : BasePart - le toy
-- @param userId : number   - ID du propriétaire
function CollectionService.RegisterToyOwner(toy, userId)
	_toyOwners[toy] = userId
end

return CollectionService
