--[[
	LevelService - Gestion des niveaux et de l'EXP

	Responsabilités :
	- Ajouter de l'EXP au joueur lors d'une action
	- Détecter les montées de niveau et mettre à jour playerData.level
	- Respecter le cap (MaxLevel = 50) sauf après Maître Prestige (illimité)
	- Notifier le client via OnLevelChanged à chaque changement d'EXP ou de niveau

	Utilisation :
	  LevelService.AddExp(userId, LevelConfig.ExpRewards.BrainrotGenerated["Rare"])
]]

local LevelService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelConfig       = require(ReplicatedStorage.Shared.LevelConfig)

local _PlayerDataService = nil
local _onLevelChanged    = nil  -- RemoteEvent → client

-- ─── Initialisation ──────────────────────────────────────────────────────────

function LevelService.Init(PlayerDataService)
	_PlayerDataService = PlayerDataService

	_onLevelChanged = ReplicatedStorage
		:WaitForChild("RemoteInterface")
		:WaitForChild("Events")
		:WaitForChild("OnLevelChanged")

	print("✅ [LevelService] initialisé")
end

-- ─── Utilitaires internes ─────────────────────────────────────────────────────

-- Calcule le niveau correspondant à un total d'EXP
-- @param totalExp       : number
-- @param isMasterPrestige: boolean - si true, pas de cap de niveau
-- @return number - niveau calculé
local function calculateLevel(totalExp, isMasterPrestige)
	local maxLevel = isMasterPrestige and 200 or LevelConfig.MaxLevel
	local level    = 1

	for lvl = 2, maxLevel do
		local required = LevelConfig.ExpRequired[lvl]
		if required and totalExp >= required then
			level = lvl
		else
			break
		end
	end

	return level
end

-- Notifie le client de l'état actuel (level + exp + expForNextLevel)
local function notifyClient(userId, playerData)
	local player = game.Players:GetPlayerByUserId(userId)
	if not (player and _onLevelChanged) then return end

	-- Envoyer nil pour expForNext si le joueur est au cap de niveau sans Maître Prestige,
	-- afin que le client affiche "MAX" et la barre pleine plutôt qu'une progression fictive.
	local isAtCap    = not playerData.isMasterPrestige and playerData.level >= LevelConfig.MaxLevel
	local expForNext = isAtCap and nil or LevelConfig.ExpRequired[playerData.level + 1]

	_onLevelChanged:FireClient(
		player,
		playerData.level,
		playerData.exp,
		expForNext
	)
end

-- ─── API publique ─────────────────────────────────────────────────────────────

-- Ajoute de l'EXP au joueur et recalcule son niveau
-- @param userId: number - User ID du joueur
-- @param amount: number - Quantité d'EXP à ajouter
function LevelService.AddExp(userId, amount)
	if not amount or amount <= 0 then return end
	if not _PlayerDataService then return end

	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return end

	-- Respecter le cap de niveau AVANT d'ajouter de l'EXP
	-- (inutile d'accumuler l'EXP si le joueur est au cap effectif)
	local effectiveMaxLevel = playerData.isMasterPrestige and 200 or LevelConfig.MaxLevel
	if playerData.level >= effectiveMaxLevel then
		return
	end

	local oldLevel   = playerData.level
	playerData.exp   = playerData.exp + amount

	-- Recalculer le niveau avec le nouvel EXP
	local newLevel = calculateLevel(playerData.exp, playerData.isMasterPrestige)

	if not playerData.isMasterPrestige then
		newLevel = math.min(newLevel, LevelConfig.MaxLevel)
	end

	playerData.level = newLevel

	if newLevel > oldLevel then
		print(string.format("[LevelService] Joueur %d : Niveau %d → %d", userId, oldLevel, newLevel))
	end

	-- Toujours notifier (l'EXP a changé même si le niveau est identique)
	notifyClient(userId, playerData)
end

-- Envoie les données de niveau initiales au client lors de la connexion
-- @param userId: number
function LevelService.SendInitialData(userId)
	if not _PlayerDataService then return end
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return end
	notifyClient(userId, playerData)
end

-- Retourne l'EXP requis pour passer au niveau suivant
-- (utile pour d'autres services qui veulent afficher la progression)
-- @param currentLevel: number
-- @return number|nil - EXP total requis, nil si pas de prochain niveau connu
function LevelService.GetExpForNextLevel(currentLevel)
	return LevelConfig.ExpRequired[currentLevel + 1]
end

return LevelService
