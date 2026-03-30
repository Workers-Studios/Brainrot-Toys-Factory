--[[
	PrestigeUIHandler - Affichage du badge de prestige et bouton de prestige

	Écoute l'événement OnPrestigeChanged (server → client) et met à jour :
	  1. Le badge de prestige visible (rang + couleur)
	  2. Le bouton "Passer Prestige" (activé/désactivé selon les conditions)

	Quand le joueur clique sur "Passer Prestige", une confirmation apparaît
	puis la RemoteFunction RequestPrestige est invoquée.

	Structure UI attendue dans StarterGui :
	  HUD
	  └── PrestigeFrame
	      ├── BadgeLabel    (TextLabel  → "Prestige V" ou "✦ Maître Prestige")
	      └── PrestigeButton (TextButton → "Passer Prestige")

	Le PrestigeButton est rendu visible uniquement si le joueur est à niveau 50
	(vérifié localement via LevelFrame pour éviter un appel réseau superflu).
	La validation réelle se fait toujours côté serveur.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ─── Modules partagés ─────────────────────────────────────────────────────────
local PrestigeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PrestigeConfig"))

-- ─── Remotes ──────────────────────────────────────────────────────────────────
local RemoteInterface   = ReplicatedStorage:WaitForChild("RemoteInterface")
local onPrestigeChanged = RemoteInterface:WaitForChild("Events"):WaitForChild("OnPrestigeChanged")
local onLevelChanged    = RemoteInterface:WaitForChild("Events"):WaitForChild("OnLevelChanged")
local requestPrestige   = RemoteInterface:WaitForChild("Functions"):WaitForChild("RequestPrestige")

-- ─── Référence à l'UI ─────────────────────────────────────────────────────────
local HUD            = PlayerGui:WaitForChild("HUD", 10)
local PrestigeFrame  = HUD and HUD:FindFirstChild("PrestigeFrame")
local BadgeLabel     = PrestigeFrame and PrestigeFrame:FindFirstChild("BadgeLabel")
local PrestigeButton = PrestigeFrame and PrestigeFrame:FindFirstChild("PrestigeButton")

-- ─── État local ───────────────────────────────────────────────────────────────
local currentPrestige    = 0
local currentIsMaster    = false
local currentLevel       = 1
local isRequestPending   = false  -- empêche le double-clic

-- ─── Mise à jour du badge ────────────────────────────────────────────────────
local function updateBadge(prestigeLevel, isMasterPrestige)
	if not PrestigeFrame then return end

	-- Index badge : 0 = aucun, 1-10 = Prestige, 11 = Maître Prestige
	local badgeIndex = isMasterPrestige and 11 or prestigeLevel
	local badgeName  = PrestigeConfig.BadgeNames[badgeIndex] or ""
	local badgeColor = PrestigeConfig.BadgeColors[badgeIndex]

	if BadgeLabel then
		BadgeLabel.Text    = badgeName ~= "" and badgeName or "Sans Prestige"
		if badgeColor then
			BadgeLabel.TextColor3 = badgeColor
		end
		BadgeLabel.Visible = (badgeName ~= "")
	end
end

-- ─── Mise à jour de la visibilité du bouton Prestige ─────────────────────────
local function updatePrestigeButton()
	if not PrestigeButton then return end

	-- Le bouton n'est jamais visible si déjà Maître Prestige
	if currentIsMaster then
		PrestigeButton.Visible = false
		return
	end

	-- Afficher le bouton seulement si le joueur est à niveau 50
	local isMaxLevel = (currentLevel >= PrestigeConfig.MaxLevel)
	PrestigeButton.Visible = isMaxLevel

	if isMaxLevel then
		-- S'assurer que le bouton est bien interactif (Active peut être false après
		-- un prestige réussi où on ne le réactive pas depuis le click handler)
		PrestigeButton.Active = true
		local isMasterRequest = (currentPrestige >= PrestigeConfig.MaxPrestige)
		PrestigeButton.Text = isMasterRequest
			and "✦ Maître Prestige"
			or  string.format("Prestige %d →", currentPrestige + 1)
	end
end

-- ─── Événements serveur ───────────────────────────────────────────────────────

onPrestigeChanged.OnClientEvent:Connect(function(prestigeLevel, isMasterPrestige)
	currentPrestige = prestigeLevel
	currentIsMaster = isMasterPrestige
	updateBadge(prestigeLevel, isMasterPrestige)
	updatePrestigeButton()
end)

onLevelChanged.OnClientEvent:Connect(function(level, _exp, _expForNext)
	currentLevel = level
	updatePrestigeButton()
end)

-- ─── Bouton Prestige ──────────────────────────────────────────────────────────
if PrestigeButton then
	PrestigeButton.MouseButton1Click:Connect(function()
		if isRequestPending then return end

		-- Confirmation simple (peut être remplacée par une vraie fenêtre)
		-- Pour l'instant on envoie directement la demande au serveur
		isRequestPending = true
		PrestigeButton.Text = "..."
		PrestigeButton.Active = false

		local success, message = requestPrestige:InvokeServer()

		isRequestPending = false

		if success then
			-- Cacher immédiatement le bouton : les events onPrestigeChanged et
			-- onLevelChanged (level → 1) arriveront et confirmeront l'état final.
			-- Ne pas appeler updatePrestigeButton() ici car l'état local (currentLevel,
			-- currentPrestige) n'est pas encore mis à jour → affichage incorrect.
			PrestigeButton.Visible = false
		else
			-- En cas d'échec, réactiver le bouton et restaurer le texte
			PrestigeButton.Active = true
			warn("[PrestigeUIHandler] Prestige refusé :", message)
			updatePrestigeButton()
		end
	end)
end
