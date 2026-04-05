--[[
	PrestigeService - Gestion du système de Prestige

	Inspiré du système de prestige Call of Duty Multijoueur :
	le joueur sacrifie sa progression en échange d'un rang permanent.

	Responsabilités :
	- Vérifier si un joueur remplit les conditions pour passer au prestige suivant
	- Exécuter le prestige : reset de la progression + incrément du rang
	- Gérer le cas spécial du Maître Prestige (après Prestige 10 + Niveau 50)
	- Notifier le client du nouveau rang

	Conditions pour passer un prestige :
	  1. Niveau 50 atteint (ou niveau 50 + Prestige 10 pour le Maître Prestige)
	  2. Posséder le montant d'argent requis
	  3. Posséder un brainrot d'une rareté spécifique dans son inventaire

	Ce qui est RESET lors d'un prestige :
	  - money             → 0
	  - level             → 1
	  - exp               → 0
	  - inventory         → vide
	  - generatorInventory→ vide
	  - brainrotInventory → vide (brainrots en inventaire seulement, PAS ceux sur les socles)
	  - placedSpawners    → vide (les spawners sont retirés du monde)
	  - quotaProgress     → vide

	Ce qui est CONSERVÉ :
	  - prestigeLevel     (permanent, irréversible)
	  - isMasterPrestige  (permanent, irréversible)
	  - placedGenerators  (les brainrots déjà posés sur les socles)
]]

local PrestigeService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PrestigeConfig    = require(ReplicatedStorage.Shared.PrestigeConfig)
local LevelConfig       = require(ReplicatedStorage.Shared.LevelConfig)

-- FloorConfig chargé de façon défensive (fichier peut ne pas encore être synchronisé)
local FloorConfig = nil
do
	local mod = ReplicatedStorage.Shared:FindFirstChild("FloorConfig")
	if mod then
		local ok, result = pcall(require, mod)
		if ok then FloorConfig = result end
	end
end

local _PlayerDataService  = nil
local _PlacementService   = nil
local _FloorService       = nil
local _ToyConfig          = nil
local _onPrestigeChanged  = nil  -- RemoteEvent → client
local _onNotification     = nil  -- RemoteEvent → client (notification toast)
local _onMoneyChanged     = nil  -- RemoteEvent → client (mise à jour HUD argent)
local _onQuotaUpdated     = nil  -- RemoteEvent → client (reset quota UI après prestige)

-- ─── Initialisation ──────────────────────────────────────────────────────────

function PrestigeService.Init(PlayerDataService, PlacementService, ToyConfig, FloorService)
	_PlayerDataService = PlayerDataService
	_PlacementService  = PlacementService
	_FloorService      = FloorService
	_ToyConfig         = ToyConfig

	local RI = ReplicatedStorage:WaitForChild("RemoteInterface")
	_onPrestigeChanged = RI:WaitForChild("Events"):WaitForChild("OnPrestigeChanged")
	_onNotification    = RI:WaitForChild("Events"):WaitForChild("OnNotification")
	_onMoneyChanged    = RI:WaitForChild("Events"):WaitForChild("OnMoneyChanged")
	_onQuotaUpdated    = RI:WaitForChild("Events"):WaitForChild("OnQuotaUpdated")

	-- Re-synchronise les attributs prestige à chaque respawn
	local Players = game:GetService("Players")
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function(character)
			task.wait(0.5)  -- laisser PlayerData se charger
			local pd = _PlayerDataService.GetPlayerData(p.UserId)
			if pd then
				character:SetAttribute("PlayerPrestige", pd.prestigeLevel or 0)
				character:SetAttribute("PlayerIsMaster",  pd.isMasterPrestige or false)
			end
		end)
	end)

	print("✅ [PrestigeService] initialisé")
end

-- ─── Utilitaires internes ─────────────────────────────────────────────────────

-- Vérifie si le joueur possède au moins un brainrot de la rareté donnée
-- dans son inventaire (brainrotInventory — PAS les socles)
local function hasBrainrotOfRarity(playerData, requiredRarity)
	for _, brainrot in ipairs(playerData.brainrotInventory) do
		if brainrot.Rarity == requiredRarity then
			return true
		end
	end
	return false
end

-- ─── API publique ─────────────────────────────────────────────────────────────

-- Vérifie si le joueur peut passer au prochain prestige
-- @param userId: number
-- @return boolean canPrestige, string reason
function PrestigeService.CanPrestige(userId)
	if not _PlayerDataService then return false, "Service non initialisé" end
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then
		return false, "Données introuvables"
	end

	-- Déjà Maître Prestige → impossible d'aller plus loin
	if playerData.isMasterPrestige then
		return false, "Tu es déjà au Maître Prestige !"
	end

	-- Vérifier le cap de niveau
	if playerData.level < LevelConfig.MaxLevel then
		return false, string.format("Niveau insuffisant : %d/%d", playerData.level, LevelConfig.MaxLevel)
	end

	-- Seule condition : niveau 50 atteint (vérifié ci-dessus)
	local isMasterRequest = (playerData.prestigeLevel >= PrestigeConfig.MaxPrestige)

	if isMasterRequest then
		return true, "✦ Maître Prestige disponible !"
	end
	return true, string.format("Prestige %d disponible !", playerData.prestigeLevel + 1)
end

-- Exécute le prestige pour un joueur
-- @param userId: number
-- @return boolean success, string message
function PrestigeService.DoPrestige(userId)
	local canPrestige, reason = PrestigeService.CanPrestige(userId)
	if not canPrestige then
		return false, reason
	end

	local playerData      = _PlayerDataService.GetPlayerData(userId)
	local isMasterRequest = (playerData.prestigeLevel >= PrestigeConfig.MaxPrestige)

	local player = game.Players:GetPlayerByUserId(userId)

	-- ─── 1. Supprimer les spawners du monde (sans retour en inventaire) ──────
	if _PlacementService and _PlacementService.ForceRemoveAllSpawners then
		_PlacementService.ForceRemoveAllSpawners(userId)
	end

	-- ─── 2. Supprimer les tools du backpack/personnage du joueur ──────────────
	-- (spawner tools, egg tools, brainrot tools — les données seront réinitialisées
	--  mais les objets Roblox dans le backpack persistent sans ce nettoyage)
	--
	-- Cas spawner template : GiveSpawnerTool clone le template Studio et nomme
	-- l'outil par la rareté ("Common", "Rare"...) SANS ajouter SpawnerRarity.
	-- La vérification par nom couvre ce cas.
	local SPAWNER_RARITY_NAMES = {
		Common = true, Uncommon = true, Rare = true, Epic = true, Legendary = true
	}

	if player then
		local function clearTools(container)
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") then
					local name = tool.Name
					if tool:GetAttribute("SpawnerRarity")
					   or tool:GetAttribute("BrainrotName")
					   or SPAWNER_RARITY_NAMES[name]
					   or name:match("^Oeuf_")
					   or name:match("^Brainrot_") then
						tool:Destroy()
					end
				end
			end
		end
		clearTools(player.Backpack)
		if player.Character then
			clearTools(player.Character)
		end
	end

	-- ─── 3. Réinitialiser la progression ─────────────────────────────────────
	playerData.money              = 0
	playerData.level              = 1
	playerData.exp                = 0
	playerData.inventory          = { Common = 0, Uncommon = 0, Rare = 0, Epic = 0, Legendary = 0 }
	playerData.generatorInventory = {}
	playerData.brainrotInventory  = {}
	playerData.placedSpawners     = {}
	playerData.quotaProgress      = {}
	-- placedGenerators est CONSERVÉ (brainrots sur les socles)

	-- ─── 4. Incrémenter le prestige ───────────────────────────────────────────
	if isMasterRequest then
		playerData.isMasterPrestige = true
		-- Note : le level cap est levé — géré par LevelService qui vérifie isMasterPrestige
	else
		playerData.prestigeLevel = playerData.prestigeLevel + 1
	end

	-- ─── 4.5 Débloquer un étage si le nouveau prestige le permet ─────────────
	if not isMasterRequest and _FloorService and FloorConfig then
		local newPrestige = playerData.prestigeLevel
		if FloorConfig.Floors[newPrestige] then
			task.spawn(function()
				_FloorService.UnlockFloor(userId, newPrestige)
			end)
		end
	end

	-- ─── 5. Sauvegarder ──────────────────────────────────────────────────────
	_PlayerDataService.SavePlayer(userId)

	-- ─── 6. Notifier le client (tous les changements d'état) ──────────────────
	if player then
		-- Mettre à jour le HUD argent (reset à 0)
		if _onMoneyChanged then
			_onMoneyChanged:FireClient(player, 0)
		end

		-- Remettre à zéro l'affichage du quota pour chaque rareté
		-- (quotaProgress a été vidé en étape 3 ; sans ce reset, le client
		-- conserverait les anciennes valeurs jusqu'à la prochaine collecte)
		if _onQuotaUpdated and _ToyConfig then
			for rarity, toyData in pairs(_ToyConfig) do
				_onQuotaUpdated:FireClient(player, rarity, 0, toyData.QuotaToGenerator)
			end
		end

		-- Envoyer le nouveau rang de prestige
		if _onPrestigeChanged then
			_onPrestigeChanged:FireClient(
				player,
				playerData.prestigeLevel,
				playerData.isMasterPrestige
			)
		end
		-- Mettre à jour les attributs character (répliqués à tous les clients)
		if player.Character then
			player.Character:SetAttribute("PlayerPrestige", playerData.prestigeLevel)
			player.Character:SetAttribute("PlayerIsMaster",  playerData.isMasterPrestige)
		end

		-- Toast de félicitations
		if _onNotification then
			local msg = isMasterRequest
				and "✦ Félicitations ! Tu es maintenant Maître Prestige ! Les niveaux sont désormais illimités."
				or  string.format("⭐ Prestige %d atteint ! Ta progression a été réinitialisée.", playerData.prestigeLevel)
			_onNotification:FireClient(player, msg, "SUCCESS")
		end
	end

	print(string.format(
		"[PrestigeService] Joueur %d → Prestige %d | MasterPrestige: %s",
		userId, playerData.prestigeLevel, tostring(playerData.isMasterPrestige)
	))

	return true, "Prestige réussi !"
end

-- Envoie les données de prestige initiales au client lors de la connexion
-- @param userId: number
function PrestigeService.SendInitialData(userId)
	if not _PlayerDataService then return end
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return end

	local player = game.Players:GetPlayerByUserId(userId)
	if not (player and _onPrestigeChanged) then return end

	_onPrestigeChanged:FireClient(
		player,
		playerData.prestigeLevel,
		playerData.isMasterPrestige
	)
	-- Attributs character pour les billboards visibles par tous
	if player.Character then
		player.Character:SetAttribute("PlayerPrestige", playerData.prestigeLevel)
		player.Character:SetAttribute("PlayerIsMaster",  playerData.isMasterPrestige)
	end
end

return PrestigeService
