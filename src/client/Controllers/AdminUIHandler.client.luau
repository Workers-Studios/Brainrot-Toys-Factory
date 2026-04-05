--[[
	Client-side admin UI handler
	Manages admin panel visibility and command execution
	Only visible to authorized admins

	Layout (640 × 570) :
	  ┌──────────────────────────────────────────────────────┐
	  │  ADMIN PANEL                                      [X] │
	  │  Player:  [__________________________]               │
	  │           suggestions                                 │
	  │  Amount:  [__________________________]               │
	  │           [Give Money]      [Set Money]              │
	  │  ────────────────────────────────────────────────── │
	  │  Spawner                  │  Brainrot                │
	  │  [C][U][R][E][L]          │  [C][U][R][E][L]        │
	  │  [🎁 Give Spawner       ] │  [🧠 Give Brainrot    ]  │
	  │  ────────────────────────────────────────────────── │
	  │  Progression                                         │
	  │  [Add EXP]   [Set Level]   [Set Prestige]           │
	  └──────────────────────────────────────────────────────┘
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player            = Players.LocalPlayer

local remoteInterface      = ReplicatedStorage:WaitForChild("RemoteInterface")
local adminFolder          = remoteInterface:WaitForChild("Admin")
local isAdminRemote        = adminFolder:WaitForChild("IsAdmin")
local executeCommandRemote = adminFolder:WaitForChild("ExecuteCommand")

if not isAdminRemote:InvokeServer() then
	print("Not admin, AdminUI disabled")
	return
end

local playerGui = player:WaitForChild("PlayerGui")

-- ─── Constantes de mise en page ───────────────────────────────────────────────
local PW   = 640   -- panel width
local PAD  = 12    -- padding latéral
local IW   = PW - PAD * 2          -- inner width = 616
local COLW = math.floor((IW - 16) / 2)  -- colonne = 300  (gap 16 entre les deux)
local LCOL = PAD                    -- colonne gauche X = 12
local RCOL = PAD + COLW + 16        -- colonne droite  X = 328

local RARITY_COLORS_UI = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(30,  200, 30),
	Rare      = Color3.fromRGB(30,  120, 255),
	Epic      = Color3.fromRGB(160, 60,  200),
	Legendary = Color3.fromRGB(255, 200, 0),
}
local RARITY_DIM = {
	Common    = Color3.fromRGB(60, 60, 60),
	Uncommon  = Color3.fromRGB(20, 70, 20),
	Rare      = Color3.fromRGB(20, 40, 90),
	Epic      = Color3.fromRGB(60, 20, 80),
	Legendary = Color3.fromRGB(80, 60, 10),
}
local RARITIES = {"Common", "Uncommon", "Rare", "Epic", "Legendary"}

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
end

local function label(parent, x, y, w, h, text, size, color, bold, alignX)
	local l = Instance.new("TextLabel")
	l.Size                   = UDim2.new(0, w, 0, h)
	l.Position               = UDim2.new(0, x, 0, y)
	l.BackgroundTransparency = 1
	l.Text                   = text
	l.TextSize               = size or 14
	l.Font                   = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextColor3             = color or Color3.fromRGB(255,255,255)
	l.TextXAlignment         = alignX or Enum.TextXAlignment.Left
	l.Parent                 = parent
	return l
end

local function separator(parent, y)
	local s = Instance.new("Frame")
	s.Size            = UDim2.new(0, IW, 0, 1)
	s.Position        = UDim2.new(0, PAD, 0, y)
	s.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	s.BorderSizePixel = 0
	s.Parent          = parent
end

local function button(parent, x, y, w, h, text, bg, textSize)
	local b = Instance.new("TextButton")
	b.Size             = UDim2.new(0, w, 0, h)
	b.Position         = UDim2.new(0, x, 0, y)
	b.BackgroundColor3 = bg or Color3.fromRGB(60, 60, 60)
	b.TextColor3       = Color3.fromRGB(255, 255, 255)
	b.Text             = text
	b.Font             = Enum.Font.GothamBold
	b.TextSize         = textSize or 13
	b.Parent           = parent
	corner(b)
	return b
end

-- ─── ScreenGui + AdminButton ──────────────────────────────────────────────────
local adminUI       = Instance.new("ScreenGui")
adminUI.Name        = "AdminUI"
adminUI.ResetOnSpawn = false
adminUI.IgnoreGuiInset = true
adminUI.Parent      = playerGui

local adminButton   = Instance.new("ImageButton")
adminButton.Name    = "AdminButton"
adminButton.Size    = UDim2.new(0, 44, 0, 44)
adminButton.Position = UDim2.new(0, 172, 0, 12)
adminButton.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
adminButton.BorderSizePixel  = 0
adminButton.Image   = ""
adminButton.Parent  = adminUI
corner(adminButton, 22)

local al = Instance.new("TextLabel")
al.Size = UDim2.new(1,0,1,0); al.BackgroundTransparency=1
al.Text = "AD"; al.Font = Enum.Font.GothamBold; al.TextSize=18
al.TextColor3=Color3.fromRGB(255,255,255); al.Parent=adminButton

adminButton.MouseEnter:Connect(function()  adminButton.BackgroundColor3=Color3.fromRGB(51,59,68) end)
adminButton.MouseLeave:Connect(function() adminButton.BackgroundColor3=Color3.fromRGB(26,31,36) end)

-- ─── Panel principal ──────────────────────────────────────────────────────────
local adminPanel = Instance.new("Frame")
adminPanel.Name   = "AdminPanel"
adminPanel.Size   = UDim2.new(0, PW, 0, 570)
adminPanel.Position = UDim2.new(0.5, -PW/2, 0.5, -285)
adminPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
adminPanel.Visible = false
adminPanel.Parent  = adminUI
corner(adminPanel, 12)

-- Titre + Fermer
label(adminPanel, PAD, 10, IW-30, 40, "ADMIN PANEL", 20, Color3.fromRGB(255,255,255), true)

local closeBtn = button(adminPanel, PW-42, 10, 30, 30, "X", Color3.fromRGB(200,50,50), 18)

-- ─── Recherche joueur ─────────────────────────────────────────────────────────
label(adminPanel, PAD, 60, IW, 20, "Player Name:", 14, Color3.fromRGB(200,200,200))

local playerSearch = Instance.new("TextBox")
playerSearch.Name   = "PlayerSearch"
playerSearch.Size   = UDim2.new(0, IW, 0, 35)
playerSearch.Position = UDim2.new(0, PAD, 0, 85)
playerSearch.BackgroundColor3 = Color3.fromRGB(50,50,50)
playerSearch.TextColor3 = Color3.fromRGB(255,255,255)
playerSearch.PlaceholderText = "Type player name..."
playerSearch.Text   = ""
playerSearch.Font   = Enum.Font.Gotham
playerSearch.TextSize = 14
playerSearch.ClearTextOnFocus = false
playerSearch.Parent = adminPanel
corner(playerSearch)

local suggestionsList = Instance.new("ScrollingFrame")
suggestionsList.Name  = "SuggestionsList"
suggestionsList.Size  = UDim2.new(0, IW, 0, 90)
suggestionsList.Position = UDim2.new(0, PAD, 0, 125)
suggestionsList.BackgroundColor3 = Color3.fromRGB(40,40,40)
suggestionsList.ScrollBarThickness = 4
suggestionsList.Visible = false
suggestionsList.Parent  = adminPanel
corner(suggestionsList)
local sugLayout = Instance.new("UIListLayout")
sugLayout.SortOrder = Enum.SortOrder.Name
sugLayout.Padding   = UDim.new(0,2)
sugLayout.Parent    = suggestionsList

-- ─── Champ Amount ─────────────────────────────────────────────────────────────
label(adminPanel, PAD, 225, IW, 20, "Amount:", 14, Color3.fromRGB(200,200,200))

local amountInput = Instance.new("TextBox")
amountInput.Name  = "AmountInput"
amountInput.Size  = UDim2.new(0, IW, 0, 35)
amountInput.Position = UDim2.new(0, PAD, 0, 250)
amountInput.BackgroundColor3 = Color3.fromRGB(50,50,50)
amountInput.TextColor3 = Color3.fromRGB(255,255,255)
amountInput.PlaceholderText = "Enter amount..."
amountInput.Text  = ""
amountInput.Font  = Enum.Font.Gotham
amountInput.TextSize = 14
amountInput.Parent = adminPanel
corner(amountInput)

-- ─── Boutons Money ────────────────────────────────────────────────────────────
local HALF = math.floor((IW - 8) / 2)   -- 304
local giveMoneyBtn = button(adminPanel, PAD,         300, HALF, 36, "Give Money", Color3.fromRGB(50,150,50))
local setMoneyBtn  = button(adminPanel, PAD+HALF+8,  300, HALF, 36, "Set Money",  Color3.fromRGB(50,100,200))

-- ─── Séparateur ───────────────────────────────────────────────────────────────
separator(adminPanel, 348)

-- ─── Spawner (colonne gauche) + Brainrot (colonne droite) ─────────────────────
-- Titres des colonnes
label(adminPanel, LCOL, 356, COLW, 20, "Spawner",  14, Color3.fromRGB(200,160,255), true)
label(adminPanel, RCOL, 356, COLW, 20, "Brainrot", 14, Color3.fromRGB(255,160,60),  true)

-- Boutons de rareté : 5 par colonne
local RBTN_W  = math.floor((COLW - 4*3) / 5)   -- ~57px
local RBTN_ST = RBTN_W + 3                       -- stride = 60

local spawnerRarityBtns  = {}
local brainrotRarityBtns = {}
local selectedSpawnerRarity  = "Common"
local selectedBrainrotRarity = "Common"

for i, rar in ipairs(RARITIES) do
	local ox = (i-1) * RBTN_ST  -- offset within column

	local sb = button(adminPanel, LCOL + ox, 380, RBTN_W, 30, rar, RARITY_DIM[rar], 10)
	spawnerRarityBtns[rar] = sb

	local bb = button(adminPanel, RCOL + ox, 380, RBTN_W, 30, rar, RARITY_DIM[rar], 10)
	brainrotRarityBtns[rar] = bb
end

local giveSpawnerBtn  = button(adminPanel, LCOL, 416, COLW, 36, "🎁 Give Spawner", Color3.fromRGB(120,50,180), 14)
local giveBrainrotBtn = button(adminPanel, RCOL, 416, COLW, 36, "🧠 Give Brainrot", Color3.fromRGB(180,100,20), 14)

-- ─── Séparateur ───────────────────────────────────────────────────────────────
separator(adminPanel, 464)

-- ─── Progression ──────────────────────────────────────────────────────────────
label(adminPanel, PAD, 472, IW, 20, "Progression", 14, Color3.fromRGB(180,180,255), true)

local PBTN_W = math.floor((IW - 2*8) / 3)   -- ~200px
local addExpBtn      = button(adminPanel, PAD,              496, PBTN_W, 36, "Add EXP",     Color3.fromRGB(30,140,80))
local setLevelBtn    = button(adminPanel, PAD+PBTN_W+8,     496, PBTN_W, 36, "Set Level",   Color3.fromRGB(30,80,160))
local setPrestigeBtn = button(adminPanel, PAD+(PBTN_W+8)*2, 496, PBTN_W, 36, "Set Prestige",Color3.fromRGB(120,30,160))

label(adminPanel, PAD, 542, IW, 18,
	"Amount = EXP / Level / Prestige   •   Rarity = Rareté Spawner / Brainrot",
	10, Color3.fromRGB(140,140,140))

-- ─── État local ───────────────────────────────────────────────────────────────
local selectedPlayer = nil

local function updateSpawnerRarity(r)
	selectedSpawnerRarity = r
	for k, btn in pairs(spawnerRarityBtns) do
		btn.BackgroundColor3 = (k == r) and RARITY_COLORS_UI[k] or RARITY_DIM[k]
	end
end

local function updateBrainrotRarity(r)
	selectedBrainrotRarity = r
	for k, btn in pairs(brainrotRarityBtns) do
		btn.BackgroundColor3 = (k == r) and RARITY_COLORS_UI[k] or RARITY_DIM[k]
	end
end

updateSpawnerRarity("Common")
updateBrainrotRarity("Common")

local function updateSuggestions(searchText)
	for _, c in ipairs(suggestionsList:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	if searchText == "" then suggestionsList.Visible = false return end

	local matches = {}
	local low = searchText:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(low, 1, true) then table.insert(matches, p.Name) end
	end
	if #matches == 0 then suggestionsList.Visible = false return end

	for _, pname in ipairs(matches) do
		local b = Instance.new("TextButton")
		b.Name = pname
		b.Size = UDim2.new(1,-8,0,30)
		b.BackgroundColor3 = Color3.fromRGB(50,50,50)
		b.TextColor3 = Color3.fromRGB(255,255,255)
		b.Text = pname; b.Font = Enum.Font.Gotham; b.TextSize = 13
		b.Parent = suggestionsList
		corner(b, 4)
		b.MouseButton1Click:Connect(function()
			playerSearch.Text = pname
			selectedPlayer = pname
			suggestionsList.Visible = false
		end)
	end
	suggestionsList.CanvasSize = UDim2.new(0,0,0,#matches*32)
	suggestionsList.Visible = true
end

-- ─── Events ───────────────────────────────────────────────────────────────────
adminButton.MouseButton1Click:Connect(function()
	adminPanel.Visible = not adminPanel.Visible
end)
closeBtn.MouseButton1Click:Connect(function()
	adminPanel.Visible = false
end)

playerSearch:GetPropertyChangedSignal("Text"):Connect(function()
	updateSuggestions(playerSearch.Text)
	selectedPlayer = playerSearch.Text
end)

for r, btn in pairs(spawnerRarityBtns) do
	btn.MouseButton1Click:Connect(function() updateSpawnerRarity(r) end)
end
for r, btn in pairs(brainrotRarityBtns) do
	btn.MouseButton1Click:Connect(function() updateBrainrotRarity(r) end)
end

giveMoneyBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer or selectedPlayer=="" then warn("No player selected") return end
	local a = tonumber(amountInput.Text)
	if not a or a<=0 then warn("Invalid amount") return end
	executeCommandRemote:FireServer("GiveMoney", selectedPlayer, a)
end)

setMoneyBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer or selectedPlayer=="" then warn("No player selected") return end
	local a = tonumber(amountInput.Text)
	if not a or a<0 then warn("Invalid amount") return end
	executeCommandRemote:FireServer("SetMoney", selectedPlayer, a)
end)

giveSpawnerBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer or selectedPlayer=="" then warn("No player selected") return end
	executeCommandRemote:FireServer("GiveSpawner", selectedPlayer, selectedSpawnerRarity)
	print("Gave", selectedSpawnerRarity, "spawner to", selectedPlayer)
end)

giveBrainrotBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer or selectedPlayer=="" then warn("No player selected") return end
	executeCommandRemote:FireServer("GiveBrainrot", selectedPlayer, selectedBrainrotRarity)
	print("Gave", selectedBrainrotRarity, "brainrot to", selectedPlayer)
end)

addExpBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer or selectedPlayer=="" then warn("No player selected") return end
	local a = tonumber(amountInput.Text)
	if not a or a<=0 then warn("Invalid amount") return end
	executeCommandRemote:FireServer("AddExp", selectedPlayer, a)
end)

setLevelBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer or selectedPlayer=="" then warn("No player selected") return end
	local l = tonumber(amountInput.Text)
	if not l or l<1 then warn("Invalid level") return end
	executeCommandRemote:FireServer("SetLevel", selectedPlayer, l)
end)

setPrestigeBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer or selectedPlayer=="" then warn("No player selected") return end
	local p = tonumber(amountInput.Text)
	if not p or p<0 then warn("Invalid prestige") return end
	executeCommandRemote:FireServer("SetPrestige", selectedPlayer, p)
end)
