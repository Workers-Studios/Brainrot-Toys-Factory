--[[
	PrestigeUIHandler - Affichage du badge de prestige et bouton de prestige

	Écoute l'événement OnPrestigeChanged (server → client) et met à jour :
	  1. Le badge de prestige visible (rang + couleur)
	  2. Le bouton "Passer Prestige" (activé/désactivé selon les conditions)

	Quand le joueur clique sur "Passer Prestige", une popup de confirmation
	apparaît ("Êtes-vous sûr ?") puis la RemoteFunction RequestPrestige est
	invoquée si le joueur confirme.

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
local TweenService      = game:GetService("TweenService")

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
local HUD            = PlayerGui:WaitForChild("HUD")
local PrestigeFrame  = HUD:WaitForChild("PrestigeFrame")
local BadgeLabel     = PrestigeFrame:WaitForChild("BadgeLabel")
local PrestigeButton = PrestigeFrame:WaitForChild("PrestigeButton")

-- ─── État local ───────────────────────────────────────────────────────────────
local currentPrestige    = 0
local currentIsMaster    = false
local currentLevel       = 1
local isRequestPending   = false  -- empêche le double-clic

-- ─── Popup de confirmation (créée dynamiquement) ──────────────────────────────
local confirmGui = nil

local function destroyConfirmPopup()
	if confirmGui then
		confirmGui:Destroy()
		confirmGui = nil
	end
end

local function showConfirmPopup(onConfirm)
	-- Évite les doublons
	destroyConfirmPopup()

	-- ScreenGui conteneur
	local sg = Instance.new("ScreenGui")
	sg.Name            = "PrestigeConfirmGui"
	sg.ResetOnSpawn    = false
	sg.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder    = 100
	sg.Parent          = PlayerGui
	confirmGui         = sg

	-- Fond semi-transparent
	local overlay = Instance.new("Frame")
	overlay.Name            = "Overlay"
	overlay.Size            = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.ZIndex          = 10
	overlay.Parent          = sg

	-- Panneau centré
	local panel = Instance.new("Frame")
	panel.Name               = "Panel"
	panel.Size               = UDim2.fromOffset(380, 200)
	panel.AnchorPoint        = Vector2.new(0.5, 0.5)
	panel.Position           = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3   = Color3.fromRGB(30, 30, 40)
	panel.BorderSizePixel    = 0
	panel.ZIndex             = 11
	panel.Parent             = overlay

	-- Coins arrondis
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent       = panel

	-- Bordure colorée
	local stroke = Instance.new("UIStroke")
	stroke.Color     = Color3.fromRGB(255, 200, 50)
	stroke.Thickness = 2
	stroke.Parent    = panel

	-- Titre
	local title = Instance.new("TextLabel")
	title.Name                  = "Title"
	title.Size                  = UDim2.new(1, 0, 0, 50)
	title.Position              = UDim2.fromOffset(0, 16)
	title.BackgroundTransparency = 1
	title.Text                  = "⭐ Passer au Prestige ?"
	title.TextColor3            = Color3.fromRGB(255, 200, 50)
	title.TextScaled            = true
	title.Font                  = Enum.Font.GothamBold
	title.ZIndex                = 12
	title.Parent                = panel

	-- Sous-titre
	local sub = Instance.new("TextLabel")
	sub.Name                  = "Sub"
	sub.Size                  = UDim2.new(1, -40, 0, 50)
	sub.Position              = UDim2.new(0, 20, 0, 68)
	sub.BackgroundTransparency = 1
	sub.Text                  = "Toute ta progression sera réinitialisée.\nCette action est irréversible."
	sub.TextColor3            = Color3.fromRGB(210, 210, 210)
	sub.TextScaled            = true
	sub.Font                  = Enum.Font.Gotham
	sub.ZIndex                = 12
	sub.Parent                = panel

	-- Bouton OUI
	local btnOui = Instance.new("TextButton")
	btnOui.Name               = "BtnOui"
	btnOui.Size               = UDim2.fromOffset(130, 44)
	btnOui.Position           = UDim2.new(0.5, -145, 1, -60)
	btnOui.BackgroundColor3   = Color3.fromRGB(50, 180, 80)
	btnOui.Text               = "✔  Oui"
	btnOui.TextColor3         = Color3.fromRGB(255, 255, 255)
	btnOui.TextScaled         = true
	btnOui.Font               = Enum.Font.GothamBold
	btnOui.ZIndex             = 12
	btnOui.Parent             = panel
	Instance.new("UICorner", btnOui).CornerRadius = UDim.new(0, 8)

	-- Bouton NON
	local btnNon = Instance.new("TextButton")
	btnNon.Name               = "BtnNon"
	btnNon.Size               = UDim2.fromOffset(130, 44)
	btnNon.Position           = UDim2.new(0.5, 15, 1, -60)
	btnNon.BackgroundColor3   = Color3.fromRGB(200, 60, 60)
	btnNon.Text               = "✘  Non"
	btnNon.TextColor3         = Color3.fromRGB(255, 255, 255)
	btnNon.TextScaled         = true
	btnNon.Font               = Enum.Font.GothamBold
	btnNon.ZIndex             = 12
	btnNon.Parent             = panel
	Instance.new("UICorner", btnNon).CornerRadius = UDim.new(0, 8)

	-- Animation d'apparition (scale 0.8 → 1)
	panel.Size = UDim2.fromOffset(380 * 0.8, 200 * 0.8)
	TweenService:Create(panel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(380, 200)
	}):Play()

	-- Connexions
	btnOui.MouseButton1Click:Connect(function()
		destroyConfirmPopup()
		onConfirm()
	end)

	btnNon.MouseButton1Click:Connect(function()
		destroyConfirmPopup()
	end)

	-- Clic sur l'overlay = annuler
	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			destroyConfirmPopup()
		end
	end)
end

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

		-- Afficher la popup de confirmation
		showConfirmPopup(function()
			-- Le joueur a confirmé
			isRequestPending = true
			PrestigeButton.Text   = "..."
			PrestigeButton.Active = false

			local success, message = requestPrestige:InvokeServer()

			isRequestPending = false

			if success then
				-- Cacher immédiatement le bouton : les events onPrestigeChanged et
				-- onLevelChanged (level → 1) arriveront et confirmeront l'état final.
				PrestigeButton.Visible = false
			else
				-- En cas d'échec, réactiver le bouton et restaurer le texte
				PrestigeButton.Active = true
				warn("[PrestigeUIHandler] Prestige refusé :", message)
				updatePrestigeButton()
			end
		end)
	end)
end
