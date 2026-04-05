--[[
	PrestigeUIHandler
	Gère l'ouverture/fermeture de la fenêtre de prestige via le bouton HUD MenuIcon.
	Suit le même pattern que ShopUIHandler / BrainrotIndexHandler.
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

-- ─── Ancien PrestigeFrame : masqué définitivement ─────────────────────────────
local HUD          = PlayerGui:WaitForChild("HUD")
local prestigeFrame = HUD:FindFirstChild("PrestigeFrame")
if prestigeFrame then
	prestigeFrame.Visible = false
end

-- ─── Bouton HUD MenuIcon ──────────────────────────────────────────────────────
local prestigeMenuNode   = HUD
	:WaitForChild("Background")
	:WaitForChild("MenuIcon")
	:WaitForChild("Prestige")

local prestigeButton  = prestigeMenuNode:WaitForChild("Button")
local prestigeCounter = prestigeMenuNode:WaitForChild("PrestigeCounter")

-- Valeur initiale à 0
prestigeCounter.Text = prestigeCounter.Text:gsub("%[%d+%]", "[0]")

-- ─── Fenêtre Prestige (ScreenGui) ─────────────────────────────────────────────
local prestigeUI = Instance.new("ScreenGui")
prestigeUI.Name           = "PrestigeUI"
prestigeUI.ResetOnSpawn   = false
prestigeUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
prestigeUI.DisplayOrder   = 50
prestigeUI.Enabled        = false
prestigeUI.Parent         = PlayerGui

-- Fond semi-transparent
local backdrop = Instance.new("Frame")
backdrop.Name                  = "Backdrop"
backdrop.Size                  = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.BorderSizePixel       = 0
backdrop.Parent                = prestigeUI

-- Panneau central
local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.Size             = UDim2.fromOffset(420, 240)
panel.AnchorPoint      = Vector2.new(0.5, 0.5)
panel.Position         = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
panel.BorderSizePixel  = 0
panel.Parent           = backdrop
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke", panel)
stroke.Color     = Color3.fromRGB(255, 200, 50)
stroke.Thickness = 2

-- Titre
local title = Instance.new("TextLabel")
title.Name                   = "Title"
title.Size                   = UDim2.new(1, -20, 0, 50)
title.Position               = UDim2.new(0, 10, 0, 14)
title.BackgroundTransparency = 1
title.Text                   = "⭐ Passer au Prestige"
title.TextColor3             = Color3.fromRGB(255, 200, 50)
title.TextScaled             = true
title.Font                   = Enum.Font.GothamBold
title.Parent                 = panel

-- Description
local desc = Instance.new("TextLabel")
desc.Name                   = "Desc"
desc.Size                   = UDim2.new(1, -40, 0, 60)
desc.Position               = UDim2.new(0, 20, 0, 70)
desc.BackgroundTransparency = 1
desc.Text                   = "Toute ta progression sera réinitialisée.\nCette action est irréversible."
desc.TextColor3             = Color3.fromRGB(200, 200, 200)
desc.TextScaled             = true
desc.Font                   = Enum.Font.Gotham
desc.TextXAlignment         = Enum.TextXAlignment.Center
desc.Parent                 = panel

-- Bouton Confirmer
local btnOui = Instance.new("TextButton")
btnOui.Name             = "BtnOui"
btnOui.Size             = UDim2.fromOffset(150, 48)
btnOui.Position         = UDim2.new(0.5, -165, 1, -68)
btnOui.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
btnOui.Text             = "✔  Confirmer"
btnOui.TextColor3       = Color3.fromRGB(255, 255, 255)
btnOui.TextScaled       = true
btnOui.Font             = Enum.Font.GothamBold
btnOui.Parent           = panel
Instance.new("UICorner", btnOui).CornerRadius = UDim.new(0, 8)

-- Bouton Annuler
local btnNon = Instance.new("TextButton")
btnNon.Name             = "BtnNon"
btnNon.Size             = UDim2.fromOffset(150, 48)
btnNon.Position         = UDim2.new(0.5, 15, 1, -68)
btnNon.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
btnNon.Text             = "✘  Annuler"
btnNon.TextColor3       = Color3.fromRGB(255, 255, 255)
btnNon.TextScaled       = true
btnNon.Font             = Enum.Font.GothamBold
btnNon.Parent           = panel
Instance.new("UICorner", btnNon).CornerRadius = UDim.new(0, 8)

-- ─── État local ───────────────────────────────────────────────────────────────
local currentPrestige  = 0
local isRequestPending = false

-- ─── Toggle de la fenêtre ─────────────────────────────────────────────────────
local function togglePrestigeUI()
	prestigeUI.Enabled = not prestigeUI.Enabled
end

-- ─── Événements serveur ───────────────────────────────────────────────────────
onPrestigeChanged.OnClientEvent:Connect(function(prestigeLevel, _isMaster)
	currentPrestige = prestigeLevel
	prestigeCounter.Text = prestigeCounter.Text:gsub("%[%d+%]", "[" .. prestigeLevel .. "]")
end)

onLevelChanged.OnClientEvent:Connect(function(_level, _exp, _expForNext)
	-- réservé si besoin futur
end)

-- ─── Connexions boutons ───────────────────────────────────────────────────────
prestigeButton.MouseButton1Click:Connect(togglePrestigeUI)

btnNon.MouseButton1Click:Connect(function()
	prestigeUI.Enabled = false
end)

backdrop.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		prestigeUI.Enabled = false
	end
end)

btnOui.MouseButton1Click:Connect(function()
	if isRequestPending then return end
	isRequestPending = true
	btnOui.Text   = "..."
	btnOui.Active = false

	local success, message = requestPrestige:InvokeServer()

	isRequestPending = false
	btnOui.Text   = "✔  Confirmer"
	btnOui.Active = true

	if success then
		prestigeUI.Enabled = false
	else
		warn("[PrestigeUIHandler] Prestige refusé :", message)
	end
end)
