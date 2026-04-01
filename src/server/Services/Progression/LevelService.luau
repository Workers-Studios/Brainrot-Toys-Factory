--[[
	LevelService - Gestion des niveaux et de l'EXP

	Système relatif : playerData.exp = EXP dans le niveau actuel (repart à 0 au level up).
	Le surplus est conservé lors d'un level up.
]]

local LevelService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelConfig       = require(ReplicatedStorage.Shared.LevelConfig)

local _PlayerDataService = nil
local _onLevelChanged    = nil

function LevelService.Init(PlayerDataService)
	_PlayerDataService = PlayerDataService

	_onLevelChanged = ReplicatedStorage
		:WaitForChild("RemoteInterface")
		:WaitForChild("Events")
		:WaitForChild("OnLevelChanged")

	print("✅ [LevelService] initialisé")
end

-- Notifie le client (level, exp actuelle, seuil du niveau actuel)
local function notifyClient(userId, playerData)
	local player = game.Players:GetPlayerByUserId(userId)
	if not (player and _onLevelChanged) then return end

	local isAtCap    = not playerData.isMasterPrestige and playerData.level >= LevelConfig.MaxLevel
	local expForNext = isAtCap and nil or LevelConfig.GetExpRequired(playerData.level)

	_onLevelChanged:FireClient(player, playerData.level, playerData.exp, expForNext)
end

-- Ajoute de l'EXP et gère les level up (avec surplus)
function LevelService.AddExp(userId, amount)
	if not amount or amount <= 0 then return end
	if not _PlayerDataService then return end

	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return end

	-- Cap : pas d'EXP si niveau max atteint (sauf Maître Prestige = illimité)
	if not playerData.isMasterPrestige and playerData.level >= LevelConfig.MaxLevel then return end

	local oldLevel = playerData.level
	playerData.exp = playerData.exp + amount

	-- Level up en boucle (gère les multi-level en un seul gain)
	while true do
		if not playerData.isMasterPrestige and playerData.level >= LevelConfig.MaxLevel then
			playerData.exp = 0  -- plafonner l'EXP au niveau max
			break
		end

		local threshold = LevelConfig.GetExpRequired(playerData.level)
		if playerData.exp >= threshold then
			playerData.exp   = playerData.exp - threshold
			playerData.level = playerData.level + 1
		else
			break
		end
	end

	if playerData.level > oldLevel then
		print(string.format("[LevelService] Joueur %d : Niveau %d → %d", userId, oldLevel, playerData.level))
	end

	notifyClient(userId, playerData)
end

-- Envoie les données initiales au client à la connexion
function LevelService.SendInitialData(userId)
	if not _PlayerDataService then return end
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return end
	notifyClient(userId, playerData)
end

function LevelService.GetExpForNextLevel(level)
	return LevelConfig.GetExpRequired(level)
end

return LevelService
