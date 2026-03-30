--[[
	HUDSetup - Crée les éléments de l'interface de progression (Niveau + Prestige)
	Entièrement en code, aucune dépendance Studio.

	Structure créée dans PlayerGui :
	  HUD (ScreenGui)
	  ├── LevelFrame    → attendu par LevelUIHandler
	  │   ├── LevelLabel    (TextLabel  → "Niveau X")
	  │   ├── ExpBar        (Frame      → fond de la barre)
	  │   │   └── Fill      (Frame      → remplissage coloré)
	  │   └── ExpLabel      (TextLabel  → "X / Y EXP" ou "MAX")
	  └── PrestigeFrame → attendu par PrestigeUIHandler
	      ├── BadgeLabel    (TextLabel  → "Prestige I" / "✦ Maître Prestige")
	      └── PrestigeButton (TextButton → "Prestige 2 →" / caché si non éligible)
]]

local Players   = game:GetService("Players")
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── Helper ───────────────────────────────────────────────────────────────────
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
end

-- ─── ScreenGui principale ─────────────────────────────────────────────────────
local hud = Instance.new("ScreenGui")
hud.Name           = "HUD"
hud.ResetOnSpawn   = false
hud.DisplayOrder   = 5
hud.IgnoreGuiInset = true
hud.Parent         = playerGui

-- ─── LevelFrame ──────────────────────────────────────────────────────────────
-- Positionné en haut à gauche, sous l'éventuel HUD de santé Roblox
local levelFrame = Instance.new("Frame")
levelFrame.Name                   = "LevelFrame"
levelFrame.Size                   = UDim2.new(0, 220, 0, 58)
levelFrame.Position               = UDim2.new(0, 10, 0, 10)
levelFrame.BackgroundColor3       = Color3.fromRGB(15, 15, 15)
levelFrame.BackgroundTransparency = 0.25
levelFrame.BorderSizePixel        = 0
levelFrame.Parent                 = hud
corner(levelFrame, 8)

-- "Niveau X"
local levelLabel = Instance.new("TextLabel")
levelLabel.Name                  = "LevelLabel"
levelLabel.Size                  = UDim2.new(1, -12, 0, 20)
levelLabel.Position              = UDim2.new(0, 10, 0, 6)
levelLabel.BackgroundTransparency = 1
levelLabel.Text                  = "Niveau 1"
levelLabel.TextColor3            = Color3.fromRGB(255, 255, 255)
levelLabel.Font                  = Enum.Font.GothamBold
levelLabel.TextSize              = 14
levelLabel.TextXAlignment        = Enum.TextXAlignment.Left
levelLabel.Parent                = levelFrame

-- Fond de la barre EXP
local expBar = Instance.new("Frame")
expBar.Name               = "ExpBar"
expBar.Size               = UDim2.new(1, -12, 0, 10)
expBar.Position           = UDim2.new(0, 6, 0, 30)
expBar.BackgroundColor3   = Color3.fromRGB(50, 50, 50)
expBar.BorderSizePixel    = 0
expBar.ClipsDescendants   = true
expBar.Parent             = levelFrame
corner(expBar, 4)

-- Remplissage de la barre EXP
local expFill = Instance.new("Frame")
expFill.Name             = "Fill"
expFill.Size             = UDim2.new(0, 0, 1, 0)
expFill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
expFill.BorderSizePixel  = 0
expFill.Parent           = expBar
corner(expFill, 4)

-- "X / Y EXP" ou "MAX"
local expLabel = Instance.new("TextLabel")
expLabel.Name                  = "ExpLabel"
expLabel.Size                  = UDim2.new(1, -12, 0, 14)
expLabel.Position              = UDim2.new(0, 6, 0, 42)
expLabel.BackgroundTransparency = 1
expLabel.Text                  = "0 / 303 EXP"
expLabel.TextColor3            = Color3.fromRGB(180, 180, 180)
expLabel.Font                  = Enum.Font.Gotham
expLabel.TextSize              = 11
expLabel.TextXAlignment        = Enum.TextXAlignment.Right
expLabel.Parent                = levelFrame

-- ─── PrestigeFrame ───────────────────────────────────────────────────────────
-- Positionné juste sous LevelFrame (10 + 58 + 6 = 74)
local prestigeFrame = Instance.new("Frame")
prestigeFrame.Name                   = "PrestigeFrame"
prestigeFrame.Size                   = UDim2.new(0, 220, 0, 34)
prestigeFrame.Position               = UDim2.new(0, 10, 0, 74)
prestigeFrame.BackgroundColor3       = Color3.fromRGB(15, 15, 15)
prestigeFrame.BackgroundTransparency = 0.25
prestigeFrame.BorderSizePixel        = 0
prestigeFrame.Parent                 = hud
corner(prestigeFrame, 8)

-- Badge de prestige (caché tant que prestigeLevel = 0)
local badgeLabel = Instance.new("TextLabel")
badgeLabel.Name                  = "BadgeLabel"
badgeLabel.Size                  = UDim2.new(0.55, -4, 1, -8)
badgeLabel.Position              = UDim2.new(0, 8, 0, 4)
badgeLabel.BackgroundTransparency = 1
badgeLabel.Text                  = ""
badgeLabel.TextColor3            = Color3.fromRGB(200, 200, 200)
badgeLabel.Font                  = Enum.Font.GothamBold
badgeLabel.TextSize              = 12
badgeLabel.TextXAlignment        = Enum.TextXAlignment.Left
badgeLabel.Visible               = false
badgeLabel.Parent                = prestigeFrame

-- Bouton Prestige (caché jusqu'au niveau 50)
local prestigeButton = Instance.new("TextButton")
prestigeButton.Name             = "PrestigeButton"
prestigeButton.Size             = UDim2.new(1, -16, 1, -8)
prestigeButton.Position         = UDim2.new(0, 8, 0, 4)
prestigeButton.BackgroundColor3 = Color3.fromRGB(200, 150, 20)
prestigeButton.TextColor3       = Color3.fromRGB(255, 255, 255)
prestigeButton.Font             = Enum.Font.GothamBold
prestigeButton.TextSize         = 12
prestigeButton.Text             = "Prestige 1 →"
prestigeButton.Visible          = false
prestigeButton.AutoButtonColor  = true
prestigeButton.Parent           = prestigeFrame
corner(prestigeButton, 6)
