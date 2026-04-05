--[[
	BackpackButtonHandler
	- Hotbar custom 9 slots avec drag & drop
	- Inventaire (outils hors hotbar) avec barre de recherche et drag & drop
	- Désactive le backpack natif Roblox
]]

local Players          = game:GetService("Players")
local StarterGui       = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONSTANTES
-- ═══════════════════════════════════════════════════════════════════════════════
local SLOT_COUNT  = 9
local SLOT_SIZE   = 60
local SLOT_PAD    = 4
local BAR_HEIGHT  = 12
local DRAG_THRESHOLD = 6  -- pixels avant de considérer que c'est un drag

-- ═══════════════════════════════════════════════════════════════════════════════
-- HOTBAR GUI
-- ═══════════════════════════════════════════════════════════════════════════════
local hotbarGui = Instance.new("ScreenGui")
hotbarGui.Name           = "CustomHotbar"
hotbarGui.ResetOnSpawn   = false
hotbarGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
hotbarGui.DisplayOrder   = 18
hotbarGui.IgnoreGuiInset = true
hotbarGui.Parent         = PlayerGui

local PAD_X       = 6  -- padding gauche/droite du hotbar
local totalWidth  = SLOT_COUNT * SLOT_SIZE + (SLOT_COUNT - 1) * SLOT_PAD + PAD_X * 2

local hotbarFrame = Instance.new("Frame")
hotbarFrame.Name                   = "HotbarFrame"
hotbarFrame.Size                   = UDim2.fromOffset(totalWidth, SLOT_SIZE + 8)
hotbarFrame.AnchorPoint            = Vector2.new(0.5, 1)
hotbarFrame.Position               = UDim2.new(0.5, 0, 1, -(BAR_HEIGHT + 14))
hotbarFrame.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
hotbarFrame.BackgroundTransparency = 0.3
hotbarFrame.BorderSizePixel        = 0
hotbarFrame.ClipsDescendants       = false
hotbarFrame.Parent                 = hotbarGui
Instance.new("UICorner", hotbarFrame).CornerRadius = UDim.new(0, 6)

-- Pas de UIListLayout : positions absolues fixes pour éviter tout décalage
local function slotX(index)
	return PAD_X + (index - 1) * (SLOT_SIZE + SLOT_PAD)
end

local function slotY()
	return (SLOT_SIZE + 8 - SLOT_SIZE) / 2   -- centré verticalement
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- INVENTAIRE GUI
-- ═══════════════════════════════════════════════════════════════════════════════
local invGui = Instance.new("ScreenGui")
invGui.Name           = "BackpackPanelUI"
invGui.ResetOnSpawn   = false
invGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
invGui.DisplayOrder   = 20
invGui.IgnoreGuiInset = false
invGui.Parent         = PlayerGui

local toggleBtn = Instance.new("ImageButton")
toggleBtn.Name                   = "BackpackToggle"
toggleBtn.Size                   = UDim2.fromOffset(44, 44)
toggleBtn.Position               = UDim2.new(0, 12, 1, -100)
toggleBtn.AnchorPoint            = Vector2.new(0, 1)
toggleBtn.BackgroundColor3       = Color3.fromRGB(30, 30, 30)
toggleBtn.BackgroundTransparency = 0.3
toggleBtn.BorderSizePixel        = 0
toggleBtn.Image                  = "rbxassetid://3926305904"
toggleBtn.ImageRectOffset        = Vector2.new(4, 36)
toggleBtn.ImageRectSize          = Vector2.new(36, 36)
toggleBtn.ImageColor3            = Color3.fromRGB(255, 255, 255)
toggleBtn.Parent                 = invGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)


local panel = Instance.new("Frame")
panel.Name                   = "InventoryPanel"
panel.Size                   = UDim2.fromOffset(totalWidth, 420)
panel.AnchorPoint            = Vector2.new(0.5, 1)
panel.Position               = UDim2.new(0.5, 0, 1, -(BAR_HEIGHT + SLOT_SIZE + 24))
panel.BackgroundColor3       = Color3.fromRGB(28, 28, 38)
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.ZIndex                 = 2
panel.Parent                 = invGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color     = Color3.fromRGB(60, 60, 80)
panelStroke.Thickness = 1

-- En-tête
local header = Instance.new("Frame")
header.Name             = "Header"
header.Size             = UDim2.new(1, 0, 0, 48)
header.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
header.BorderSizePixel  = 0
header.ZIndex           = 3
header.Parent           = panel
local headerCorner = Instance.new("UICorner", header)
headerCorner.CornerRadius = UDim.new(0, 10)
-- Cache les coins bas de l'header
local headerFix = Instance.new("Frame")
headerFix.Size             = UDim2.new(1, 0, 0.5, 0)
headerFix.Position         = UDim2.new(0, 0, 0.5, 0)
headerFix.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
headerFix.BorderSizePixel  = 0
headerFix.ZIndex           = 3
headerFix.Parent           = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Size                   = UDim2.new(1, -60, 1, 0)
titleLabel.Position               = UDim2.fromOffset(16, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                   = "Inventaire"
titleLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.TextSize               = 16
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.ZIndex                 = 4
titleLabel.Parent                 = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size                   = UDim2.fromOffset(30, 30)
closeBtn.Position               = UDim2.new(1, -40, 0.5, -15)
closeBtn.BackgroundColor3       = Color3.fromRGB(60, 60, 80)
closeBtn.BorderSizePixel        = 0
closeBtn.Text                   = "✕"
closeBtn.TextColor3             = Color3.fromRGB(200, 200, 200)
closeBtn.Font                   = Enum.Font.GothamBold
closeBtn.TextSize               = 14
closeBtn.ZIndex                 = 4
closeBtn.Parent                 = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Barre de recherche
local searchBar = Instance.new("TextBox")
searchBar.Size                   = UDim2.new(1, -32, 0, 34)
searchBar.Position               = UDim2.fromOffset(16, 56)
searchBar.BackgroundColor3       = Color3.fromRGB(38, 38, 52)
searchBar.BorderSizePixel        = 0
searchBar.PlaceholderText        = "🔍  Rechercher un outil..."
searchBar.PlaceholderColor3      = Color3.fromRGB(110, 110, 130)
searchBar.Text                   = ""
searchBar.TextColor3             = Color3.fromRGB(220, 220, 220)
searchBar.Font                   = Enum.Font.Gotham
searchBar.TextSize               = 13
searchBar.ClearTextOnFocus       = false
searchBar.ZIndex                 = 3
searchBar.Parent                 = panel
Instance.new("UICorner", searchBar).CornerRadius = UDim.new(0, 8)
local searchPad = Instance.new("UIPadding", searchBar)
searchPad.PaddingLeft = UDim.new(0, 12)

-- Filtres (Tous / Oeufs / Spawners / Brainrots)
local FILTERS = { "Tous", "Oeufs", "Spawners", "Brainrots" }
local activeFilter = "Tous"
local filterBtns   = {}

local filterBar = Instance.new("Frame")
filterBar.Size             = UDim2.new(1, -32, 0, 28)
filterBar.Position         = UDim2.fromOffset(16, 98)
filterBar.BackgroundTransparency = 1
filterBar.ZIndex           = 3
filterBar.Parent           = panel

local filterList = Instance.new("UIListLayout", filterBar)
filterList.FillDirection       = Enum.FillDirection.Horizontal
filterList.VerticalAlignment   = Enum.VerticalAlignment.Center
filterList.Padding             = UDim.new(0, 6)

for _, label in FILTERS do
	local fb = Instance.new("TextButton")
	fb.Size                   = UDim2.fromOffset(72, 24)
	fb.BackgroundColor3       = label == "Tous"
		and Color3.fromRGB(80, 80, 180)
		or  Color3.fromRGB(40, 40, 55)
	fb.BorderSizePixel        = 0
	fb.Text                   = label
	fb.TextColor3             = Color3.fromRGB(220, 220, 220)
	fb.Font                   = Enum.Font.GothamBold
	fb.TextSize               = 11
	fb.ZIndex                 = 4
	fb.Parent                 = filterBar
	Instance.new("UICorner", fb).CornerRadius = UDim.new(0, 6)
	filterBtns[label] = fb
end

-- Séparateur
local sep = Instance.new("Frame")
sep.Size             = UDim2.new(1, -32, 0, 1)
sep.Position         = UDim2.fromOffset(16, 132)
sep.BackgroundColor3 = Color3.fromRGB(50, 50, 68)
sep.BorderSizePixel  = 0
sep.ZIndex           = 3
sep.Parent           = panel

-- Zone scrollable
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name                   = "ToolGrid"
scrollFrame.Size                   = UDim2.new(1, -32, 1, -144)
scrollFrame.Position               = UDim2.fromOffset(16, 138)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel        = 0
scrollFrame.ScrollBarThickness     = 4
scrollFrame.ScrollBarImageColor3   = Color3.fromRGB(80, 80, 110)
scrollFrame.CanvasSize             = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scrollFrame.ZIndex                 = 3
scrollFrame.Parent                 = panel

local invGrid = Instance.new("UIGridLayout", scrollFrame)
invGrid.CellSize    = UDim2.fromOffset(80, 94)
invGrid.CellPadding = UDim2.fromOffset(10, 10)
invGrid.SortOrder   = Enum.SortOrder.Name
local scrollPad = Instance.new("UIPadding", scrollFrame)
scrollPad.PaddingTop  = UDim.new(0, 6)
scrollPad.PaddingLeft = UDim.new(0, 4)

-- ═══════════════════════════════════════════════════════════════════════════════
-- ÉTAT
-- ═══════════════════════════════════════════════════════════════════════════════
local slots      = {}   -- slots[i] = Tool | nil
local slotFrames = {}   -- slotFrames[i] = Frame
local equipped   = nil  -- Tool actuellement dans le character

local KEY_CODES = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
	Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
	Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- DRAG STATE
-- ═══════════════════════════════════════════════════════════════════════════════
local drag = {
	active      = false,
	tool        = nil,
	sourceSlot  = nil,   -- number si vient hotbar, nil si vient inventaire
	sourceFrame = nil,   -- frame réel déplacé
	startPos    = nil,
	moved       = false,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- FORWARD DECLARATIONS
-- ═══════════════════════════════════════════════════════════════════════════════
local buildInventory
local refreshSlot
local refreshAllSlots
local selectSlot

-- ═══════════════════════════════════════════════════════════════════════════════
-- RARITY
-- ═══════════════════════════════════════════════════════════════════════════════
local RARITY_COLORS = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(30,  180,  30),
	Rare      = Color3.fromRGB(0,   120, 255),
	Epic      = Color3.fromRGB(160,  0,  200),
	Legendary = Color3.fromRGB(255, 185,   0),
}

local function getToolRarity(tool)
	-- Attributs directs
	local r = tool:GetAttribute("Rarity") or tool:GetAttribute("SpawnerRarity")
	if r then return r end
	-- Oeuf_Common / Oeuf_Rare …
	local oeuf = tool.Name:match("^[Oo]euf_(.+)$")
	if oeuf then return oeuf end
	-- spawner_common / spawner_rare …
	local spawner = tool.Name:match("^spawner_(.+)$")
	if spawner then return spawner:sub(1,1):upper() .. spawner:sub(2) end
	-- Brainrot_{name} → pas de rareté dans le nom, on retourne nil
	return nil
end

local function rarityColor(tool)
	local r = getToolRarity(tool)
	return RARITY_COLORS[r] or Color3.fromRGB(60, 60, 80)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════
local function getToolIcon(tool)
	if tool and tool.TextureId ~= "" then
		return tool.TextureId, Vector2.new(0,0), Vector2.new(0,0)
	end
	return "rbxassetid://3926305904", Vector2.new(4,36), Vector2.new(36,36)
end

local function nextFreeSlot()
	for i = 1, SLOT_COUNT do
		if slots[i] == nil then return i end
	end
	return nil
end

local function slotOfTool(tool)
	for i = 1, SLOT_COUNT do
		if slots[i] == tool then return i end
	end
	return nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- VISUEL SLOTS HOTBAR
-- ═══════════════════════════════════════════════════════════════════════════════
refreshSlot = function(index)
	local frame  = slotFrames[index]
	if not frame then return end
	local tool   = slots[index]
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	local icon   = frame:FindFirstChild("Icon")
	local name   = frame:FindFirstChild("ToolName")
	local isEq   = (tool ~= nil and tool == equipped)

	frame.BackgroundColor3 = isEq
		and Color3.fromRGB(50, 50, 20)
		or  Color3.fromRGB(30, 30, 30)

	if tool then
		local rc = rarityColor(tool)
		stroke.Color     = isEq and Color3.fromRGB(255, 215, 0) or rc
		stroke.Thickness = isEq and 2 or 1
		local img, rectOff, rectSize = getToolIcon(tool)
		icon.Image            = img
		icon.ImageRectOffset  = rectOff
		icon.ImageRectSize    = rectSize
		name.Text             = tool.Name
	else
		stroke.Color     = Color3.fromRGB(80, 80, 80)
		stroke.Thickness = 1
		icon.Image = ""
		name.Text  = ""
	end
end

refreshAllSlots = function()
	for i = 1, SLOT_COUNT do refreshSlot(i) end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ÉQUIPEMENT
-- ═══════════════════════════════════════════════════════════════════════════════
selectSlot = function(index)
	local tool = slots[index]
	if not tool then return end
	local char = player.Character
	if not char then return end

	if equipped == tool then
		tool.Parent = player.Backpack
		equipped    = nil
	else
		if equipped then
			equipped.Parent = player.Backpack
		end
		equipped    = tool
		tool.Parent = char
	end
	refreshAllSlots()
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DRAG : GUI FLOTTANT
-- ═══════════════════════════════════════════════════════════════════════════════
local dragGui = Instance.new("ScreenGui")
dragGui.Name           = "DragGui"
dragGui.ResetOnSpawn   = false
dragGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
dragGui.DisplayOrder   = 100
dragGui.IgnoreGuiInset = true
dragGui.Parent         = PlayerGui

local function beginDragMove(pos)
	local frame = drag.sourceFrame
	if not frame then return end

	-- Élever le slot au-dessus des autres visuellement
	frame.ZIndex = 10
	for _, child in frame:GetDescendants() do
		if child:IsA("GuiObject") then child.ZIndex = 11 end
	end
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position    = UDim2.fromOffset(pos.X, pos.Y)
	-- Reparenter dans dragGui pour qu'il sorte du clip hotbarFrame
	frame.Parent = dragGui
end

local function endDragMove()
	local frame = drag.sourceFrame
	local idx   = drag.sourceSlot
	if not frame then return end

	-- Remettre dans hotbarFrame à sa position fixe d'origine
	frame.ZIndex      = 1
	for _, child in frame:GetDescendants() do
		if child:IsA("GuiObject") then child.ZIndex = 1 end
	end
	frame.AnchorPoint = Vector2.new(0, 0)
	if idx then
		frame.Position = UDim2.fromOffset(slotX(idx), slotY())
	end
	frame.Parent = hotbarFrame
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DRAG & DROP : LOGIQUE DROP
-- ═══════════════════════════════════════════════════════════════════════════════
local function findHotbarSlotAt(pos)
	local objects = PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
	for _, obj in objects do
		for i = 1, SLOT_COUNT do
			if obj == slotFrames[i] or obj:IsDescendantOf(slotFrames[i]) then
				return i
			end
		end
	end
	return nil
end

local function isOverInventory(pos)
	local objects = PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
	for _, obj in objects do
		if obj == panel or obj:IsDescendantOf(panel) then
			return true
		end
	end
	return false
end

local function applyDrop(pos)
	local tool       = drag.tool
	local sourceSlot = drag.sourceSlot

	local targetSlot = findHotbarSlotAt(pos)

	if targetSlot then
		-- Drop sur un slot hotbar
		if sourceSlot then
			-- Hotbar → Hotbar : échanger les données des slots
			local other       = slots[targetSlot]
			slots[targetSlot] = tool
			slots[sourceSlot] = other
			refreshSlot(sourceSlot)
			refreshSlot(targetSlot)
			-- Les frames restent à leurs positions fixes, seul le contenu change
		else
			-- Inventaire → Hotbar : placer (déplacer l'occupant si besoin)
			local displaced  = slots[targetSlot]
			slots[targetSlot] = tool
			-- displaced reste dans backpack (juste plus dans hotbar)
			refreshSlot(targetSlot)
			buildInventory()
		end

	elseif isOverInventory(pos) and sourceSlot then
		-- Hotbar → Inventaire : retirer du slot
		if equipped == tool then
			tool.Parent = player.Backpack
			equipped    = nil
		end
		slots[sourceSlot] = nil
		refreshSlot(sourceSlot)
		buildInventory()
	end
	-- Sinon drop dans le vide : annuler, rien ne bouge
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DRAG : ÉVÉNEMENTS GLOBAUX
-- ═══════════════════════════════════════════════════════════════════════════════
UserInputService.InputChanged:Connect(function(input)
	if not drag.active then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement
	and input.UserInputType ~= Enum.UserInputType.Touch then return end

	local pos = input.Position

	if not drag.moved then
		local d = (Vector2.new(pos.X, pos.Y) - Vector2.new(drag.startPos.X, drag.startPos.Y)).Magnitude
		if d >= DRAG_THRESHOLD then
			drag.moved = true
			beginDragMove(pos)
		end
	else
		if drag.sourceFrame and drag.sourceFrame.Parent == dragGui then
			drag.sourceFrame.Position = UDim2.fromOffset(pos.X, pos.Y)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not drag.active then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
	and input.UserInputType ~= Enum.UserInputType.Touch then return end

	local pos = input.Position

	if drag.moved then
		endDragMove()
		applyDrop(pos)
	else
		-- Simple clic
		if drag.sourceSlot then
			selectSlot(drag.sourceSlot)
		else
			local idx = nextFreeSlot()
			if idx then
				slots[idx] = drag.tool
				refreshSlot(idx)
				buildInventory()
			end
		end
	end

	drag.active       = false
	drag.tool         = nil
	drag.sourceSlot   = nil
	drag.sourceFrame  = nil

	drag.moved        = false
	drag.startPos     = nil
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- CRÉATION DES SLOTS HOTBAR
-- ═══════════════════════════════════════════════════════════════════════════════
local function createSlot(index)
	local slot = Instance.new("Frame")
	slot.Name                    = "Slot" .. index
	slot.Size                    = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	-- Position absolue fixe — ne bougera jamais
	slot.Position                = UDim2.fromOffset(slotX(index), slotY())
	slot.BackgroundColor3        = Color3.fromRGB(30, 30, 30)
	slot.BackgroundTransparency  = 0.2
	slot.BorderSizePixel         = 0
	slot.Parent                  = hotbarFrame
	Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke", slot)
	stroke.Color     = Color3.fromRGB(80, 80, 80)
	stroke.Thickness = 1

	local numLabel = Instance.new("TextLabel")
	numLabel.Size                   = UDim2.fromOffset(16, 16)
	numLabel.Position               = UDim2.fromOffset(3, 2)
	numLabel.BackgroundTransparency = 1
	numLabel.Text                   = tostring(index)
	numLabel.TextColor3             = Color3.fromRGB(180, 180, 180)
	numLabel.Font                   = Enum.Font.GothamBold
	numLabel.TextSize               = 11
	numLabel.Parent                 = slot

	local icon = Instance.new("ImageLabel")
	icon.Name                   = "Icon"
	icon.Size                   = UDim2.fromOffset(38, 38)
	icon.Position               = UDim2.new(0.5, 0, 0.5, -4)
	icon.AnchorPoint            = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image                  = ""
	icon.Parent                 = slot

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name                   = "ToolName"
	nameLabel.Size                   = UDim2.new(1, -4, 0, 14)
	nameLabel.Position               = UDim2.new(0, 2, 1, -15)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text                   = ""
	nameLabel.TextColor3             = Color3.fromRGB(210, 210, 210)
	nameLabel.Font                   = Enum.Font.Gotham
	nameLabel.TextSize               = 9
	nameLabel.TextTruncate           = Enum.TextTruncate.AtEnd
	nameLabel.TextXAlignment         = Enum.TextXAlignment.Center
	nameLabel.Parent                 = slot

	-- Bouton transparent par-dessus pour capturer les inputs
	local btn = Instance.new("TextButton")
	btn.Size                   = UDim2.fromScale(1, 1)
	btn.BackgroundTransparency = 1
	btn.Text                   = ""
	btn.ZIndex                 = 5
	btn.Parent                 = slot

	slot.LayoutOrder = index

	btn.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if not slots[index] then return end
		drag.active       = true
		drag.tool         = slots[index]
		drag.sourceSlot   = index
		drag.sourceFrame  = slot

		drag.startPos     = input.Position
		drag.moved        = false
	end)

	slotFrames[index] = slot
	slots[index]      = nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- INVENTAIRE
-- ═══════════════════════════════════════════════════════════════════════════════
local currentFilter = ""

buildInventory = function()
	for _, child in scrollFrame:GetChildren() do
		if not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	local filter = currentFilter:lower()
	local shown  = 0

	local function matchesCategory(tool)
		local n = tool.Name:lower()
		if activeFilter == "Oeufs"     then return n:find("^oeuf_") ~= nil end
		if activeFilter == "Spawners"  then
			return n:find("^spawner_") ~= nil or tool:GetAttribute("SpawnerRarity") ~= nil
		end
		if activeFilter == "Brainrots" then return n:find("^brainrot_") ~= nil end
		return true -- "Tous"
	end

	for _, tool in player.Backpack:GetChildren() do
		if not tool:IsA("Tool") then continue end
		if slotOfTool(tool) then continue end
		if not matchesCategory(tool) then continue end
		if filter ~= "" and not tool.Name:lower():find(filter, 1, true) then continue end

		shown += 1
		local capturedTool = tool

		local rc = rarityColor(capturedTool)

		local slot = Instance.new("Frame")
		slot.Size                   = UDim2.fromOffset(80, 94)
		slot.BackgroundColor3       = Color3.fromRGB(38, 38, 54)
		slot.BorderSizePixel        = 0
		slot.ZIndex                 = 4
		slot.Parent                 = scrollFrame
		Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 8)
		local slotStroke = Instance.new("UIStroke", slot)
		slotStroke.Color     = rc
		slotStroke.Thickness = 2

		local img, rectOff, rectSize = getToolIcon(capturedTool)
		local icon = Instance.new("ImageLabel")
		icon.Size                   = UDim2.fromOffset(52, 52)
		icon.Position               = UDim2.new(0.5, 0, 0, 10)
		icon.AnchorPoint            = Vector2.new(0.5, 0)
		icon.BackgroundTransparency = 1
		icon.Image                  = img
		icon.ImageRectOffset        = rectOff
		icon.ImageRectSize          = rectSize
		icon.ZIndex                 = 5
		icon.Parent                 = slot

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size                   = UDim2.new(1, -6, 0, 22)
		nameLabel.Position               = UDim2.new(0, 3, 1, -24)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text                   = capturedTool.Name
		nameLabel.TextColor3             = Color3.fromRGB(210, 210, 210)
		nameLabel.Font                   = Enum.Font.Gotham
		nameLabel.TextSize               = 11
		nameLabel.TextTruncate           = Enum.TextTruncate.AtEnd
		nameLabel.TextXAlignment         = Enum.TextXAlignment.Center
		nameLabel.ZIndex                 = 5
		nameLabel.Parent                 = slot

		-- Bouton invisible pour capturer les inputs
		local btn = Instance.new("TextButton")
		btn.Size                   = UDim2.fromScale(1, 1)
		btn.BackgroundTransparency = 1
		btn.Text                   = ""
		btn.ZIndex                 = 5
		btn.Parent                 = slot

		btn.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
			drag.active       = true
			drag.tool         = capturedTool
			drag.sourceSlot   = nil
			drag.sourceFrame  = slot

			drag.startPos     = input.Position
			drag.moved        = false
		end)
	end

	if shown == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size                   = UDim2.new(1, 0, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Text                   = filter ~= "" and "Aucun résultat" or "Inventaire vide"
		empty.TextColor3             = Color3.fromRGB(130, 130, 150)
		empty.Font                   = Enum.Font.Gotham
		empty.TextSize               = 13
		empty.TextXAlignment         = Enum.TextXAlignment.Center
		empty.Parent                 = scrollFrame
	end
end

searchBar:GetPropertyChangedSignal("Text"):Connect(function()
	currentFilter = searchBar.Text
	buildInventory()
end)

for _, label in FILTERS do
	filterBtns[label].MouseButton1Click:Connect(function()
		activeFilter = label
		-- Mettre à jour l'apparence des boutons
		for _, lbl in FILTERS do
			filterBtns[lbl].BackgroundColor3 = lbl == label
				and Color3.fromRGB(80, 80, 180)
				or  Color3.fromRGB(40, 40, 55)
		end
		buildInventory()
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ÉCOUTE DU BACKPACK
-- ═══════════════════════════════════════════════════════════════════════════════
local function addToolToHotbar(tool)
	if slotOfTool(tool) then return end
	local idx = nextFreeSlot()
	if idx then
		slots[idx] = tool
		refreshSlot(idx)
	end
end

local function removeToolFromHotbar(tool)
	local idx = slotOfTool(tool)
	if idx then
		slots[idx] = nil
		if equipped == tool then equipped = nil end
		refreshSlot(idx)
	end
end

local function onToolAdded(tool)
	if not tool:IsA("Tool") then return end
	if equipped == tool then equipped = nil end
	if not slotOfTool(tool) then
		addToolToHotbar(tool)
	end
	refreshAllSlots()
	if panel.Visible then buildInventory() end
end

local function onToolRemoved(tool)
	if not tool:IsA("Tool") then return end
	local char = player.Character
	if char and tool:IsDescendantOf(char) then
		equipped = tool
		refreshAllSlots()
		return
	end
	removeToolFromHotbar(tool)
	if panel.Visible then buildInventory() end
end

local function connectBackpack()
	local backpack = player.Backpack
	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") then addToolToHotbar(tool) end
	end
	backpack.ChildAdded:Connect(onToolAdded)
	backpack.ChildRemoved:Connect(onToolRemoved)

	-- Écoute aussi le character : si un outil équipé est détruit (oeuf posé),
	-- on nettoie son slot immédiatement
	local char = player.Character
	if char then
		char.ChildRemoved:Connect(function(child)
			if not child:IsA("Tool") then return end
			-- L'outil a été détruit depuis le character (pas juste déséquipé)
			-- Si il n'est plus dans le backpack non plus, on nettoie le slot
			task.defer(function()
				if child.Parent ~= player.Backpack then
					removeToolFromHotbar(child)
					if panel.Visible then buildInventory() end
				end
			end)
		end)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLAVIER 1-9
-- ═══════════════════════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	for i, keyCode in KEY_CODES do
		if input.KeyCode == keyCode then
			selectSlot(i)
			break
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- TOGGLE INVENTAIRE
-- ═══════════════════════════════════════════════════════════════════════════════
local function openInventory()
	searchBar.Text = ""
	currentFilter  = ""
	buildInventory()
	panel.Visible  = true
end

local function closeInventory()
	panel.Visible = false
end

toggleBtn.MouseButton1Click:Connect(function()
	if panel.Visible then closeInventory() else openInventory() end
end)

closeBtn.MouseButton1Click:Connect(closeInventory)

-- ═══════════════════════════════════════════════════════════════════════════════
-- RESPAWN
-- ═══════════════════════════════════════════════════════════════════════════════
local function onCharacterAdded()
	for i = 1, SLOT_COUNT do
		slots[i] = nil
		refreshSlot(i)
	end
	equipped      = nil
	closeInventory()
	if drag.moved then endDragMove() end
	drag.active       = false
	drag.sourceFrame  = nil

	drag.moved        = false

	task.wait(0.5)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	connectBackpack()
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════════════════════════════════════
for i = 1, SLOT_COUNT do
	createSlot(i)
end

if player.Character then
	task.spawn(onCharacterAdded)
end

player.CharacterAdded:Connect(onCharacterAdded)
