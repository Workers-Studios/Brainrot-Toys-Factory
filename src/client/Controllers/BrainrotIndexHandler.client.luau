--[[
	BrainrotIndexHandler - GUI Index + Inventaire des Brainrots

	Ouverture Index    : HUD → Background → MenuIcon → Index → Button
	Ouverture Inventaire : bouton haut-gauche (sous les boutons Roblox/music)
	4 onglets : Normal | Gold | Diamond | Inventaire
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ─── Configs ─────────────────────────────────────────────────────────────────
local BrainrotConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotConfig"))
local VariantConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VariantConfig"))

local RARITY_ORDER  = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local RARITY_COLORS = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(30,  200, 30),
	Rare      = Color3.fromRGB(0,   120, 255),
	Epic      = Color3.fromRGB(160, 0,   200),
	Legendary = Color3.fromRGB(255, 200, 0),
}

local TABS = { "Normal", "Gold", "Diamond" }
local TAB_COLORS = {
	Normal  = Color3.fromRGB(200, 200, 200),
	Gold    = Color3.fromRGB(255, 200, 0),
	Diamond = Color3.fromRGB(100, 220, 255),
}

-- ─── Remote ──────────────────────────────────────────────────────────────────
local RemoteInterface   = ReplicatedStorage:WaitForChild("RemoteInterface")
local RequestPlayerData = RemoteInterface:WaitForChild("Functions"):WaitForChild("RequestPlayerData")

-- ─── Bouton Index dans le HUD (même pattern que ShopUIHandler) ───────────────
local HUD        = PlayerGui:WaitForChild("HUD")
local Background = HUD:WaitForChild("Background")
local MenuIcon   = Background:WaitForChild("MenuIcon")
local IndexFrame = MenuIcon:WaitForChild("Index")
local hudButton  = IndexFrame:WaitForChild("Button")

-- ─── Construction du panneau principal ───────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "BrainrotIndexUI"
screenGui.ResetOnSpawn   = false
screenGui.DisplayOrder   = 50
screenGui.IgnoreGuiInset = true
screenGui.Enabled        = false
screenGui.Parent         = PlayerGui

-- Fond semi-transparent
local backdrop = Instance.new("Frame")
backdrop.Size                   = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.BorderSizePixel        = 0
backdrop.Parent                 = screenGui

-- Panneau central
local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.Size             = UDim2.new(0, 680, 0, 520)
panel.Position         = UDim2.new(0.5, 0, 0.5, 0)
panel.AnchorPoint      = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
panel.BorderSizePixel  = 0
panel.Parent           = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

-- Titre
local title = Instance.new("TextLabel")
title.Size                   = UDim2.new(1, -50, 0, 40)
title.Position               = UDim2.new(0, 16, 0, 10)
title.BackgroundTransparency = 1
title.Text                   = "Index des Brainrots"
title.TextColor3             = Color3.fromRGB(255, 255, 255)
title.Font                   = Enum.Font.GothamBold
title.TextSize               = 20
title.TextXAlignment         = Enum.TextXAlignment.Left
title.Parent                 = panel

-- Compteur
local counterLabel = Instance.new("TextLabel")
counterLabel.Size                   = UDim2.new(0, 250, 0, 20)
counterLabel.Position               = UDim2.new(0, 16, 0, 48)
counterLabel.BackgroundTransparency = 1
counterLabel.Text                   = "0 / 46 découverts"
counterLabel.TextColor3             = Color3.fromRGB(150, 150, 150)
counterLabel.Font                   = Enum.Font.Gotham
counterLabel.TextSize               = 13
counterLabel.TextXAlignment         = Enum.TextXAlignment.Left
counterLabel.Parent                 = panel

-- Bouton fermer
local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 32, 0, 32)
closeBtn.Position         = UDim2.new(1, -44, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
closeBtn.BorderSizePixel  = 0
closeBtn.Text             = "✕"
closeBtn.TextColor3       = Color3.fromRGB(255, 100, 100)
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 16
closeBtn.Parent           = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- ─── Onglets ─────────────────────────────────────────────────────────────────
local tabBar = Instance.new("Frame")
tabBar.Size                   = UDim2.new(1, -32, 0, 36)
tabBar.Position               = UDim2.new(0, 16, 0, 74)
tabBar.BackgroundTransparency = 1
tabBar.Parent                 = panel

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding       = UDim.new(0, 6)
tabLayout.Parent        = tabBar

local tabButtons = {}
for _, tabName in ipairs(TABS) do
	local btn = Instance.new("TextButton")
	btn.Name             = tabName
	btn.Size             = UDim2.new(0, 100, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	btn.BorderSizePixel  = 0
	btn.Text             = tabName
	btn.TextColor3       = TAB_COLORS[tabName]
	btn.Font             = Enum.Font.GothamBold
	btn.TextSize         = 13
	btn.Parent           = tabBar
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	tabButtons[tabName] = btn
end

-- ─── Zone de grille ──────────────────────────────────────────────────────────
local gridFrame = Instance.new("ScrollingFrame")
gridFrame.Size                   = UDim2.new(1, -32, 1, -128)
gridFrame.Position               = UDim2.new(0, 16, 0, 118)
gridFrame.BackgroundTransparency = 1
gridFrame.ScrollBarThickness     = 4
gridFrame.ScrollBarImageColor3   = Color3.fromRGB(80, 80, 100)
gridFrame.BorderSizePixel        = 0
gridFrame.Parent                 = panel

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize    = UDim2.new(0, 148, 0, 80)
gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
gridLayout.Parent      = gridFrame

-- ─── Données ─────────────────────────────────────────────────────────────────
local _discovered = { Normal = {}, Gold = {}, Diamond = {} }
local _currentTab = "Normal"

local function isDiscovered(name, variant)
	for _, n in ipairs(_discovered[variant] or {}) do
		if n == name then return true end
	end
	return false
end

-- ─── Construction des cartes ─────────────────────────────────────────────────
local function makeCard(parent, nameText, rarityText, revenueText, rarity, discovered)
	local card = Instance.new("Frame")
	card.BackgroundColor3       = discovered
		and Color3.fromRGB(28, 28, 40)
		or  Color3.fromRGB(20, 20, 28)
	card.BackgroundTransparency = discovered and 0 or 0.3
	card.BorderSizePixel        = 0
	card.Parent                 = parent
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

	if discovered and rarity then
		local stroke = Instance.new("UIStroke")
		stroke.Color     = RARITY_COLORS[rarity] or Color3.fromRGB(100, 100, 100)
		stroke.Thickness = 1.5
		stroke.Parent    = card
	end

	local function lbl(text, color, y, h, bold)
		local l = Instance.new("TextLabel")
		l.Size                   = UDim2.new(1, -8, 0, h)
		l.Position               = UDim2.new(0, 4, 0, y)
		l.BackgroundTransparency = 1
		l.Text                   = text
		l.TextColor3             = color
		l.Font                   = bold and Enum.Font.GothamBold or Enum.Font.Gotham
		l.TextSize               = bold and 11 or 10
		l.TextWrapped            = true
		l.TextXAlignment         = Enum.TextXAlignment.Center
		l.Parent                 = card
	end

	local dim = Color3.fromRGB(70, 70, 70)
	lbl(nameText,    discovered and (RARITY_COLORS[rarity] or Color3.fromRGB(200,200,200)) or dim, 4,  28, true)
	lbl(rarityText,  discovered and (RARITY_COLORS[rarity] or Color3.fromRGB(150,150,150)) or dim, 34, 18, false)
	lbl(revenueText, discovered and Color3.fromRGB(80, 220, 120) or dim,                           54, 18, true)
end

local function buildGrid(tab)
	for _, child in ipairs(gridFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local total, found = 0, 0
	for _, rarity in ipairs(RARITY_ORDER) do
		for name, cfg in pairs(BrainrotConfig[rarity] or {}) do
			total += 1
			local discovered = isDiscovered(name, tab)
			if discovered then found += 1 end

			local mult    = VariantConfig.RevenueMultiplier[tab] or 1
			local revenue = math.floor((cfg.RevenuePerSecond or 0) * mult)

			makeCard(gridFrame,
				discovered and name   or "???",
				discovered and rarity or "???",
				discovered and ("$" .. revenue .. "/s") or "???",
				rarity,
				discovered
			)
		end
	end

	local totalAll = 0
	for _, r in ipairs(RARITY_ORDER) do
		for _ in pairs(BrainrotConfig[r] or {}) do totalAll += 1 end
	end
	counterLabel.Text = #(_discovered.Normal or {}) .. " / " .. totalAll .. " découverts"

	local cols = math.max(math.floor(gridFrame.AbsoluteSize.X / (148 + 8)), 1)
	local rows = math.ceil(total / cols)
	gridFrame.CanvasSize = UDim2.new(0, 0, 0, rows * (80 + 8) + 8)
end

-- ─── Sélection d'onglet ───────────────────────────────────────────────────────
local function selectTab(tabName)
	_currentTab = tabName
	for _, t in ipairs(TABS) do
		local btn = tabButtons[t]
		btn.BackgroundColor3 = (t == tabName)
			and Color3.fromRGB(50, 50, 70)
			or  Color3.fromRGB(35, 35, 45)
		btn.TextSize = (t == tabName) and 14 or 13
	end
	buildGrid(tabName)
end

for _, tabName in ipairs(TABS) do
	tabButtons[tabName].MouseButton1Click:Connect(function()
		selectTab(tabName)
	end)
end

-- ─── Ouverture / Fermeture ────────────────────────────────────────────────────
local function openPanel()
	local data = RequestPlayerData:InvokeServer()
	if data and data.discoveredBrainrots then
		_discovered = {
			Normal  = data.discoveredBrainrots.Normal  or {},
			Gold    = data.discoveredBrainrots.Gold    or {},
			Diamond = data.discoveredBrainrots.Diamond or {},
		}
	end
	screenGui.Enabled = true
	selectTab(_currentTab)
end

local function closePanel()
	screenGui.Enabled = false
end

hudButton.MouseButton1Click:Connect(openPanel)
closeBtn.MouseButton1Click:Connect(closePanel)
backdrop.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		closePanel()
	end
end)
