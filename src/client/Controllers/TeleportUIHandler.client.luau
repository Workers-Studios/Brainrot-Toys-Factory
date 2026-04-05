--[[
	TeleportUIHandler - Intra-map teleportation buttons

	Layout (top-center of screen):
	┌──────────────────────────────────────────────────┐
	│  [ PvE ]  [ Social HUB ]  [ Fishing ]  [ Sacrifice ]  │
	│           [ My Base ]      [ Sell ]                    │
	└──────────────────────────────────────────────────┘

	Fires RemoteEvent "TeleportRequest" with the destination name.
	VFX is handled separately — this script only sends the request.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player        = Players.LocalPlayer
local playerGui     = player:WaitForChild("PlayerGui")
local teleportEvent = ReplicatedStorage
	:WaitForChild("RemoteInterface")
	:WaitForChild("Events")
	:WaitForChild("TeleportRequest")

-- ─── Dimensions ───────────────────────────────────────────────────────────────
local PANEL_W  = 420
local PANEL_H  = 100
local PAD      = 10
local BTN_H    = 36
local GAP      = 8

-- Row 1 : 4 buttons
local ROW1_BTN_W = math.floor((PANEL_W - PAD*2 - GAP*3) / 4)  -- 94px

-- Row 2 : 2 buttons centered
local ROW2_BTN_W = 140
local ROW2_TOTAL = ROW2_BTN_W * 2 + GAP
local ROW2_X     = math.floor((PANEL_W - ROW2_TOTAL) / 2)

-- ─── Colors ───────────────────────────────────────────────────────────────────
local COLORS = {
	PvE       = { bg = Color3.fromRGB(170, 70,  20),  hover = Color3.fromRGB(200, 90,  40)  },
	SocialHub = { bg = Color3.fromRGB(30,  90,  190), hover = Color3.fromRGB(50,  120, 220) },
	Fishing   = { bg = Color3.fromRGB(20,  150, 130), hover = Color3.fromRGB(40,  180, 160) },
	Sacrifice = { bg = Color3.fromRGB(110, 20,  160), hover = Color3.fromRGB(140, 40,  200) },
	MyBase    = { bg = Color3.fromRGB(35,  130, 55),  hover = Color3.fromRGB(55,  160, 75)  },
	Sell      = { bg = Color3.fromRGB(170, 140, 20),  hover = Color3.fromRGB(210, 175, 30)  },
}

-- ─── ScreenGui ────────────────────────────────────────────────────────────────
local gui        = Instance.new("ScreenGui")
gui.Name         = "TeleportUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent       = playerGui

-- ─── Panel ────────────────────────────────────────────────────────────────────
local panel           = Instance.new("Frame")
panel.Name            = "TeleportPanel"
panel.Size            = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position        = UDim2.new(0.5, -PANEL_W / 2, 0, 4)
panel.BackgroundTransparency = 1
panel.BorderSizePixel = 0
panel.Parent          = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

-- ─── Button factory ───────────────────────────────────────────────────────────
local function makeButton(label, destination, x, y, w)
	local col = COLORS[destination]

	local btn             = Instance.new("TextButton")
	btn.Name              = destination .. "Btn"
	btn.Size              = UDim2.new(0, w, 0, BTN_H)
	btn.Position          = UDim2.new(0, x, 0, y)
	btn.BackgroundColor3  = col.bg
	btn.BorderSizePixel   = 0
	btn.Text              = label
	btn.TextColor3        = Color3.fromRGB(255, 255, 255)
	btn.Font              = Enum.Font.GothamBold
	btn.TextSize          = 13
	btn.AutoButtonColor   = false
	btn.Parent            = panel
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	-- Hover
	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = col.hover
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = col.bg
	end)

	-- Click → fire server
	btn.MouseButton1Click:Connect(function()
		teleportEvent:FireServer(destination)
	end)

	return btn
end

-- ─── Row 1 : PvE · Social HUB · Fishing · Sacrifice ──────────────────────────
local row1Y = PAD
local row1Buttons = {
	{ label = "⚔️ PvE",        dest = "PvE"       },
	{ label = "👥 Social HUB", dest = "SocialHub"  },
	{ label = "🎣 Fishing",    dest = "Fishing"    },
	{ label = "💀 Sacrifice",  dest = "Sacrifice"  },
}
for i, data in ipairs(row1Buttons) do
	local x = PAD + (i - 1) * (ROW1_BTN_W + GAP)
	makeButton(data.label, data.dest, x, row1Y, ROW1_BTN_W)
end

-- ─── Row 2 : My Base · Sell ───────────────────────────────────────────────────
local row2Y = PAD + BTN_H + GAP
makeButton("🏠 My Base", "MyBase", ROW2_X,                  row2Y, ROW2_BTN_W)
makeButton("💰 Sell",    "Sell",   ROW2_X + ROW2_BTN_W + GAP, row2Y, ROW2_BTN_W)
