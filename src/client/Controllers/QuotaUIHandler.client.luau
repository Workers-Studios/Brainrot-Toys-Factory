--[[
	Affichage temporaire du quota par rareté
	UI entièrement créée en code - aucune dépendance Studio

	Structure : panneau fixe à droite
	Pour chaque toyType × rarity : barre de progression + compteur x/max
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local OnQuotaUpdated = ReplicatedStorage
	:WaitForChild("RemoteInterface")
	:WaitForChild("Events")
	:WaitForChild("OnQuotaUpdated")

-- ─── Couleurs par rareté ─────────────────────────────────────────────────────
local RARITY_COLORS = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(30,  200, 30),
	Rare      = Color3.fromRGB(0,   120, 255),
	Epic      = Color3.fromRGB(160, 0,   200),
	Legendary = Color3.fromRGB(255, 200, 0),
}

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- ─── Création de la ScreenGui ─────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QuotaUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Panneau principal
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 220, 0, 40)  -- hauteur minimale, grandit avec le contenu
panel.Position = UDim2.new(1, -230, 0.5, -20)
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
panel.BackgroundTransparency = 0.3
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner", panel)
panelCorner.CornerRadius = UDim.new(0, 8)

local layout = Instance.new("UIListLayout", panel)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)

local padding = Instance.new("UIPadding", panel)
padding.PaddingTop    = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft   = UDim.new(0, 10)
padding.PaddingRight  = UDim.new(0, 10)

-- Titre
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 18)
title.BackgroundTransparency = 1
title.Text = "📊 Quotas"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.LayoutOrder = 0
title.Parent = panel

-- Séparateur
local sep = Instance.new("Frame")
sep.Name = "Separator"
sep.Size = UDim2.new(1, 0, 0, 1)
sep.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
sep.BorderSizePixel = 0
sep.LayoutOrder = 1
sep.Parent = panel

-- ─── Stockage des lignes ──────────────────────────────────────────────────────
-- _rows[rarity] = { bar, counter }
local _rows = {}
local _layoutOrder = 2  -- après titre + séparateur

local function getOrCreateRow(rarity)
	if _rows[rarity] then return _rows[rarity] end

	-- Conteneur de la ligne
	local row = Instance.new("Frame")
	row.Name = "Row_" .. rarity
	row.Size = UDim2.new(1, 0, 0, 20)
	row.BackgroundTransparency = 1
	row.LayoutOrder = _layoutOrder
	row.Parent = panel
	_layoutOrder += 1

	-- Nom de la rareté
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(0, 64, 1, 0)
	rarityLabel.Position = UDim2.new(0, 0, 0, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = rarity
	rarityLabel.TextColor3 = RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
	rarityLabel.TextSize = 11
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.Parent = row

	-- Fond de la barre
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -110, 1, -6)
	barBg.Position = UDim2.new(0, 66, 0.5, 0)
	barBg.AnchorPoint = Vector2.new(0, 0.5)
	barBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	barBg.BorderSizePixel = 0
	barBg.ClipsDescendants = true
	barBg.Parent = row

	local barBgCorner = Instance.new("UICorner", barBg)
	barBgCorner.CornerRadius = UDim.new(0, 3)

	-- Barre de progression
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 1, 0, 1)
	bar.BackgroundColor3 = RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
	bar.BorderSizePixel = 0
	bar.Parent = barBg

	local barCorner = Instance.new("UICorner", bar)
	barCorner.CornerRadius = UDim.new(0, 3)

	-- Compteur x/max
	local counter = Instance.new("TextLabel")
	counter.Size = UDim2.new(0, 40, 1, 0)
	counter.Position = UDim2.new(1, -42, 0, 0)
	counter.BackgroundTransparency = 1
	counter.Text = "0/?"
	counter.TextColor3 = Color3.fromRGB(220, 220, 220)
	counter.TextSize = 10
	counter.Font = Enum.Font.Gotham
	counter.TextXAlignment = Enum.TextXAlignment.Right
	counter.Parent = row

	_rows[rarity] = { bar = bar, counter = counter }
	return _rows[rarity]
end

-- ─── Mise à jour auto de la hauteur du panneau ────────────────────────────────
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	panel.Size = UDim2.new(
		0, 220,
		0, layout.AbsoluteContentSize.Y + 16  -- 16 = padding top+bottom
	)
end)

-- ─── Réception des mises à jour serveur ──────────────────────────────────────
-- Signature : (rarity, current, max)
OnQuotaUpdated.OnClientEvent:Connect(function(rarity, current, max)
	local row = getOrCreateRow(rarity)

	row.counter.Text = current .. "/" .. max

	local pct = (max > 0) and math.clamp(current / max, 0, 1) or 0
	row.bar.Size = UDim2.new(pct, 0, 1, 0)
end)
