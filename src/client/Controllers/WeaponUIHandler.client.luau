--[[
    WeaponUIHandler - UI boutique d'armes + détection de frappe + cooldown

    Flux :
      ProximityPrompt E sur WeaponPNJ → OpenNPCDialogue("WeaponPNJ") → shop UI
      Tool.Activated → détection cible → WeaponSwing (→ serveur)
      Indicateur de cooldown local (feedback visuel uniquement)
      Notification d'entrée/sortie zone PvP
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = workspace.CurrentCamera

local WeaponConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponConfig"))

local ev = ReplicatedStorage:WaitForChild("RemoteInterface"):WaitForChild("Events")
local fn = ReplicatedStorage:WaitForChild("RemoteInterface"):WaitForChild("Functions")

local evOpenDialogue  = ev:WaitForChild("OpenNPCDialogue")
local evBuy           = ev:WaitForChild("WeaponBuy")
local evEquip         = ev:WaitForChild("WeaponEquip")
local evSwing         = ev:WaitForChild("WeaponSwing")
local evBuyResult     = ev:WaitForChild("WeaponBuyResult")
local fnGetShopData   = fn:WaitForChild("WeaponGetShopData")

-- ─── Couleurs ────────────────────────────────────────────────────────────────

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
    gray    = Color3.fromRGB(80,  85,  100),
}

local RARITY_COLORS = {
    Common    = Color3.fromRGB(180, 180, 180),
    Uncommon  = Color3.fromRGB(80,  210, 80),
    Rare      = Color3.fromRGB(80,  140, 255),
    Epic      = Color3.fromRGB(180, 80,  255),
    Legendary = Color3.fromRGB(255, 175, 30),
}

-- ─── Helpers UI ──────────────────────────────────────────────────────────────

local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = p
end
local function stroke(p, col, t)
    local s = Instance.new("UIStroke"); s.Color = col or C.divider; s.Thickness = t or 1; s.Parent = p
end
local function padding(p, v)
    local u = Instance.new("UIPadding")
    u.PaddingLeft = UDim.new(0,v); u.PaddingRight  = UDim.new(0,v)
    u.PaddingTop  = UDim.new(0,v); u.PaddingBottom = UDim.new(0,v)
    u.Parent = p
end

-- ─── Main ScreenGui ──────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name           = "WeaponUI"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = playerGui

-- ─── Notification ─────────────────────────────────────────────────────────────

local notifFrame = Instance.new("Frame")
notifFrame.Size             = UDim2.new(0, 380, 0, 48)
notifFrame.Position         = UDim2.new(0.5, -190, 0, -60)
notifFrame.BackgroundColor3 = C.panel
notifFrame.BorderSizePixel  = 0
notifFrame.Visible          = false
notifFrame.ZIndex           = 30
corner(notifFrame, 8); stroke(notifFrame, C.accent)
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

local function showNotif(msg, color)
    notifLabel.Text = msg
    local s = notifFrame:FindFirstChildOfClass("UIStroke")
    if s then s.Color = color or C.accent end
    notifFrame.Visible  = true
    notifFrame.Position = UDim2.new(0.5, -190, 0, -60)
    TweenService:Create(notifFrame, TweenInfo.new(0.25), { Position = UDim2.new(0.5, -190, 0, 70) }):Play()
    task.delay(2.5, function()
        local t = TweenService:Create(notifFrame, TweenInfo.new(0.25), { Position = UDim2.new(0.5, -190, 0, -60) })
        t:Play(); t.Completed:Connect(function() notifFrame.Visible = false end)
    end)
end

-- ─── Cooldown indicator ───────────────────────────────────────────────────────

local cdFrame = Instance.new("Frame")
cdFrame.Size             = UDim2.new(0, 160, 0, 36)
cdFrame.Position         = UDim2.new(0.5, -80, 1, -160)
cdFrame.BackgroundColor3 = C.panel
cdFrame.BorderSizePixel  = 0
cdFrame.Visible          = false
cdFrame.ZIndex           = 20
corner(cdFrame, 6); stroke(cdFrame, C.divider)
cdFrame.Parent = gui

local cdBar = Instance.new("Frame")
cdBar.Size             = UDim2.new(1, 0, 1, 0)
cdBar.BackgroundColor3 = C.green
cdBar.BorderSizePixel  = 0
cdBar.ZIndex           = 21
corner(cdBar, 6)
cdBar.Parent = cdFrame

local cdLabel = Instance.new("TextLabel")
cdLabel.Size              = UDim2.new(1, 0, 1, 0)
cdLabel.BackgroundTransparency = 1
cdLabel.Text              = "⚡ Prêt"
cdLabel.TextColor3        = Color3.new(1,1,1)
cdLabel.Font              = Enum.Font.GothamBold
cdLabel.TextSize          = 13
cdLabel.TextXAlignment    = Enum.TextXAlignment.Center
cdLabel.ZIndex            = 22
cdLabel.Parent            = cdFrame

-- ─── PvP Zone indicator ───────────────────────────────────────────────────────

local pvpBadge = Instance.new("Frame")
pvpBadge.Size             = UDim2.new(0, 140, 0, 30)
pvpBadge.Position         = UDim2.new(0.5, -70, 0, 16)
pvpBadge.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
pvpBadge.BorderSizePixel  = 0
pvpBadge.Visible          = false
pvpBadge.ZIndex           = 20
corner(pvpBadge, 6)
pvpBadge.Parent = gui

local pvpLabel = Instance.new("TextLabel")
pvpLabel.Size              = UDim2.new(1, 0, 1, 0)
pvpLabel.BackgroundTransparency = 1
pvpLabel.Text              = "⚔  Zone PvP"
pvpLabel.TextColor3        = Color3.new(1,1,1)
pvpLabel.Font              = Enum.Font.GothamBold
pvpLabel.TextSize          = 13
pvpLabel.TextXAlignment    = Enum.TextXAlignment.Center
pvpLabel.ZIndex            = 21
pvpLabel.Parent            = pvpBadge

-- ─── Weapon Shop UI ──────────────────────────────────────────────────────────

local SHOP_W, SHOP_H = 520, 500
local shopPanel = Instance.new("Frame")
shopPanel.Name             = "WeaponShop"
shopPanel.Size             = UDim2.new(0, SHOP_W, 0, SHOP_H)
shopPanel.Position         = UDim2.new(0.5, -SHOP_W/2, 0.5, -SHOP_H/2)
shopPanel.BackgroundColor3 = C.bg
shopPanel.BorderSizePixel  = 0
shopPanel.Visible          = false
shopPanel.ZIndex           = 15
corner(shopPanel, 12); stroke(shopPanel, C.divider, 2)
shopPanel.Parent = gui

-- Header
local shopHeader = Instance.new("Frame")
shopHeader.Size             = UDim2.new(1, 0, 0, 52)
shopHeader.BackgroundColor3 = C.header
shopHeader.BorderSizePixel  = 0
shopHeader.ZIndex           = 16
corner(shopHeader, 12)
shopHeader.Parent = shopPanel

local shopTitle = Instance.new("TextLabel")
shopTitle.Size              = UDim2.new(1, -60, 1, 0)
shopTitle.Position          = UDim2.new(0, 14, 0, 0)
shopTitle.BackgroundTransparency = 1
shopTitle.Text              = "⚔  Armurerie"
shopTitle.TextColor3        = C.text
shopTitle.Font              = Enum.Font.GothamBold
shopTitle.TextSize          = 16
shopTitle.TextXAlignment    = Enum.TextXAlignment.Left
shopTitle.ZIndex            = 17
shopTitle.Parent            = shopHeader

local shopCloseBtn = Instance.new("TextButton")
shopCloseBtn.Size             = UDim2.new(0, 30, 0, 30)
shopCloseBtn.Position         = UDim2.new(1, -40, 0.5, -15)
shopCloseBtn.BackgroundColor3 = Color3.fromRGB(130, 30, 30)
shopCloseBtn.Text             = "✕"
shopCloseBtn.TextColor3       = Color3.new(1,1,1)
shopCloseBtn.Font             = Enum.Font.GothamBold
shopCloseBtn.TextSize         = 14
shopCloseBtn.ZIndex           = 17
corner(shopCloseBtn, 6)
shopCloseBtn.Parent = shopHeader

-- Money display
local moneyBar = Instance.new("Frame")
moneyBar.Size             = UDim2.new(1, 0, 0, 32)
moneyBar.Position         = UDim2.new(0, 0, 0, 52)
moneyBar.BackgroundColor3 = C.panel
moneyBar.BorderSizePixel  = 0
moneyBar.ZIndex           = 16
moneyBar.Parent           = shopPanel

local moneyLabel = Instance.new("TextLabel")
moneyLabel.Size              = UDim2.new(1, -16, 1, 0)
moneyLabel.Position          = UDim2.new(0, 8, 0, 0)
moneyLabel.BackgroundTransparency = 1
moneyLabel.Text              = "💰  $0"
moneyLabel.TextColor3        = C.gold
moneyLabel.Font              = Enum.Font.GothamBold
moneyLabel.TextSize          = 13
moneyLabel.TextXAlignment    = Enum.TextXAlignment.Right
moneyLabel.ZIndex            = 17
moneyLabel.Parent            = moneyBar

-- Scroll list
local shopScroll = Instance.new("ScrollingFrame")
shopScroll.Position              = UDim2.new(0, 12, 0, 92)
shopScroll.Size                  = UDim2.new(1, -24, 0, SHOP_H - 110)
shopScroll.BackgroundTransparency = 1
shopScroll.BorderSizePixel       = 0
shopScroll.ScrollBarThickness    = 4
shopScroll.ScrollBarImageColor3  = C.accent
shopScroll.CanvasSize            = UDim2.new(0,0,0,0)
shopScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
shopScroll.ZIndex                = 16
shopScroll.Parent                = shopPanel

local shopLayout = Instance.new("UIListLayout")
shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopLayout.Padding   = UDim.new(0, 6)
shopLayout.Parent    = shopScroll

-- ─── State ────────────────────────────────────────────────────────────────────

local _lastSwing      = 0
local _weaponEquipped = false   -- outil arme dans les mains
local _inPVPZone      = false
local _pvpZonePart    = nil
local _playerMoney    = 0

-- ─── PvP zone detection (client-side, for UI only) ───────────────────────────

local function findPVPZone()
    local folder = workspace:FindFirstChild(WeaponConfig.PVPFolder)
    if folder then
        _pvpZonePart = folder:FindFirstChild(WeaponConfig.PVPPartName)
    end
end

local function isInZone(pos)
    if not _pvpZonePart then return false end
    local lp = _pvpZonePart.CFrame:PointToObjectSpace(pos)
    local s  = _pvpZonePart.Size
    return math.abs(lp.X) <= s.X/2 and math.abs(lp.Y) <= s.Y/2 and math.abs(lp.Z) <= s.Z/2
end

-- ─── Shop building ────────────────────────────────────────────────────────────

local function buildShop(items)
    for _, child in ipairs(shopScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for idx, item in ipairs(items) do
        local rColor = RARITY_COLORS[item.Rarity] or C.text

        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, 0, 0, 76)
        row.BackgroundColor3 = C.itemBg
        row.BorderSizePixel  = 0
        row.LayoutOrder      = idx
        corner(row, 8); stroke(row, rColor, 1)
        row.Parent = shopScroll

        -- Bande rareté à gauche
        local band = Instance.new("Frame")
        band.Size             = UDim2.new(0, 6, 1, 0)
        band.BackgroundColor3 = rColor
        band.BorderSizePixel  = 0
        corner(band, 3)
        band.Parent = row

        -- Nom
        local nameL = Instance.new("TextLabel")
        nameL.Size              = UDim2.new(0, 200, 0, 24)
        nameL.Position          = UDim2.new(0, 16, 0, 8)
        nameL.BackgroundTransparency = 1
        nameL.Text              = "Baseball Bat — " .. item.Rarity
        nameL.TextColor3        = rColor
        nameL.Font              = Enum.Font.GothamBold
        nameL.TextSize          = 14
        nameL.TextXAlignment    = Enum.TextXAlignment.Left
        nameL.ZIndex            = 2
        nameL.Parent            = row

        -- Stats
        local statsL = Instance.new("TextLabel")
        statsL.Size              = UDim2.new(0, 260, 0, 18)
        statsL.Position          = UDim2.new(0, 16, 0, 34)
        statsL.BackgroundTransparency = 1
        statsL.Text              = string.format("Knockback: %d  •  Ragdoll: %.1fs",
                                       item.Knockback, item.Duration)
        statsL.TextColor3        = C.subtext
        statsL.Font              = Enum.Font.Gotham
        statsL.TextSize          = 11
        statsL.TextXAlignment    = Enum.TextXAlignment.Left
        statsL.ZIndex            = 2
        statsL.Parent            = row

        -- Prix
        local priceL = Instance.new("TextLabel")
        priceL.Size              = UDim2.new(0, 100, 0, 20)
        priceL.Position          = UDim2.new(0, 16, 0, 54)
        priceL.BackgroundTransparency = 1
        priceL.Text              = string.format("$%d", item.Price)
        priceL.TextColor3        = C.gold
        priceL.Font              = Enum.Font.GothamBold
        priceL.TextSize          = 13
        priceL.TextXAlignment    = Enum.TextXAlignment.Left
        priceL.ZIndex            = 2
        priceL.Parent            = row

        -- Bouton action (droite)
        local actionBtn = Instance.new("TextButton")
        actionBtn.Size             = UDim2.new(0, 110, 0, 34)
        actionBtn.Position         = UDim2.new(1, -124, 0.5, -17)
        actionBtn.Font             = Enum.Font.GothamBold
        actionBtn.TextSize         = 13
        actionBtn.TextColor3       = Color3.new(1,1,1)
        actionBtn.AutoButtonColor  = false
        actionBtn.ZIndex           = 3
        corner(actionBtn, 8)
        actionBtn.Parent = row

        if item.Equipped then
            -- Actuellement équipée
            actionBtn.Text             = "✔  Équipée"
            actionBtn.BackgroundColor3 = Color3.fromRGB(30, 100, 50)
            actionBtn.Active           = false
        elseif item.Owned then
            -- Possédée mais pas équipée
            actionBtn.Text             = "Équiper"
            actionBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 180)
            actionBtn.MouseButton1Click:Connect(function()
                evEquip:FireServer(item.Rarity)
                showNotif("Batte " .. item.Rarity .. " équipée !", C.accent)
                shopPanel.Visible = false
            end)
        else
            -- Pas encore possédée
            local canAfford = _playerMoney >= item.Price
            actionBtn.Text             = "Acheter"
            actionBtn.BackgroundColor3 = canAfford and Color3.fromRGB(25, 120, 55)
                                                    or  C.gray
            if canAfford then
                actionBtn.MouseButton1Click:Connect(function()
                    evBuy:FireServer(item.Rarity)
                end)
            end

            -- Hover
            actionBtn.MouseEnter:Connect(function()
                if canAfford then
                    actionBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 70)
                end
            end)
            actionBtn.MouseLeave:Connect(function()
                actionBtn.BackgroundColor3 = canAfford and Color3.fromRGB(25, 120, 55)
                                                        or  C.gray
            end)
        end
    end
end

local function openShop()
    moneyLabel.Text = string.format("💰  $%d", _playerMoney)
    local items = fnGetShopData:InvokeServer()
    if items then
        buildShop(items)
    end
    shopPanel.Visible = true
end

shopCloseBtn.MouseButton1Click:Connect(function()
    shopPanel.Visible = false
end)

-- ─── Swing detection ──────────────────────────────────────────────────────────

-- Feedback visuel du cooldown uniquement (la frappe est détectée server-side via Touched)
local function handleSwing()
    local now = tick()
    if now - _lastSwing < WeaponConfig.Cooldown then return end
    _lastSwing = now

    cdBar.Size         = UDim2.new(0, 0, 1, 0)
    cdLabel.Text       = "⏳ Cooldown"
    cdLabel.TextColor3 = C.gold
    TweenService:Create(cdBar, TweenInfo.new(WeaponConfig.Cooldown, Enum.EasingStyle.Linear),
        { Size = UDim2.new(1, 0, 1, 0) }):Play()
    task.delay(WeaponConfig.Cooldown, function()
        cdLabel.Text       = "⚡ Prêt"
        cdLabel.TextColor3 = Color3.new(1,1,1)
    end)
end

-- ─── Tool tracking ────────────────────────────────────────────────────────────

local _swingConn = nil

local function onCharacterAdded(chr)
    chr.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child:GetAttribute("IsWeapon") then
            _weaponEquipped = true
            cdFrame.Visible = true
            if _swingConn then _swingConn:Disconnect() end
            _swingConn = child.Activated:Connect(handleSwing)
        end
    end)
    chr.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") and child:GetAttribute("IsWeapon") then
            _weaponEquipped = false
            cdFrame.Visible = false
            if _swingConn then _swingConn:Disconnect(); _swingConn = nil end
        end
    end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

-- ─── PvP zone update + badge ─────────────────────────────────────────────────

findPVPZone()

RunService.Heartbeat:Connect(function()
    local chr = player.Character
    if not chr then return end
    local hrp = chr:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local wasIn = _inPVPZone
    _inPVPZone  = isInZone(hrp.Position)
    pvpBadge.Visible = _inPVPZone

    if _inPVPZone and not wasIn then
        showNotif("⚔  Vous entrez dans la zone PvP !", Color3.fromRGB(220, 60, 60))
    elseif not _inPVPZone and wasIn then
        showNotif("✅  Vous quittez la zone PvP.", C.green)
    end
end)

-- ─── Events ──────────────────────────────────────────────────────────────────

-- Ouvrir la boutique quand le PNJ est activé
evOpenDialogue.OnClientEvent:Connect(function(npcId)
    if npcId == "WeaponPNJ" then
        openShop()
    end
end)

-- Résultat d'un achat
evBuyResult.OnClientEvent:Connect(function(success, msg)
    if success then
        showNotif("✔  " .. (msg or "Achat réussi !"), C.green)
        -- Rafraîchir la boutique si elle est ouverte
        if shopPanel.Visible then
            local items = fnGetShopData:InvokeServer()
            if items then buildShop(items) end
        end
    else
        showNotif("✖  " .. (msg or "Achat refusé."), C.red)
    end
end)

-- Mise à jour de l'argent (depuis OnMoneyChanged existant)
ev:WaitForChild("OnMoneyChanged").OnClientEvent:Connect(function(newMoney)
    _playerMoney = newMoney
    moneyLabel.Text = string.format("💰  $%d", _playerMoney)
end)
