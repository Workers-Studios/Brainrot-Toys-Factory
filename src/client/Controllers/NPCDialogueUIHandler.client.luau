--[[
    NPCDialogueUIHandler - UI client pour les dialogues PNJ et la vente d'items

    Panneaux :
      1. Dialogue    : nom NPC + texte intro + 4 options (touches 1-4)
      2. Inventaire  : liste des items avec cases à cocher + prix + bouton OK

    Flow :
      ProximityPrompt E → OpenNPCDialogue → panneau dialogue
      Option 1 (SellHeld)   → NPCSellHeld → résultat
      Option 2 (SellAll)    → NPCSellAll  → résultat
      Option 3 (OpenSellUI) → NPCGetSellInventory → panneau inventaire → NPCSellItems
      Option 4 (Close)      → ferme le dialogue
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local NPCDialogueConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NPCDialogueConfig"))

local ev = ReplicatedStorage:WaitForChild("RemoteInterface"):WaitForChild("Events")
local fn = ReplicatedStorage:WaitForChild("RemoteInterface"):WaitForChild("Functions")

local evOpenDialogue = ev:WaitForChild("OpenNPCDialogue")
local evSellHeld     = ev:WaitForChild("NPCSellHeld")
local evSellAll      = ev:WaitForChild("NPCSellAll")
local evSellItems    = ev:WaitForChild("NPCSellItems")
local evSellResult   = ev:WaitForChild("NPCSellResult")
local fnGetInventory = fn:WaitForChild("NPCGetSellInventory")

-- ─── State ────────────────────────────────────────────────────────────────────

local _currentNPCId   = nil   -- "BrainrotPNJ" | "SpawnerPNJ"
local _currentConfig  = nil   -- config table du PNJ actif
local _quantities     = {}    -- { [key] = { qty, max, priceEach, name, rarity } }

-- ─── Colors ───────────────────────────────────────────────────────────────────

local C = {
    bg      = Color3.fromRGB(20,  22,  32),
    panel   = Color3.fromRGB(30,  34,  48),
    header  = Color3.fromRGB(40,  46,  66),
    accent  = Color3.fromRGB(80,  160, 255),
    green   = Color3.fromRGB(50,  200, 100),
    red     = Color3.fromRGB(220, 60,  60),
    gold    = Color3.fromRGB(255, 200, 50),
    text    = Color3.fromRGB(230, 230, 240),
    subtext = Color3.fromRGB(150, 155, 175),
    divider = Color3.fromRGB(50,  56,  75),
    itemBg  = Color3.fromRGB(35,  40,  56),
    hover   = Color3.fromRGB(50,  58,  82),
    keyBg   = Color3.fromRGB(55,  62,  85),
}

local RARITY_COLORS = {
    Common    = Color3.fromRGB(180, 180, 180),
    Uncommon  = Color3.fromRGB(80,  210, 80),
    Rare      = Color3.fromRGB(80,  140, 255),
    Epic      = Color3.fromRGB(180, 80,  255),
    Legendary = Color3.fromRGB(255, 175, 30),
}

-- ─── Helpers UI ───────────────────────────────────────────────────────────────

local function corner(parent, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = parent
end
local function stroke(parent, color, t)
    local s = Instance.new("UIStroke"); s.Color = color or C.divider; s.Thickness = t or 1; s.Parent = parent
end
local function padding(parent, p)
    local ui = Instance.new("UIPadding")
    ui.PaddingLeft = UDim.new(0, p); ui.PaddingRight  = UDim.new(0, p)
    ui.PaddingTop  = UDim.new(0, p); ui.PaddingBottom = UDim.new(0, p)
    ui.Parent = parent
end

-- ─── ScreenGui ────────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name           = "NPCDialogueUI"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = playerGui

-- ─── Notification banner ─────────────────────────────────────────────────────

local notifFrame = Instance.new("Frame")
notifFrame.Size             = UDim2.new(0, 380, 0, 48)
notifFrame.Position         = UDim2.new(0.5, -190, 0, -60)
notifFrame.BackgroundColor3 = C.panel
notifFrame.BorderSizePixel  = 0
notifFrame.Visible          = false
notifFrame.ZIndex           = 30
corner(notifFrame, 8)
stroke(notifFrame, C.accent)
notifFrame.Parent = gui

local notifLabel = Instance.new("TextLabel")
notifLabel.Size              = UDim2.new(1, -16, 1, 0)
notifLabel.Position          = UDim2.new(0, 8, 0, 0)
notifLabel.BackgroundTransparency = 1
notifLabel.TextColor3        = C.text
notifLabel.Font              = Enum.Font.GothamBold
notifLabel.TextSize          = 14
notifLabel.TextXAlignment    = Enum.TextXAlignment.Center
notifLabel.ZIndex            = 31
notifLabel.Parent            = notifFrame

local _notifActive = false
local function showNotif(msg, color)
    notifLabel.Text             = msg
    stroke(notifFrame, color or C.accent)
    notifFrame.Visible          = true
    notifFrame.Position         = UDim2.new(0.5, -190, 0, -60)
    TweenService:Create(notifFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, -190, 0, 70) }):Play()
    task.delay(2.5, function()
        local t = TweenService:Create(notifFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(0.5, -190, 0, -60) })
        t:Play()
        t.Completed:Connect(function() notifFrame.Visible = false end)
    end)
end

-- ─── Dialogue Panel ───────────────────────────────────────────────────────────

local DIAL_W, DIAL_H = 400, 300
local dialoguePanel = Instance.new("Frame")
dialoguePanel.Name             = "DialoguePanel"
dialoguePanel.Size             = UDim2.new(0, DIAL_W, 0, DIAL_H)
dialoguePanel.Position         = UDim2.new(0.5, -DIAL_W/2, 0.5, -DIAL_H/2)
dialoguePanel.BackgroundColor3 = C.bg
dialoguePanel.BorderSizePixel  = 0
dialoguePanel.Visible          = false
dialoguePanel.ZIndex           = 10
corner(dialoguePanel, 12)
stroke(dialoguePanel, C.divider, 2)
dialoguePanel.Parent = gui

-- En-tête
local dialHeader = Instance.new("Frame")
dialHeader.Size             = UDim2.new(1, 0, 0, 52)
dialHeader.BackgroundColor3 = C.header
dialHeader.BorderSizePixel  = 0
corner(dialHeader, 12)
dialHeader.ZIndex = 11
dialHeader.Parent = dialoguePanel

local dialNPCName = Instance.new("TextLabel")
dialNPCName.Size              = UDim2.new(1, -16, 1, 0)
dialNPCName.Position          = UDim2.new(0, 8, 0, 0)
dialNPCName.BackgroundTransparency = 1
dialNPCName.Text              = ""
dialNPCName.TextColor3        = C.text
dialNPCName.Font              = Enum.Font.GothamBold
dialNPCName.TextSize          = 16
dialNPCName.TextXAlignment    = Enum.TextXAlignment.Left
dialNPCName.ZIndex            = 12
dialNPCName.Parent            = dialHeader

-- Texte intro
local dialIntro = Instance.new("TextLabel")
dialIntro.Size              = UDim2.new(1, -24, 0, 56)
dialIntro.Position          = UDim2.new(0, 12, 0, 58)
dialIntro.BackgroundTransparency = 1
dialIntro.Text              = ""
dialIntro.TextColor3        = C.subtext
dialIntro.Font              = Enum.Font.Gotham
dialIntro.TextSize          = 13
dialIntro.TextWrapped       = true
dialIntro.TextXAlignment    = Enum.TextXAlignment.Left
dialIntro.TextYAlignment    = Enum.TextYAlignment.Top
dialIntro.ZIndex            = 11
dialIntro.Parent            = dialoguePanel

-- Ligne séparatrice
local divLine = Instance.new("Frame")
divLine.Size             = UDim2.new(1, -24, 0, 1)
divLine.Position         = UDim2.new(0, 12, 0, 118)
divLine.BackgroundColor3 = C.divider
divLine.BorderSizePixel  = 0
divLine.ZIndex           = 11
divLine.Parent           = dialoguePanel

-- Boutons d'options (4 boutons)
local optionButtons = {}
for i = 1, 4 do
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, -24, 0, 36)
    row.Position         = UDim2.new(0, 12, 0, 124 + (i - 1) * 40)
    row.BackgroundColor3 = C.itemBg
    row.BorderSizePixel  = 0
    row.ZIndex           = 11
    corner(row, 6)
    row.Parent = dialoguePanel

    -- Touche clavier
    local keyLabel = Instance.new("TextLabel")
    keyLabel.Size             = UDim2.new(0, 26, 0, 26)
    keyLabel.Position         = UDim2.new(0, 4, 0.5, -13)
    keyLabel.BackgroundColor3 = C.keyBg
    keyLabel.Text             = tostring(i)
    keyLabel.TextColor3       = C.accent
    keyLabel.Font             = Enum.Font.GothamBold
    keyLabel.TextSize         = 13
    keyLabel.ZIndex           = 12
    corner(keyLabel, 4)
    keyLabel.Parent = row

    -- Label option
    local optLabel = Instance.new("TextLabel")
    optLabel.Size           = UDim2.new(1, -38, 1, 0)
    optLabel.Position       = UDim2.new(0, 34, 0, 0)
    optLabel.BackgroundTransparency = 1
    optLabel.Text           = ""
    optLabel.TextColor3     = C.text
    optLabel.Font           = Enum.Font.GothamBold
    optLabel.TextSize       = 13
    optLabel.TextXAlignment = Enum.TextXAlignment.Left
    optLabel.ZIndex         = 12
    optLabel.Parent         = row

    -- Bouton invisible par-dessus
    local btn = Instance.new("TextButton")
    btn.Size              = UDim2.fromScale(1, 1)
    btn.BackgroundTransparency = 1
    btn.Text              = ""
    btn.ZIndex            = 13
    btn.Parent            = row
    btn.AutoButtonColor   = false

    btn.MouseEnter:Connect(function()  row.BackgroundColor3 = C.hover end)
    btn.MouseLeave:Connect(function() row.BackgroundColor3 = C.itemBg end)

    optionButtons[i] = { row = row, label = optLabel, btn = btn }
end

-- ─── Inventory Sell Panel ─────────────────────────────────────────────────────

local INV_W, INV_H = 500, 480
local invPanel = Instance.new("Frame")
invPanel.Name             = "SellInventoryPanel"
invPanel.Size             = UDim2.new(0, INV_W, 0, INV_H)
invPanel.Position         = UDim2.new(0.5, -INV_W/2, 0.5, -INV_H/2)
invPanel.BackgroundColor3 = C.bg
invPanel.BorderSizePixel  = 0
invPanel.Visible          = false
invPanel.ZIndex           = 15
corner(invPanel, 12)
stroke(invPanel, C.divider, 2)
invPanel.Parent = gui

-- En-tête inventaire
local invHeader = Instance.new("Frame")
invHeader.Size             = UDim2.new(1, 0, 0, 50)
invHeader.BackgroundColor3 = C.header
invHeader.BorderSizePixel  = 0
corner(invHeader, 12)
invHeader.ZIndex = 16
invHeader.Parent = invPanel

local invTitle = Instance.new("TextLabel")
invTitle.Size              = UDim2.new(1, -60, 1, 0)
invTitle.Position          = UDim2.new(0, 14, 0, 0)
invTitle.BackgroundTransparency = 1
invTitle.Text              = "Choisir quoi vendre"
invTitle.TextColor3        = C.text
invTitle.Font              = Enum.Font.GothamBold
invTitle.TextSize          = 15
invTitle.TextXAlignment    = Enum.TextXAlignment.Left
invTitle.ZIndex            = 17
invTitle.Parent            = invHeader

local invCloseBtn = Instance.new("TextButton")
invCloseBtn.Size             = UDim2.new(0, 30, 0, 30)
invCloseBtn.Position         = UDim2.new(1, -40, 0.5, -15)
invCloseBtn.BackgroundColor3 = Color3.fromRGB(130, 30, 30)
invCloseBtn.Text             = "✕"
invCloseBtn.TextColor3       = Color3.new(1,1,1)
invCloseBtn.Font             = Enum.Font.GothamBold
invCloseBtn.TextSize         = 14
invCloseBtn.ZIndex           = 17
corner(invCloseBtn, 6)
invCloseBtn.Parent = invHeader

-- Liste scrollable
local invScroll = Instance.new("ScrollingFrame")
invScroll.Position              = UDim2.new(0, 12, 0, 58)
invScroll.Size                  = UDim2.new(1, -24, 0, INV_H - 130)
invScroll.BackgroundTransparency = 1
invScroll.BorderSizePixel       = 0
invScroll.ScrollBarThickness    = 4
invScroll.ScrollBarImageColor3  = C.accent
invScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
invScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
invScroll.ZIndex                = 16
invScroll.Parent                = invPanel

local invLayout = Instance.new("UIListLayout")
invLayout.SortOrder = Enum.SortOrder.LayoutOrder
invLayout.Padding   = UDim.new(0, 4)
invLayout.Parent    = invScroll

-- Barre du bas
local invBottom = Instance.new("Frame")
invBottom.Size             = UDim2.new(1, 0, 0, 60)
invBottom.Position         = UDim2.new(0, 0, 1, -60)
invBottom.BackgroundColor3 = C.panel
invBottom.BorderSizePixel  = 0
invBottom.ZIndex           = 16
invBottom.Parent           = invPanel

local invTotalLabel = Instance.new("TextLabel")
invTotalLabel.Size              = UDim2.new(0.5, 0, 1, 0)
invTotalLabel.BackgroundTransparency = 1
invTotalLabel.Text              = "Total : $0"
invTotalLabel.TextColor3        = C.gold
invTotalLabel.Font              = Enum.Font.GothamBold
invTotalLabel.TextSize          = 14
invTotalLabel.TextXAlignment    = Enum.TextXAlignment.Left
invTotalLabel.ZIndex            = 17
padding(invTotalLabel, 10)
invTotalLabel.Parent = invBottom

local invOKBtn = Instance.new("TextButton")
invOKBtn.Size             = UDim2.new(0, 110, 0, 38)
invOKBtn.Position         = UDim2.new(1, -130, 0.5, -19)
invOKBtn.BackgroundColor3 = Color3.fromRGB(25, 110, 55)
invOKBtn.Text             = "✔  Vendre"
invOKBtn.TextColor3       = Color3.new(1,1,1)
invOKBtn.Font             = Enum.Font.GothamBold
invOKBtn.TextSize         = 14
invOKBtn.ZIndex           = 17
corner(invOKBtn, 8)
invOKBtn.Parent = invBottom

-- ─── Logic ────────────────────────────────────────────────────────────────────

local function closeDialogue()
    dialoguePanel.Visible = false
    invPanel.Visible      = false
    _currentNPCId  = nil
    _currentConfig = nil
    _quantities    = {}
end

local function closeInvPanel()
    invPanel.Visible = false
    _quantities      = {}
end

invCloseBtn.MouseButton1Click:Connect(closeInvPanel)

-- Recalcule le total à partir des quantités
local function recalcTotal()
    local total = 0
    for _, data in pairs(_quantities) do
        total = total + data.qty * data.priceEach
    end
    invTotalLabel.Text = string.format("Total : $%d", total)
end

-- Construit la liste de l'inventaire de vente (items stackés avec sélecteur de quantité)
local function buildSellInventory(items, npcType)
    for _, child in ipairs(invScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    _quantities = {}
    recalcTotal()

    -- Stacker les brainrots par nom côté client (serveur envoie une liste plate)
    local stackedList = {}
    if npcType == "brainrot" then
        local stackMap   = {}
        local stackOrder = {}
        for _, item in ipairs(items) do
            local k = item.Name
            if not stackMap[k] then
                stackMap[k] = { Name = item.Name, Rarity = item.Rarity, PriceEach = item.Price, Count = 0 }
                table.insert(stackOrder, k)
            end
            stackMap[k].Count = stackMap[k].Count + 1
        end
        for _, k in ipairs(stackOrder) do
            table.insert(stackedList, stackMap[k])
        end
    else
        -- Spawners déjà groupés côté serveur
        for _, item in ipairs(items) do
            table.insert(stackedList, {
                Name      = item.Rarity .. " Spawner",
                Rarity    = item.Rarity,
                PriceEach = item.PriceEach,
                Count     = item.Count,
            })
        end
    end

    if #stackedList == 0 then
        local empty = Instance.new("Frame")
        empty.Size             = UDim2.new(1, 0, 0, 40)
        empty.BackgroundTransparency = 1
        empty.LayoutOrder      = 1
        empty.Parent           = invScroll
        local lbl = Instance.new("TextLabel")
        lbl.Size              = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Text              = "Inventaire vide"
        lbl.TextColor3        = C.subtext
        lbl.Font              = Enum.Font.Gotham
        lbl.TextSize          = 13
        lbl.ZIndex            = 17
        lbl.Parent            = empty
        return
    end

    for idx, item in ipairs(stackedList) do
        local key         = npcType == "brainrot" and item.Name or item.Rarity
        local rarityColor = RARITY_COLORS[item.Rarity] or C.text
        local maxQty      = item.Count

        -- Initialiser la quantité à 0
        _quantities[key] = {
            qty       = 0,
            max       = maxQty,
            priceEach = item.PriceEach,
            name      = item.Name,
            rarity    = item.Rarity,
        }

        local ROW_H = 60
        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, 0, 0, ROW_H)
        row.BackgroundColor3 = C.itemBg
        row.BorderSizePixel  = 0
        row.LayoutOrder      = idx
        corner(row, 6)
        stroke(row, rarityColor, 1)
        row.Parent = invScroll

        -- ── Ligne haute ──────────────────────────────────────────────────────

        -- Nom (haut-gauche)
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size              = UDim2.new(1, -130, 0, 22)
        nameLabel.Position          = UDim2.new(0, 8, 0, 5)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text              = item.Name
        nameLabel.TextColor3        = C.text
        nameLabel.Font              = Enum.Font.GothamBold
        nameLabel.TextSize          = 13
        nameLabel.TextXAlignment    = Enum.TextXAlignment.Left
        nameLabel.ZIndex            = 2
        nameLabel.Parent            = row

        -- Total sélectionné (haut-droit, or)
        local totalLabel = Instance.new("TextLabel")
        totalLabel.Size              = UDim2.new(0, 118, 0, 22)
        totalLabel.Position          = UDim2.new(1, -126, 0, 5)
        totalLabel.BackgroundTransparency = 1
        totalLabel.Text              = "$0"
        totalLabel.TextColor3        = C.gold
        totalLabel.Font              = Enum.Font.GothamBold
        totalLabel.TextSize          = 13
        totalLabel.TextXAlignment    = Enum.TextXAlignment.Right
        totalLabel.ZIndex            = 2
        totalLabel.Parent            = row

        -- ── Ligne basse ──────────────────────────────────────────────────────

        -- Rareté (bas-gauche, coloré)
        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Size             = UDim2.new(0, 90, 0, 16)
        rarityLabel.Position         = UDim2.new(0, 8, 0, 33)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text             = item.Rarity
        rarityLabel.TextColor3       = rarityColor
        rarityLabel.Font             = Enum.Font.Gotham
        rarityLabel.TextSize         = 11
        rarityLabel.TextXAlignment   = Enum.TextXAlignment.Left
        rarityLabel.ZIndex           = 2
        rarityLabel.Parent           = row

        -- Possédé (bas-gauche après rareté)
        local ownedLabel = Instance.new("TextLabel")
        ownedLabel.Size              = UDim2.new(0, 100, 0, 16)
        ownedLabel.Position          = UDim2.new(0, 104, 0, 34)
        ownedLabel.BackgroundTransparency = 1
        ownedLabel.Text              = "×" .. maxQty .. " possédé" .. (maxQty > 1 and "s" or "")
        ownedLabel.TextColor3        = C.subtext
        ownedLabel.Font              = Enum.Font.Gotham
        ownedLabel.TextSize          = 11
        ownedLabel.TextXAlignment    = Enum.TextXAlignment.Left
        ownedLabel.ZIndex            = 2
        ownedLabel.Parent            = row

        -- Prix unitaire (bas, avant les contrôles)
        local priceEachLabel = Instance.new("TextLabel")
        priceEachLabel.Size              = UDim2.new(0, 80, 0, 16)
        priceEachLabel.Position          = UDim2.new(1, -212, 0, 34)
        priceEachLabel.BackgroundTransparency = 1
        priceEachLabel.Text              = string.format("$%d/u", item.PriceEach)
        priceEachLabel.TextColor3        = C.subtext
        priceEachLabel.Font              = Enum.Font.Gotham
        priceEachLabel.TextSize          = 11
        priceEachLabel.TextXAlignment    = Enum.TextXAlignment.Right
        priceEachLabel.ZIndex            = 2
        priceEachLabel.Parent            = row

        -- Bouton −
        local minusBtn = Instance.new("TextButton")
        minusBtn.Size             = UDim2.new(0, 26, 0, 24)
        minusBtn.Position         = UDim2.new(1, -122, 0, 29)
        minusBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
        minusBtn.Text             = "−"
        minusBtn.TextColor3       = Color3.new(1, 1, 1)
        minusBtn.Font             = Enum.Font.GothamBold
        minusBtn.TextSize         = 16
        minusBtn.AutoButtonColor  = false
        minusBtn.ZIndex           = 3
        corner(minusBtn, 4)
        minusBtn.Parent = row

        -- TextBox quantité
        local qtyBox = Instance.new("TextBox")
        qtyBox.Size             = UDim2.new(0, 44, 0, 24)
        qtyBox.Position         = UDim2.new(1, -94, 0, 29)
        qtyBox.BackgroundColor3 = C.panel
        qtyBox.Text             = "0"
        qtyBox.TextColor3       = C.text
        qtyBox.Font             = Enum.Font.GothamBold
        qtyBox.TextSize         = 13
        qtyBox.TextXAlignment   = Enum.TextXAlignment.Center
        qtyBox.ClearTextOnFocus = false
        qtyBox.ZIndex           = 3
        corner(qtyBox, 4)
        stroke(qtyBox, C.divider)
        qtyBox.Parent = row

        -- Bouton +
        local plusBtn = Instance.new("TextButton")
        plusBtn.Size             = UDim2.new(0, 26, 0, 24)
        plusBtn.Position         = UDim2.new(1, -48, 0, 29)
        plusBtn.BackgroundColor3 = Color3.fromRGB(30, 130, 60)
        plusBtn.Text             = "+"
        plusBtn.TextColor3       = Color3.new(1, 1, 1)
        plusBtn.Font             = Enum.Font.GothamBold
        plusBtn.TextSize         = 16
        plusBtn.AutoButtonColor  = false
        plusBtn.ZIndex           = 3
        corner(plusBtn, 4)
        plusBtn.Parent = row

        -- ── Logique quantité ─────────────────────────────────────────────────

        local function updateQty(newQty)
            newQty = math.clamp(math.floor(tonumber(newQty) or 0), 0, maxQty)
            _quantities[key].qty  = newQty
            qtyBox.Text           = tostring(newQty)
            totalLabel.Text       = string.format("$%d", newQty * item.PriceEach)
            row.BackgroundColor3  = newQty > 0 and C.hover or C.itemBg
            recalcTotal()
        end

        minusBtn.MouseButton1Click:Connect(function()
            updateQty(_quantities[key].qty - 1)
        end)

        plusBtn.MouseButton1Click:Connect(function()
            updateQty(_quantities[key].qty + 1)
        end)

        qtyBox.FocusLost:Connect(function()
            updateQty(qtyBox.Text)
        end)

        -- ── Item unique : remplacer les contrôles par un simple toggle ────────
        if maxQty == 1 then
            minusBtn.Visible = false
            qtyBox.Visible   = false
            plusBtn.Visible  = false

            -- Petite coche visuelle à droite
            local checkIcon = Instance.new("TextLabel")
            checkIcon.Size              = UDim2.new(0, 24, 0, 24)
            checkIcon.Position          = UDim2.new(1, -36, 0.5, -12)
            checkIcon.BackgroundColor3  = C.panel
            checkIcon.Text              = ""
            checkIcon.TextColor3        = C.green
            checkIcon.Font              = Enum.Font.GothamBold
            checkIcon.TextSize          = 16
            checkIcon.ZIndex            = 4
            corner(checkIcon, 4)
            stroke(checkIcon, rarityColor)
            checkIcon.Parent = row

            -- Bouton invisible sur toute la ligne pour toggle
            local hitBtn = Instance.new("TextButton")
            hitBtn.Size              = UDim2.fromScale(1, 1)
            hitBtn.BackgroundTransparency = 1
            hitBtn.Text              = ""
            hitBtn.ZIndex            = 5
            hitBtn.Parent            = row

            hitBtn.MouseButton1Click:Connect(function()
                local newQty = _quantities[key].qty == 0 and 1 or 0
                updateQty(newQty)
                checkIcon.Text = newQty == 1 and "✔" or ""
            end)
        end
    end
end

-- Ouvre l'UI d'inventaire de vente
local function openSellInventory()
    if not _currentConfig then return end
    local npcType = _currentConfig.NPCType

    invTitle.Text = "Choisir quoi vendre — " .. _currentConfig.Name

    -- Récupère l'inventaire depuis le serveur
    local items = fnGetInventory:InvokeServer(npcType)
    buildSellInventory(items or {}, npcType)
    invPanel.Visible = true
end

-- Déclenche une action de dialogue
local function triggerOption(action)
    if not _currentConfig then return end
    local npcType = _currentConfig.NPCType

    if action == "Close" then
        closeDialogue()
    elseif action == "SellHeld" then
        evSellHeld:FireServer(npcType)
    elseif action == "SellAll" then
        evSellAll:FireServer(npcType)
        closeDialogue()
    elseif action == "OpenSellUI" then
        openSellInventory()
    end
end

-- Connecte les boutons d'options
for i, data in ipairs(optionButtons) do
    data.btn.MouseButton1Click:Connect(function()
        if _currentConfig and _currentConfig.Options[i] then
            triggerOption(_currentConfig.Options[i].Action)
        end
    end)
end

-- Bouton OK de l'inventaire
invOKBtn.MouseButton1Click:Connect(function()
    if not _currentConfig then return end
    local npcType = _currentConfig.NPCType

    local hasQty = false
    for _, data in pairs(_quantities) do
        if data.qty > 0 then hasQty = true; break end
    end
    if not hasQty then
        showNotif("Aucune quantité sélectionnée.", C.red)
        return
    end

    if npcType == "brainrot" then
        -- Envoyer le nom une fois par unité (SellSelectedBrainrots attend une liste de noms)
        local names = {}
        for _, data in pairs(_quantities) do
            for _ = 1, data.qty do
                table.insert(names, data.name)
            end
        end
        evSellItems:FireServer(npcType, names)
    else
        local rarityList = {}
        for _, data in pairs(_quantities) do
            if data.qty > 0 then
                table.insert(rarityList, { rarity = data.rarity, count = data.qty })
            end
        end
        evSellItems:FireServer(npcType, rarityList)
    end

    closeInvPanel()
end)

-- ─── Affichage du dialogue ────────────────────────────────────────────────────

local function openDialogue(npcId)
    local config = NPCDialogueConfig[npcId]
    if not config then return end

    _currentNPCId  = npcId
    _currentConfig = config

    dialNPCName.Text = "💬  " .. config.Name
    dialIntro.Text   = config.Intro

    for i, optData in ipairs(optionButtons) do
        local opt = config.Options[i]
        if opt then
            optData.label.Text  = opt.Label
            optData.row.Visible = true
        else
            optData.row.Visible = false
        end
    end

    dialoguePanel.Visible = true
    invPanel.Visible      = false
end

-- ─── Résultat d'une vente ─────────────────────────────────────────────────────

evSellResult.OnClientEvent:Connect(function(success, money, message)
    showNotif(message, success and C.green or C.red)
end)

-- ─── Ouverture depuis le serveur ──────────────────────────────────────────────

evOpenDialogue.OnClientEvent:Connect(function(npcId)
    openDialogue(npcId)
end)

-- ─── Raccourcis clavier 1-4 ──────────────────────────────────────────────────

local KEY_MAP = {
    [Enum.KeyCode.One]   = 1,
    [Enum.KeyCode.Two]   = 2,
    [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four]  = 4,
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not dialoguePanel.Visible then return end
    local idx = KEY_MAP[input.KeyCode]
    if idx and _currentConfig and _currentConfig.Options[idx] then
        triggerOption(_currentConfig.Options[idx].Action)
    end
end)

-- ─── Fermeture automatique si le joueur se déplace ───────────────────────────

RunService.Heartbeat:Connect(function()
    if not dialoguePanel.Visible then return end
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.MoveDirection.Magnitude > 0 then
        closeDialogue()
    end
end)
