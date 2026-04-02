--[[
	InventoryButtonHandler
	Recrée le panel inventaire Roblox (backpack) avec barre de recherche.
	Bouton 🎒 en haut-gauche pour ouvrir/fermer.
]]

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local backpack  = player:WaitForChild("Backpack")

-- ─── Couleurs rareté ─────────────────────────────────────────────────────────
local RARITY_COLORS = {
	Common    = Color3.fromRGB(160, 160, 160),
	Uncommon  = Color3.fromRGB(30,  200, 30),
	Rare      = Color3.fromRGB(0,   120, 255),
	Epic      = Color3.fromRGB(160, 0,   200),
	Legendary = Color3.fromRGB(255, 200, 0),
}

local function getToolColor(tool)
	local rarity = tool:GetAttribute("Rarity")
	if rarity and RARITY_COLORS[rarity] then
		return RARITY_COLORS[rarity]
	end
	if tool.Name:match("^Oeuf_") then   return Color3.fromRGB(255, 220, 80) end
	if tool.Name:match("^Brainrot_") then return Color3.fromRGB(100, 200, 255) end
	return Color3.fromRGB(100, 100, 120)
end

local function getDisplayName(tool)
	local name = tool:GetAttribute("BrainrotName") or tool.Name
	name = name:gsub("^Oeuf_", "Oeuf ")
	name = name:gsub("^Brainrot_", "")
	return name
end

-- ─── GUI principal ────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "InventoryUI"
screenGui.ResetOnSpawn   = false
screenGui.DisplayOrder   = 45
screenGui.IgnoreGuiInset = false
screenGui.Enabled        = false
screenGui.Parent         = PlayerGui

-- Fond semi-transparent
local backdrop = Instance.new("Frame")
backdrop.Size                   = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.55
backdrop.BorderSizePixel        = 0
backdrop.Parent                 = screenGui

-- Panneau
local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.Size             = UDim2.new(0, 620, 0, 460)
panel.Position         = UDim2.new(0.5, 0, 0.5, 0)
panel.AnchorPoint      = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
panel.BorderSizePixel  = 0
panel.Parent           = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

-- Titre
local titleLbl = Instance.new("TextLabel")
titleLbl.Size                   = UDim2.new(1, -180, 0, 40)
titleLbl.Position               = UDim2.new(0, 16, 0, 8)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                   = "Inventaire"
titleLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
titleLbl.Font                   = Enum.Font.GothamBold
titleLbl.TextSize               = 18
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.Parent                 = panel

-- Barre de recherche
local searchBox = Instance.new("TextBox")
searchBox.Name                   = "Search"
searchBox.Size                   = UDim2.new(0, 200, 0, 30)
searchBox.Position               = UDim2.new(1, -244, 0, 13)
searchBox.BackgroundColor3       = Color3.fromRGB(30, 30, 42)
searchBox.BorderSizePixel        = 0
searchBox.PlaceholderText        = "🔍 Rechercher..."
searchBox.PlaceholderColor3      = Color3.fromRGB(100, 100, 120)
searchBox.Text                   = ""
searchBox.TextColor3             = Color3.fromRGB(220, 220, 220)
searchBox.Font                   = Enum.Font.Gotham
searchBox.TextSize               = 13
searchBox.ClearTextOnFocus       = false
searchBox.Parent                 = panel
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", searchBox).Color = Color3.fromRGB(60, 60, 90)

-- Bouton fermer
local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 30, 0, 30)
closeBtn.Position         = UDim2.new(1, -42, 0, 13)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
closeBtn.BorderSizePixel  = 0
closeBtn.Text             = "✕"
closeBtn.TextColor3       = Color3.fromRGB(255, 100, 100)
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 14
closeBtn.Parent           = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Compteur d'items
local countLbl = Instance.new("TextLabel")
countLbl.Size                   = UDim2.new(1, -32, 0, 18)
countLbl.Position               = UDim2.new(0, 16, 0, 48)
countLbl.BackgroundTransparency = 1
countLbl.Text                   = "0 objet(s)"
countLbl.TextColor3             = Color3.fromRGB(120, 120, 140)
countLbl.Font                   = Enum.Font.Gotham
countLbl.TextSize               = 12
countLbl.TextXAlignment         = Enum.TextXAlignment.Left
countLbl.Parent                 = panel

-- Zone scrollable
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size                   = UDim2.new(1, -24, 1, -80)
scrollFrame.Position               = UDim2.new(0, 12, 0, 70)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness     = 4
scrollFrame.ScrollBarImageColor3   = Color3.fromRGB(80, 80, 110)
scrollFrame.BorderSizePixel        = 0
scrollFrame.Parent                 = panel

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize    = UDim2.new(0, 90, 0, 100)
gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
gridLayout.Parent      = scrollFrame

local padding = Instance.new("UIPadding")
padding.PaddingTop  = UDim.new(0, 4)
padding.PaddingLeft = UDim.new(0, 4)
padding.Parent      = scrollFrame

-- ─── Construction des slots ───────────────────────────────────────────────────
local _filter = ""

local function buildSlot(tool, equipped)
	local slot = Instance.new("TextButton")
	slot.Name             = tool.Name
	slot.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
	slot.BorderSizePixel  = 0
	slot.Text             = ""
	slot.AutoButtonColor  = false
	slot.Parent           = scrollFrame
	Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 8)

	-- Bordure couleur rareté
	local stroke = Instance.new("UIStroke")
	stroke.Color     = getToolColor(tool)
	stroke.Thickness = equipped and 2.5 or 1.5
	stroke.Parent    = slot

	-- Fond coloré léger
	local colorBg = Instance.new("Frame")
	colorBg.Size                   = UDim2.new(1, 0, 0.55, 0)
	colorBg.BackgroundColor3       = getToolColor(tool)
	colorBg.BackgroundTransparency = 0.82
	colorBg.BorderSizePixel        = 0
	colorBg.Parent                 = slot
	Instance.new("UICorner", colorBg).CornerRadius = UDim.new(0, 8)

	-- Icône de l'outil (si disponible)
	local toolHandle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
	if toolHandle and tool:FindFirstChild("TextureId") then
		-- image custom ignorée, pas disponible facilement
	end

	-- Nom de l'item
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size                   = UDim2.new(1, -6, 0, 36)
	nameLbl.Position               = UDim2.new(0, 3, 0, 4)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text                   = getDisplayName(tool)
	nameLbl.TextColor3             = Color3.fromRGB(230, 230, 230)
	nameLbl.Font                   = Enum.Font.GothamBold
	nameLbl.TextSize               = 11
	nameLbl.TextWrapped            = true
	nameLbl.TextXAlignment         = Enum.TextXAlignment.Center
	nameLbl.TextYAlignment         = Enum.TextYAlignment.Center
	nameLbl.Parent                 = slot

	-- Rareté
	local rarityLbl = Instance.new("TextLabel")
	rarityLbl.Size                   = UDim2.new(1, -6, 0, 16)
	rarityLbl.Position               = UDim2.new(0, 3, 0, 44)
	rarityLbl.BackgroundTransparency = 1
	rarityLbl.Text                   = tool:GetAttribute("Rarity") or ""
	rarityLbl.TextColor3             = getToolColor(tool)
	rarityLbl.Font                   = Enum.Font.Gotham
	rarityLbl.TextSize               = 10
	rarityLbl.TextXAlignment         = Enum.TextXAlignment.Center
	rarityLbl.Parent                 = slot

	-- Quantité (attribut Count)
	local count = tool:GetAttribute("Count")
	if count and count > 1 then
		local cntLbl = Instance.new("TextLabel")
		cntLbl.Size                   = UDim2.new(0, 28, 0, 16)
		cntLbl.Position               = UDim2.new(1, -30, 1, -20)
		cntLbl.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
		cntLbl.BackgroundTransparency = 0.3
		cntLbl.Text                   = "x" .. count
		cntLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
		cntLbl.Font                   = Enum.Font.GothamBold
		cntLbl.TextSize               = 10
		cntLbl.TextXAlignment         = Enum.TextXAlignment.Right
		cntLbl.BorderSizePixel        = 0
		cntLbl.Parent                 = slot
		Instance.new("UICorner", cntLbl).CornerRadius = UDim.new(0, 4)
	end

	-- Badge "Équipé"
	if equipped then
		local eqLbl = Instance.new("TextLabel")
		eqLbl.Size                   = UDim2.new(1, -8, 0, 14)
		eqLbl.Position               = UDim2.new(0, 4, 1, -18)
		eqLbl.BackgroundColor3       = Color3.fromRGB(40, 160, 80)
		eqLbl.BackgroundTransparency = 0
		eqLbl.Text                   = "Équipé"
		eqLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
		eqLbl.Font                   = Enum.Font.GothamBold
		eqLbl.TextSize               = 9
		eqLbl.TextXAlignment         = Enum.TextXAlignment.Center
		eqLbl.BorderSizePixel        = 0
		eqLbl.Parent                 = slot
		Instance.new("UICorner", eqLbl).CornerRadius = UDim.new(0, 4)
	end

	-- Clic → équiper / déséquiper
	slot.MouseButton1Click:Connect(function()
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		if equipped then
			humanoid:UnequipTools()
		else
			humanoid:EquipTool(tool)
		end
	end)
end

local function rebuildGrid()
	-- Vider
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local query  = _filter:lower()
	local total  = 0

	-- Équipé en premier
	if player.Character then
		for _, tool in ipairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") then
				local display = getDisplayName(tool):lower()
				if query == "" or display:find(query, 1, true) then
					buildSlot(tool, true)
					total += 1
				end
			end
		end
	end

	-- Backpack
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			local display = getDisplayName(tool):lower()
			if query == "" or display:find(query, 1, true) then
				buildSlot(tool, false)
				total += 1
			end
		end
	end

	countLbl.Text = total .. " objet(s)"

	-- Canvas
	local cols = math.max(math.floor(scrollFrame.AbsoluteSize.X / (90 + 8)), 1)
	local rows = math.ceil(total / cols)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, rows * (100 + 8) + 8)
end

-- ─── Ouverture / Fermeture ────────────────────────────────────────────────────
local function openInventory()
	screenGui.Enabled = true
	searchBox.Text    = ""
	_filter           = ""
	rebuildGrid()
end

local function closeInventory()
	screenGui.Enabled = false
end

-- ─── Bouton haut-gauche ───────────────────────────────────────────────────────
local btnGui = Instance.new("ScreenGui")
btnGui.Name           = "InventoryButtonUI"
btnGui.ResetOnSpawn   = false
btnGui.DisplayOrder   = 10
btnGui.IgnoreGuiInset = false
btnGui.Parent         = PlayerGui

local openBtn = Instance.new("TextButton")
openBtn.Size                  = UDim2.new(0, 44, 0, 44)
openBtn.Position              = UDim2.new(0, 8, 0, 100)
openBtn.BackgroundColor3      = Color3.fromRGB(20, 20, 30)
openBtn.BackgroundTransparency = 0.15
openBtn.BorderSizePixel       = 0
openBtn.Text                  = "🎒"
openBtn.TextSize              = 22
openBtn.Font                  = Enum.Font.GothamBold
openBtn.AutoButtonColor       = true
openBtn.Parent                = btnGui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 8)
local btnStroke = Instance.new("UIStroke")
btnStroke.Color     = Color3.fromRGB(80, 80, 120)
btnStroke.Thickness = 1
btnStroke.Parent    = openBtn

openBtn.MouseButton1Click:Connect(function()
	if screenGui.Enabled then closeInventory() else openInventory() end
end)

-- ─── Événements ──────────────────────────────────────────────────────────────
closeBtn.MouseButton1Click:Connect(closeInventory)
backdrop.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		closeInventory()
	end
end)

-- Recherche en temps réel
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	_filter = searchBox.Text
	rebuildGrid()
end)

-- Mise à jour auto quand le backpack change
backpack.ChildAdded:Connect(function()   if screenGui.Enabled then rebuildGrid() end end)
backpack.ChildRemoved:Connect(function() if screenGui.Enabled then rebuildGrid() end end)

player.CharacterAdded:Connect(function(char)
	char.ChildAdded:Connect(function()   if screenGui.Enabled then rebuildGrid() end end)
	char.ChildRemoved:Connect(function() if screenGui.Enabled then rebuildGrid() end end)
end)
if player.Character then
	player.Character.ChildAdded:Connect(function()   if screenGui.Enabled then rebuildGrid() end end)
	player.Character.ChildRemoved:Connect(function() if screenGui.Enabled then rebuildGrid() end end)
end

-- Touche ² / BackQuote pour toggle (comme l'inventaire Roblox)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.BackQuote then
		if screenGui.Enabled then closeInventory() else openInventory() end
	end
end)
