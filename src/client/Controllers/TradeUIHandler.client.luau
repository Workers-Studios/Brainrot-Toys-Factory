--[[
	TradeUIHandler - Client-side UI for the player-to-player trade system

	Panels:
	  1. Trade HUD button (top-left, below teleport bar)
	  2. Player List panel (lists online players with "Trade" button)
	  3. Invite popup (Accept / Decline incoming invite)
	  4. Trade window (my offer | their offer, money input, tax, confirm/cancel)
	  5. Brainrot selector overlay (pick from available brainrots)
	  6. Timer overlay (3-second countdown when both confirmed)

	All UI is created programmatically — no pre-existing ScreenGui required.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ev = ReplicatedStorage
	:WaitForChild("RemoteInterface")
	:WaitForChild("Events")

local evSendRequest     = ev:WaitForChild("SendTradeRequest")
local evInviteReceived  = ev:WaitForChild("TradeInviteReceived")
local evInviteResponse  = ev:WaitForChild("TradeInviteResponse")
local evInviteDeclined  = ev:WaitForChild("TradeInviteDeclined")
local evAddBrainrot     = ev:WaitForChild("TradeAddBrainrot")
local evRemoveBrainrot  = ev:WaitForChild("TradeRemoveBrainrot")
local evSetMoney        = ev:WaitForChild("TradeSetMoney")
local evConfirm         = ev:WaitForChild("TradeConfirm")
local evCancel          = ev:WaitForChild("TradeCancel")
local evStateUpdate     = ev:WaitForChild("TradeStateUpdate")

-- ─── State ────────────────────────────────────────────────────────────────────

local _tradeState   = nil   -- last packet from TradeStateUpdate
local _timerConn    = nil   -- RenderStepped connection for countdown

-- ─── Color Palette ────────────────────────────────────────────────────────────

local C = {
	bg        = Color3.fromRGB(18,  20,  28),
	panel     = Color3.fromRGB(28,  32,  44),
	header    = Color3.fromRGB(38,  44,  62),
	accent    = Color3.fromRGB(80,  160, 255),
	accentDim = Color3.fromRGB(40,  80,  160),
	green     = Color3.fromRGB(50,  200, 100),
	greenDim  = Color3.fromRGB(25,  110, 55),
	red       = Color3.fromRGB(220, 60,  60),
	redDim    = Color3.fromRGB(130, 30,  30),
	gold      = Color3.fromRGB(255, 200, 50),
	text      = Color3.fromRGB(230, 230, 240),
	subtext   = Color3.fromRGB(150, 155, 175),
	divider   = Color3.fromRGB(50,  56,  75),
	itemBg    = Color3.fromRGB(35,  40,  56),
	itemHover = Color3.fromRGB(48,  55,  78),
}

local RARITY_COLORS = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(80,  210, 80),
	Rare      = Color3.fromRGB(80,  140, 255),
	Epic      = Color3.fromRGB(180, 80,  255),
	Legendary = Color3.fromRGB(255, 175, 30),
}

-- ─── UI Helpers ───────────────────────────────────────────────────────────────

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or C.divider
	s.Thickness = thickness or 1
	s.Parent = parent
end

local function label(parent, text, x, y, w, h, size, color, font, align)
	local l = Instance.new("TextLabel")
	l.Position     = UDim2.new(0, x, 0, y)
	l.Size         = UDim2.new(0, w, 0, h)
	l.BackgroundTransparency = 1
	l.Text         = text
	l.TextColor3   = color or C.text
	l.Font         = font  or Enum.Font.GothamBold
	l.TextSize     = size  or 14
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Parent       = parent
	return l
end

local function btn(parent, text, x, y, w, h, bg, hoverBg, textColor)
	local b = Instance.new("TextButton")
	b.Position        = UDim2.new(0, x, 0, y)
	b.Size            = UDim2.new(0, w, 0, h)
	b.BackgroundColor3 = bg or C.accent
	b.BorderSizePixel = 0
	b.Text            = text
	b.TextColor3      = textColor or Color3.new(1,1,1)
	b.Font            = Enum.Font.GothamBold
	b.TextSize        = 13
	b.AutoButtonColor = false
	corner(b, 6)
	b.Parent          = parent

	local _hov = hoverBg or bg
	b.MouseEnter:Connect(function()  b.BackgroundColor3 = _hov end)
	b.MouseLeave:Connect(function() b.BackgroundColor3 = bg   end)
	return b
end

local function scrollFrame(parent, x, y, w, h)
	local sf = Instance.new("ScrollingFrame")
	sf.Position              = UDim2.new(0, x, 0, y)
	sf.Size                  = UDim2.new(0, w, 0, h)
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel       = 0
	sf.ScrollBarThickness    = 4
	sf.ScrollBarImageColor3  = C.accent
	sf.CanvasSize            = UDim2.new(0, 0, 0, 0)
	sf.AutomaticCanvasSize   = Enum.AutomaticSize.Y
	sf.Parent                = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder  = Enum.SortOrder.LayoutOrder
	layout.Padding    = UDim.new(0, 4)
	layout.Parent     = sf
	return sf
end

-- ─── ScreenGui ────────────────────────────────────────────────────────────────

local gui             = Instance.new("ScreenGui")
gui.Name              = "TradeUI"
gui.ResetOnSpawn      = false
gui.IgnoreGuiInset    = true
gui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
gui.Parent            = playerGui

-- ─── Notification Banner ──────────────────────────────────────────────────────

local notifFrame = Instance.new("Frame")
notifFrame.Name              = "Notif"
notifFrame.Size              = UDim2.new(0, 340, 0, 44)
notifFrame.Position          = UDim2.new(0.5, -170, 0, -60)
notifFrame.BackgroundColor3  = C.panel
notifFrame.BorderSizePixel   = 0
notifFrame.Visible           = false
notifFrame.ZIndex            = 20
corner(notifFrame, 8)
stroke(notifFrame, C.accent)
notifFrame.Parent = gui

local notifLabel = Instance.new("TextLabel")
notifLabel.Size              = UDim2.fromScale(1, 1)
notifLabel.BackgroundTransparency = 1
notifLabel.TextColor3        = C.text
notifLabel.Font              = Enum.Font.Gotham
notifLabel.TextSize          = 13
notifLabel.ZIndex            = 21
notifLabel.Parent            = notifFrame

local _notifTween = nil
local function showNotif(msg, color)
	if _notifTween then _notifTween:Cancel() end
	notifLabel.Text = msg
	notifFrame.BackgroundColor3 = C.panel
	stroke(notifFrame, color or C.accent)
	notifFrame.Visible = true
	notifFrame.Position = UDim2.new(0.5, -170, 0, -60)

	local tweenIn = TweenService:Create(notifFrame,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -170, 0, 80) })
	tweenIn:Play()
	tweenIn.Completed:Connect(function()
		task.wait(2.5)
		local tweenOut = TweenService:Create(notifFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, -170, 0, -60) })
		tweenOut:Play()
		tweenOut.Completed:Connect(function() notifFrame.Visible = false end)
	end)
end

-- ─── Trade HUD Button ────────────────────────────────────────────────────────

local tradeBtnFrame = Instance.new("Frame")
tradeBtnFrame.Name             = "TradeHUDBtn"
tradeBtnFrame.Size             = UDim2.new(0, 110, 0, 34)
tradeBtnFrame.Position         = UDim2.new(0, 12, 0, 118)  -- left side, below teleport area
tradeBtnFrame.BackgroundTransparency = 1
tradeBtnFrame.Parent           = gui

local tradeHUDBtn = btn(tradeBtnFrame, "🤝 Trade", 0, 0, 110, 34, C.accentDim, C.accent)

-- ─── Player List Panel ────────────────────────────────────────────────────────

local playerListPanel = Instance.new("Frame")
playerListPanel.Name             = "PlayerList"
playerListPanel.Size             = UDim2.new(0, 280, 0, 360)
playerListPanel.Position         = UDim2.new(0, 12, 0, 158)
playerListPanel.BackgroundColor3 = C.bg
playerListPanel.BorderSizePixel  = 0
playerListPanel.Visible          = false
playerListPanel.ZIndex           = 5
corner(playerListPanel, 10)
stroke(playerListPanel, C.divider)
playerListPanel.Parent = gui

-- Header
local plHeader = Instance.new("Frame")
plHeader.Size            = UDim2.new(1, 0, 0, 44)
plHeader.BackgroundColor3 = C.header
plHeader.BorderSizePixel = 0
corner(plHeader, 10)
plHeader.ZIndex = 6
plHeader.Parent = playerListPanel
label(plHeader, "👥  Players Online", 14, 0, 200, 44, 14, C.text, Enum.Font.GothamBold, Enum.TextXAlignment.Left).ZIndex = 7

local plCloseBtn = btn(plHeader, "✕", 248, 10, 24, 24, C.redDim, C.red)
plCloseBtn.ZIndex = 7

-- Scroll area
local plScroll = scrollFrame(playerListPanel, 8, 52, 264, 300)
plScroll.ZIndex = 6

-- Populate list
local function refreshPlayerList()
	for _, child in ipairs(plScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local allPlayers = Players:GetPlayers()
	for _, p in ipairs(allPlayers) do
		if p == player then continue end

		local row = Instance.new("Frame")
		row.Size             = UDim2.new(1, 0, 0, 40)
		row.BackgroundColor3 = C.itemBg
		row.BorderSizePixel  = 0
		row.LayoutOrder      = 1
		corner(row, 6)
		row.Parent = plScroll

		label(row, p.Name, 10, 0, 160, 40, 13, C.text)
		local tradeBtn2 = btn(row, "Trade", 178, 6, 72, 28, C.accentDim, C.accent)
		tradeBtn2.MouseButton1Click:Connect(function()
			evSendRequest:FireServer(p.UserId)
			showNotif("Trade request sent to " .. p.Name, C.accent)
			playerListPanel.Visible = false
		end)
	end
end

tradeHUDBtn.MouseButton1Click:Connect(function()
	local visible = not playerListPanel.Visible
	playerListPanel.Visible = visible
	if visible then refreshPlayerList() end
end)

plCloseBtn.MouseButton1Click:Connect(function()
	playerListPanel.Visible = false
end)

Players.PlayerAdded:Connect(function()
	if playerListPanel.Visible then refreshPlayerList() end
end)
Players.PlayerRemoving:Connect(function()
	if playerListPanel.Visible then refreshPlayerList() end
end)

-- ─── Invite Popup ─────────────────────────────────────────────────────────────

local invitePopup = Instance.new("Frame")
invitePopup.Name             = "InvitePopup"
invitePopup.Size             = UDim2.new(0, 380, 0, 155)
invitePopup.Position         = UDim2.new(0.5, -190, 0.5, -77)
invitePopup.BackgroundColor3 = C.bg
invitePopup.BorderSizePixel  = 0
invitePopup.Visible          = false
invitePopup.ZIndex           = 15
corner(invitePopup, 12)
stroke(invitePopup, C.accent, 2)
invitePopup.Parent = gui

label(invitePopup, "🤝  Trade Invite", 20, 14, 300, 24, 15, C.accent, Enum.Font.GothamBold).ZIndex = 16

local inviteMsg = label(invitePopup, "", 20, 46, 340, 36, 13, C.text, Enum.Font.Gotham)
inviteMsg.TextWrapped = true
inviteMsg.ZIndex = 16

local inviteAccept  = btn(invitePopup, "✔  Accept",  20,  100, 160, 36, C.greenDim, C.green)
local inviteDecline = btn(invitePopup, "✕  Decline", 198, 100, 160, 36, C.redDim,   C.red)
inviteAccept.ZIndex  = 16
inviteDecline.ZIndex = 16

inviteAccept.MouseButton1Click:Connect(function()
	evInviteResponse:FireServer(true)
	invitePopup.Visible = false
end)
inviteDecline.MouseButton1Click:Connect(function()
	evInviteResponse:FireServer(false)
	invitePopup.Visible = false
end)

-- ─── Trade Window ─────────────────────────────────────────────────────────────

local WIN_W, WIN_H = 740, 510
local tradeWindow = Instance.new("Frame")
tradeWindow.Name             = "TradeWindow"
tradeWindow.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
tradeWindow.Position         = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
tradeWindow.BackgroundColor3 = C.bg
tradeWindow.BorderSizePixel  = 0
tradeWindow.Visible          = false
tradeWindow.ZIndex           = 10
corner(tradeWindow, 12)
stroke(tradeWindow, C.divider, 2)
tradeWindow.Parent = gui

-- Header
local twHeader = Instance.new("Frame")
twHeader.Size             = UDim2.new(1, 0, 0, 50)
twHeader.BackgroundColor3 = C.header
twHeader.BorderSizePixel  = 0
corner(twHeader, 12)
twHeader.ZIndex = 11
twHeader.Parent = tradeWindow

local twTitle = label(twHeader, "🤝  Trade", 18, 0, 500, 50, 15, C.text, Enum.Font.GothamBold)
twTitle.ZIndex = 12

local twCloseBtn = btn(twHeader, "✕", WIN_W - 46, 12, 28, 28, C.redDim, C.red)
twCloseBtn.ZIndex = 12
twCloseBtn.MouseButton1Click:Connect(function()
	evCancel:FireServer()
end)

-- Divider line between header and content
local divLine = Instance.new("Frame")
divLine.Size             = UDim2.new(1, -36, 0, 1)
divLine.Position         = UDim2.new(0, 18, 0, 50)
divLine.BackgroundColor3 = C.divider
divLine.BorderSizePixel  = 0
divLine.ZIndex           = 11
divLine.Parent           = tradeWindow

-- ── Column layout ──────────────────────────────────────────────────────────────
-- Left col: MY OFFER  |  divider  |  Right col: THEIR OFFER
local COL_W  = 320
local COL_Y  = 58
local COL_H  = 350
local LEFT_X = 18
local MID_X  = LEFT_X + COL_W + 10  -- 348
local RIGHT_X = MID_X + 4

-- Column labels
local myColLabel    = label(tradeWindow, "YOUR OFFER", LEFT_X, COL_Y, COL_W, 22, 12, C.accent)
myColLabel.ZIndex   = 11
local theirColLabel = label(tradeWindow, "THEIR OFFER", RIGHT_X, COL_Y, COL_W, 22, 12, C.subtext)
theirColLabel.ZIndex = 11

-- Middle divider
local midDiv = Instance.new("Frame")
midDiv.Size             = UDim2.new(0, 1, 0, COL_H + 40)
midDiv.Position         = UDim2.new(0, MID_X, 0, COL_Y)
midDiv.BackgroundColor3 = C.divider
midDiv.BorderSizePixel  = 0
midDiv.ZIndex           = 11
midDiv.Parent           = tradeWindow

-- MY brainrots list
local myBrainrotScroll = scrollFrame(tradeWindow, LEFT_X, COL_Y + 26, COL_W, 200)
myBrainrotScroll.ZIndex = 11
myBrainrotScroll.BackgroundColor3 = C.panel
myBrainrotScroll.BackgroundTransparency = 0
corner(myBrainrotScroll, 6)

-- Add brainrot button
local addBrainrotBtn = btn(tradeWindow, "+ Add Brainrot", LEFT_X, COL_Y + 232, COL_W, 30, C.accentDim, C.accent)
addBrainrotBtn.ZIndex = 11

-- MY money input row
label(tradeWindow, "Offer $:", LEFT_X, COL_Y + 270, 70, 28, 13, C.subtext).ZIndex = 11

local myMoneyBox = Instance.new("TextBox")
myMoneyBox.Position          = UDim2.new(0, LEFT_X + 76, 0, COL_Y + 270)
myMoneyBox.Size              = UDim2.new(0, 160, 0, 28)
myMoneyBox.BackgroundColor3  = C.itemBg
myMoneyBox.BorderSizePixel   = 0
myMoneyBox.Text              = "0"
myMoneyBox.TextColor3        = C.text
myMoneyBox.Font              = Enum.Font.GothamBold
myMoneyBox.TextSize          = 13
myMoneyBox.ClearTextOnFocus  = true
myMoneyBox.ZIndex            = 11
corner(myMoneyBox, 6)
stroke(myMoneyBox, C.divider)
myMoneyBox.Parent = tradeWindow

local setMoneyBtn = btn(tradeWindow, "Set", LEFT_X + 242, COL_Y + 270, 72, 28, C.accentDim, C.accent)
setMoneyBtn.ZIndex = 11

-- MY confirmed indicator
local myConfirmedLabel = label(tradeWindow, "", LEFT_X, COL_Y + 306, COL_W, 22, 12, C.subtext)
myConfirmedLabel.ZIndex = 11

-- THEIR brainrots list
local theirBrainrotScroll = scrollFrame(tradeWindow, RIGHT_X, COL_Y + 26, COL_W, 200)
theirBrainrotScroll.ZIndex = 11
theirBrainrotScroll.BackgroundColor3 = C.panel
theirBrainrotScroll.BackgroundTransparency = 0
corner(theirBrainrotScroll, 6)

-- THEIR money display
label(tradeWindow, "Their $:", RIGHT_X, COL_Y + 270, 70, 28, 13, C.subtext).ZIndex = 11
local theirMoneyLabel = label(tradeWindow, "0", RIGHT_X + 76, COL_Y + 270, 160, 28, 13, C.text)
theirMoneyLabel.ZIndex = 11

-- THEIR confirmed indicator
local theirConfirmedLabel = label(tradeWindow, "", RIGHT_X, COL_Y + 306, COL_W, 22, 12, C.subtext)
theirConfirmedLabel.ZIndex = 11

-- ── Bottom bar ─────────────────────────────────────────────────────────────────
local BOTTOM_Y = 420

local bottomBar = Instance.new("Frame")
bottomBar.Size             = UDim2.new(1, -36, 0, 1)
bottomBar.Position         = UDim2.new(0, 18, 0, BOTTOM_Y - 8)
bottomBar.BackgroundColor3 = C.divider
bottomBar.BorderSizePixel  = 0
bottomBar.ZIndex           = 11
bottomBar.Parent           = tradeWindow

local taxLabel    = label(tradeWindow, "Tax: $0", 18, BOTTOM_Y, 200, 24, 12, C.gold)
taxLabel.ZIndex   = 11
local valueLabel  = label(tradeWindow, "", 18, BOTTOM_Y + 20, 400, 22, 11, C.subtext)
valueLabel.ZIndex = 11

local confirmBtn  = btn(tradeWindow, "✔  Confirm", WIN_W - 310, BOTTOM_Y, 136, 40, C.greenDim, C.green)
local cancelBtn2  = btn(tradeWindow, "✕  Cancel",  WIN_W - 164, BOTTOM_Y, 136, 40, C.redDim,   C.red)
confirmBtn.ZIndex = 11
cancelBtn2.ZIndex = 11

confirmBtn.MouseButton1Click:Connect(function()
	evConfirm:FireServer()
end)
cancelBtn2.MouseButton1Click:Connect(function()
	evCancel:FireServer()
end)

-- ── Confirm Timer Overlay ──────────────────────────────────────────────────────

local timerOverlay = Instance.new("Frame")
timerOverlay.Name              = "TimerOverlay"
timerOverlay.Size              = UDim2.fromScale(1, 1)
timerOverlay.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
timerOverlay.BackgroundTransparency = 0.4
timerOverlay.BorderSizePixel   = 0
timerOverlay.Visible           = false
timerOverlay.ZIndex            = 13
timerOverlay.Parent            = tradeWindow

local timerLabel = Instance.new("TextLabel")
timerLabel.Size                = UDim2.new(0, 200, 0, 60)
timerLabel.Position            = UDim2.new(0.5, -100, 0.5, -60)
timerLabel.BackgroundTransparency = 1
timerLabel.Text                = "3"
timerLabel.TextColor3          = C.gold
timerLabel.Font                = Enum.Font.GothamBold
timerLabel.TextSize            = 48
timerLabel.ZIndex              = 14
timerLabel.Parent              = timerOverlay

local timerSubLabel = Instance.new("TextLabel")
timerSubLabel.Size             = UDim2.new(0, 280, 0, 24)
timerSubLabel.Position         = UDim2.new(0.5, -140, 0.5, 10)
timerSubLabel.BackgroundTransparency = 1
timerSubLabel.Text             = "Trade executing in..."
timerSubLabel.TextColor3       = C.text
timerSubLabel.Font             = Enum.Font.Gotham
timerSubLabel.TextSize         = 13
timerSubLabel.ZIndex           = 14
timerSubLabel.Parent           = timerOverlay

local timerCancelBtn = btn(timerOverlay, "Cancel Trade", WIN_W/2 - 70, WIN_H/2 + 44, 140, 36, C.redDim, C.red)
timerCancelBtn.ZIndex = 14
timerCancelBtn.MouseButton1Click:Connect(function()
	evCancel:FireServer()
end)

-- ─── Brainrot Selector Panel ──────────────────────────────────────────────────

local SEL_W, SEL_H = 660, 440
local selectorPanel = Instance.new("Frame")
selectorPanel.Name             = "BrainrotSelector"
selectorPanel.Size             = UDim2.new(0, SEL_W, 0, SEL_H)
selectorPanel.Position         = UDim2.new(0.5, -SEL_W/2, 0.5, -SEL_H/2)
selectorPanel.BackgroundColor3 = C.bg
selectorPanel.BorderSizePixel  = 0
selectorPanel.Visible          = false
selectorPanel.ZIndex           = 18
corner(selectorPanel, 12)
stroke(selectorPanel, C.accent, 2)
selectorPanel.Parent = gui

-- Selector header
local selHeader = Instance.new("Frame")
selHeader.Size             = UDim2.new(1, 0, 0, 48)
selHeader.BackgroundColor3 = C.header
selHeader.BorderSizePixel  = 0
corner(selHeader, 12)
selHeader.ZIndex = 19
selHeader.Parent = selectorPanel

label(selHeader, "🧠  Choose a Brainrot to Add", 16, 0, 500, 48, 14, C.text, Enum.Font.GothamBold).ZIndex = 20
local selClose = btn(selHeader, "✕", SEL_W - 44, 10, 28, 28, C.redDim, C.red)
selClose.ZIndex = 20
selClose.MouseButton1Click:Connect(function()
	selectorPanel.Visible = false
end)

label(selectorPanel, "Click a brainrot to add it to your offer", 16, 54, SEL_W - 32, 22, 11, C.subtext, Enum.Font.Gotham).ZIndex = 19

-- Brainrot grid scroll
local selScroll = Instance.new("ScrollingFrame")
selScroll.Position              = UDim2.new(0, 12, 0, 80)
selScroll.Size                  = UDim2.new(0, SEL_W - 24, 0, SEL_H - 100)
selScroll.BackgroundTransparency = 1
selScroll.BorderSizePixel       = 0
selScroll.ScrollBarThickness    = 4
selScroll.ScrollBarImageColor3  = C.accent
selScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
selScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
selScroll.ZIndex                = 19
selScroll.Parent                = selectorPanel

local selGrid = Instance.new("UIGridLayout")
selGrid.CellSize    = UDim2.new(0, 150, 0, 72)
selGrid.CellPadding = UDim2.new(0, 8, 0, 8)
selGrid.SortOrder   = Enum.SortOrder.LayoutOrder
selGrid.Parent      = selScroll

local function populateSelector(available)
	for _, child in ipairs(selScroll:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then child:Destroy() end
	end

	if not available or #available == 0 then
		local empty = label(selScroll, "No brainrots available to add", 0, 0, SEL_W - 40, 40, 13, C.subtext, Enum.Font.Gotham, Enum.TextXAlignment.Center)
		empty.ZIndex = 19
		return
	end

	for _, b in ipairs(available) do
		local rarityColor = RARITY_COLORS[b.Rarity] or C.text

		local card = Instance.new("TextButton")
		card.Size             = UDim2.new(0, 150, 0, 72)
		card.BackgroundColor3 = C.itemBg
		card.BorderSizePixel  = 0
		card.Text             = ""
		card.AutoButtonColor  = false
		card.ZIndex           = 19
		corner(card, 8)
		stroke(card, rarityColor, 2)
		card.Parent = selScroll

		-- Rarity badge
		local rarityBadge = Instance.new("Frame")
		rarityBadge.Size             = UDim2.new(1, 0, 0, 18)
		rarityBadge.Position         = UDim2.new(0, 0, 0, 0)
		rarityBadge.BackgroundColor3 = rarityColor
		rarityBadge.BackgroundTransparency = 0.6
		rarityBadge.BorderSizePixel  = 0
		rarityBadge.ZIndex           = 20
		corner(rarityBadge, 8)
		rarityBadge.Parent = card

		local rarityText = Instance.new("TextLabel")
		rarityText.Size              = UDim2.fromScale(1, 1)
		rarityText.BackgroundTransparency = 1
		rarityText.Text              = b.Rarity
		rarityText.TextColor3        = Color3.new(1,1,1)
		rarityText.Font              = Enum.Font.GothamBold
		rarityText.TextSize          = 10
		rarityText.ZIndex            = 21
		rarityText.Parent            = rarityBadge

		-- Name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size              = UDim2.new(1, -8, 0, 30)
		nameLabel.Position          = UDim2.new(0, 4, 0, 22)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text              = b.Name
		nameLabel.TextColor3        = C.text
		nameLabel.Font              = Enum.Font.GothamBold
		nameLabel.TextSize          = 11
		nameLabel.TextWrapped       = true
		nameLabel.ZIndex            = 20
		nameLabel.Parent            = card

		-- RPS
		local rpsLabel = Instance.new("TextLabel")
		rpsLabel.Size              = UDim2.new(1, -8, 0, 16)
		rpsLabel.Position          = UDim2.new(0, 4, 0, 54)
		rpsLabel.BackgroundTransparency = 1
		rpsLabel.Text              = string.format("$%.1f/s", b.RevenuePerSecond or 0)
		rpsLabel.TextColor3        = C.gold
		rpsLabel.Font              = Enum.Font.Gotham
		rpsLabel.TextSize          = 10
		rpsLabel.ZIndex            = 20
		rpsLabel.Parent            = card

		card.MouseEnter:Connect(function()
			card.BackgroundColor3 = C.itemHover
		end)
		card.MouseLeave:Connect(function()
			card.BackgroundColor3 = C.itemBg
		end)

		local bName = b.Name
		card.MouseButton1Click:Connect(function()
			evAddBrainrot:FireServer(bName)
			selectorPanel.Visible = false
		end)
	end
end

addBrainrotBtn.MouseButton1Click:Connect(function()
	if _tradeState and _tradeState.state == "active" then
		populateSelector(_tradeState.available or {})
		selectorPanel.Visible = true
	end
end)

-- ─── Render Helpers ───────────────────────────────────────────────────────────

-- Rebuild one side's brainrot list
local function buildBrainrotList(scroll, brainrots, isMine)
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	if #brainrots == 0 then
		local empty = Instance.new("Frame")
		empty.Size             = UDim2.new(1, 0, 0, 32)
		empty.BackgroundTransparency = 1
		empty.LayoutOrder      = 1
		empty.Parent           = scroll

		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size              = UDim2.fromScale(1, 1)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Text              = "No brainrots added"
		emptyLabel.TextColor3        = C.subtext
		emptyLabel.Font              = Enum.Font.Gotham
		emptyLabel.TextSize          = 12
		emptyLabel.Parent            = empty
		return
	end

	for i, b in ipairs(brainrots) do
		local rarityColor = RARITY_COLORS[b.Rarity] or C.text

		local row = Instance.new("Frame")
		row.Size             = UDim2.new(1, 0, 0, 38)
		row.BackgroundColor3 = C.itemBg
		row.BorderSizePixel  = 0
		row.LayoutOrder      = i
		corner(row, 6)
		stroke(row, rarityColor, 1)
		row.Parent = scroll

		-- Colored rarity dot
		local dot = Instance.new("Frame")
		dot.Size             = UDim2.new(0, 8, 0, 8)
		dot.Position         = UDim2.new(0, 6, 0.5, -4)
		dot.BackgroundColor3 = rarityColor
		dot.BorderSizePixel  = 0
		corner(dot, 4)
		dot.Parent = row

		local nameL = Instance.new("TextLabel")
		nameL.Size              = UDim2.new(1, isMine and -52 or -18, 0, 20)
		nameL.Position          = UDim2.new(0, 20, 0, 2)
		nameL.BackgroundTransparency = 1
		nameL.Text              = b.Name
		nameL.TextColor3        = C.text
		nameL.Font              = Enum.Font.GothamBold
		nameL.TextSize          = 12
		nameL.TextXAlignment    = Enum.TextXAlignment.Left
		nameL.Parent            = row

		local rpsL = Instance.new("TextLabel")
		rpsL.Size              = UDim2.new(1, isMine and -52 or -18, 0, 14)
		rpsL.Position          = UDim2.new(0, 20, 0, 22)
		rpsL.BackgroundTransparency = 1
		rpsL.Text              = string.format("$%.1f/s", b.RevenuePerSecond or 0)
		rpsL.TextColor3        = C.gold
		rpsL.Font              = Enum.Font.Gotham
		rpsL.TextSize          = 10
		rpsL.TextXAlignment    = Enum.TextXAlignment.Left
		rpsL.Parent            = row

		if isMine then
			local removeBtn = btn(row, "✕", COL_W - 46, 6, 28, 26, C.redDim, C.red)
			local bName = b.Name
			removeBtn.MouseButton1Click:Connect(function()
				evRemoveBrainrot:FireServer(bName)
			end)
		end
	end
end

-- Main render from state packet
local function renderState(state)
	if not state then return end
	_tradeState = state

	twTitle.Text = "🤝  Trade with " .. (state.partnerName or "?")

	-- Brainrot lists
	buildBrainrotList(myBrainrotScroll,    state.mySide.brainrots,    true)
	buildBrainrotList(theirBrainrotScroll, state.theirSide.brainrots, false)

	-- Money
	if not myMoneyBox:IsFocused() then
		myMoneyBox.Text = tostring(state.mySide.money or 0)
	end
	theirMoneyLabel.Text = "$" .. tostring(state.theirSide.money or 0)

	-- Confirmed indicators
	local function confText(confirmed)
		return confirmed and "✔ Confirmed" or "⏳ Waiting..."
	end
	local function confColor(confirmed)
		return confirmed and C.green or C.subtext
	end
	myConfirmedLabel.Text       = confText(state.mySide.confirmed)
	myConfirmedLabel.TextColor3 = confColor(state.mySide.confirmed)
	theirConfirmedLabel.Text       = confText(state.theirSide.confirmed)
	theirConfirmedLabel.TextColor3 = confColor(state.theirSide.confirmed)

	-- Tax
	if state.myTax and state.myTax > 0 then
		taxLabel.Text = string.format("⚠ You pay tax: $%d", state.myTax)
		taxLabel.TextColor3 = C.red
	else
		taxLabel.Text = "No tax"
		taxLabel.TextColor3 = C.gold
	end

	-- Compute values for display
	local myVal, theirVal = state.mySide.money or 0, state.theirSide.money or 0
	for _, b in ipairs(state.mySide.brainrots)    do myVal    += (b.RevenuePerSecond or 0) end
	for _, b in ipairs(state.theirSide.brainrots) do theirVal += (b.RevenuePerSecond or 0) end
	valueLabel.Text = string.format("Your total value: $%.1f  |  Their total value: $%.1f", myVal, theirVal)

	-- Add brainrot button visibility
	local canEdit = (state.state == "active")
	addBrainrotBtn.Visible  = canEdit
	myMoneyBox.Visible      = canEdit
	setMoneyBtn.Visible     = canEdit
	confirmBtn.Visible      = canEdit
	confirmBtn.BackgroundColor3 = state.mySide.confirmed and C.greenDim or C.green

	-- Timer overlay
	if state.state == "confirming" then
		timerOverlay.Visible = true
		addBrainrotBtn.Visible = false
		myMoneyBox.Visible     = false
		setMoneyBtn.Visible    = false
		confirmBtn.Visible     = false

		-- Start countdown
		if _timerConn then _timerConn:Disconnect(); _timerConn = nil end
		_timerConn = RunService.RenderStepped:Connect(function()
			local remaining = (state.timerEnd or 0) - os.time()
			if remaining <= 0 then
				timerLabel.Text = "0"
				if _timerConn then _timerConn:Disconnect(); _timerConn = nil end
			else
				timerLabel.Text = tostring(math.ceil(remaining))
			end
		end)
	else
		timerOverlay.Visible = false
		if _timerConn then _timerConn:Disconnect(); _timerConn = nil end
	end

	-- Show/close window
	if state.state == "cancelled" then
		showNotif("Trade was cancelled.", C.red)
		tradeWindow.Visible = false
		playerListPanel.Visible = false
		_tradeState = nil
	elseif state.state == "completed" then
		showNotif("Trade completed successfully!", C.green)
		tradeWindow.Visible = false
		_tradeState = nil
	else
		tradeWindow.Visible = true
		playerListPanel.Visible = false
	end
end

-- Money set button
setMoneyBtn.MouseButton1Click:Connect(function()
	local amount = tonumber(myMoneyBox.Text) or 0
	evSetMoney:FireServer(amount)
end)

myMoneyBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		local amount = tonumber(myMoneyBox.Text) or 0
		evSetMoney:FireServer(amount)
	end
end)

-- ─── Remote Event Listeners ───────────────────────────────────────────────────

evInviteReceived:Connect(function(fromUserId, fromName)
	inviteMsg.Text = fromName .. " wants to trade with you!"
	invitePopup.Visible = true
end)

evInviteDeclined:Connect(function(declinedByName)
	showNotif(declinedByName .. " declined your trade request.", C.red)
end)

evStateUpdate:Connect(function(state)
	renderState(state)
end)

-- ─── Cleanup on trade close ───────────────────────────────────────────────────

twCloseBtn.MouseButton1Click:Connect(function()
	-- Already fires evCancel above — also clean up locally in case server was slow
end)
