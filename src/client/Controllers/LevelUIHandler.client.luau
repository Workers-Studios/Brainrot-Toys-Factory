--[[
	LevelUIHandler - Affichage du niveau et de la progression EXP

	- LevelFrame (rectangle HUD) : caché, bouton Prestige reparenté dans HUD
	- Overhead : ScreenGui positionné via WorldToViewportPoint (taille fixe au scroll)
	- Barre EXP : full width, collée en bas de l'écran
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local camera    = workspace.CurrentCamera

local PrestigeConfig    = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PrestigeConfig"))
local RemoteInterface   = ReplicatedStorage:WaitForChild("RemoteInterface")
local onLevelChanged    = RemoteInterface:WaitForChild("Events"):WaitForChild("OnLevelChanged")
local onPrestigeChanged = RemoteInterface:WaitForChild("Events"):WaitForChild("OnPrestigeChanged")

-- ─── HUD : cacher le LevelFrame, garder le bouton Prestige ───────────────────

local HUD        = PlayerGui:WaitForChild("HUD")
local LevelFrame = HUD:WaitForChild("LevelFrame")

local prestigeButton = LevelFrame:FindFirstChild("PrestigeButton")
	or LevelFrame:FindFirstChildWhichIsA("TextButton")
	or LevelFrame:FindFirstChildWhichIsA("ImageButton")

if prestigeButton then
	prestigeButton.Parent = HUD
end

LevelFrame.Visible = false

-- ─── ScreenGui overhead (taille fixe quelle que soit la distance caméra) ─────
--
-- Utilise WorldToViewportPoint chaque RenderStepped pour positionner un Frame
-- en espace écran → la taille en pixels ne change pas au scroll.

local overheadGui = Instance.new("ScreenGui")
overheadGui.Name           = "OverheadUI"
overheadGui.ResetOnSpawn   = false
overheadGui.IgnoreGuiInset = true
overheadGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
overheadGui.Parent         = PlayerGui

-- { [userId] = { frame, lLabel, player } }
local overheadData = {}

local MAX_DIST   = 60   -- studs max pour afficher l'overhead
local HEAD_ABOVE = Vector3.new(0, 2.6, 0)  -- offset au-dessus du centre de la tête

local function makeLabel(parent, name, size, posY, textSize, font, color, strokeT)
	local lbl = Instance.new("TextLabel")
	lbl.Name                   = name
	lbl.Size                   = UDim2.new(1, 0, 0, size)
	lbl.Position               = UDim2.new(0, 0, 0, posY)
	lbl.BackgroundTransparency = 1
	lbl.Text                   = ""
	lbl.TextColor3             = color
	lbl.TextTransparency       = 0
	lbl.Font                   = font
	lbl.TextSize               = textSize
	lbl.TextStrokeTransparency = strokeT
	lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
	lbl.TextXAlignment         = Enum.TextXAlignment.Center
	lbl.Parent                 = parent
	return lbl
end

local function createOverhead(p)
	-- Nettoyer l'ancien si présent
	if overheadData[p.UserId] then
		overheadData[p.UserId].frame:Destroy()
		overheadData[p.UserId] = nil
	end

	local frame = Instance.new("Frame")
	frame.Name               = "Overhead_" .. p.UserId
	frame.Size               = UDim2.new(0, 220, 0, 70)
	frame.AnchorPoint        = Vector2.new(0.5, 1)
	frame.BackgroundTransparency = 1
	frame.Visible            = false
	frame.Parent             = overheadGui

	-- Niveau (+ emoji prestige inline)
	local lLabel = makeLabel(frame, "LevelLabel", 28, 0,
		24, Enum.Font.GothamBold, Color3.fromRGB(255, 255, 255), 0.4)

	-- DisplayName
	local nLabel = makeLabel(frame, "NameLabel", 22, 28,
		18, Enum.Font.GothamBold, Color3.fromRGB(255, 255, 255), 0)

	-- @username
	local uLabel = makeLabel(frame, "UsernameLabel", 16, 50,
		11, Enum.Font.Gotham, Color3.fromRGB(155, 158, 168), 0)

	nLabel.Text = p.DisplayName
	uLabel.Text = "@ " .. p.Name

	overheadData[p.UserId] = { frame = frame, lLabel = lLabel, player = p }
	return lLabel
end

local function refreshLevel(character, lLabel)
	local level    = character:GetAttribute("PlayerLevel")    or 1
	local prestige = character:GetAttribute("PlayerPrestige") or 0
	local isMaster = character:GetAttribute("PlayerIsMaster") or false

	if isMaster then
		lLabel.Text = tostring(level) .. " ⭐"
	elseif prestige > 0 then
		lLabel.Text = tostring(level) .. " 🌟"
	else
		lLabel.Text = tostring(level)
	end
end

local function connectCharacter(p, character, lLabel)
	refreshLevel(character, lLabel)
	character:GetAttributeChangedSignal("PlayerLevel"):Connect(function()
		refreshLevel(character, lLabel)
	end)
	character:GetAttributeChangedSignal("PlayerPrestige"):Connect(function()
		refreshLevel(character, lLabel)
	end)
	character:GetAttributeChangedSignal("PlayerIsMaster"):Connect(function()
		refreshLevel(character, lLabel)
	end)
end

local function setupPlayer(p)
	local lLabel = createOverhead(p)

	if p.Character then
		connectCharacter(p, p.Character, lLabel)
	end

	p.CharacterAdded:Connect(function(character)
		-- Re-créer l'overhead pour récupérer un lLabel frais après respawn
		local newLLabel = createOverhead(p)
		connectCharacter(p, character, newLLabel)
	end)
end

-- Init joueurs présents
for _, p in ipairs(Players:GetPlayers()) do
	setupPlayer(p)
end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(p)
	if overheadData[p.UserId] then
		overheadData[p.UserId].frame:Destroy()
		overheadData[p.UserId] = nil
	end
end)

-- ─── Mise à jour des positions chaque frame ───────────────────────────────────

RunService.RenderStepped:Connect(function()
	for _, data in pairs(overheadData) do
		local p   = data.player
		local chr = p.Character
		if not chr then data.frame.Visible = false; continue end

		local head = chr:FindFirstChild("Head")
		if not head then data.frame.Visible = false; continue end

		local dist = (camera.CFrame.Position - head.Position).Magnitude
		if dist > MAX_DIST then data.frame.Visible = false; continue end

		local screenPos, onScreen, depth =
			camera:WorldToViewportPoint(head.Position + HEAD_ABOVE)

		if onScreen and depth > 0 then
			data.frame.Visible  = true
			data.frame.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
		else
			data.frame.Visible = false
		end
	end
end)

-- ─── Barre EXP full width en bas de l'écran ──────────────────────────────────

local BAR_HEIGHT = 12

local expGui = Instance.new("ScreenGui")
expGui.Name           = "ExpBarUI"
expGui.ResetOnSpawn   = false
expGui.IgnoreGuiInset = true
expGui.DisplayOrder   = 20
expGui.Parent         = PlayerGui

local barBg = Instance.new("Frame")
barBg.Name              = "ExpBarBg"
barBg.Size              = UDim2.new(1, 0, 0, BAR_HEIGHT)
barBg.Position          = UDim2.new(0, 0, 1, 0)
barBg.AnchorPoint       = Vector2.new(0, 1)
barBg.BackgroundColor3  = Color3.fromRGB(20, 20, 20)
barBg.BorderSizePixel   = 0
barBg.Parent            = expGui

local barFill = Instance.new("Frame")
barFill.Name             = "Fill"
barFill.Size             = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
barFill.BorderSizePixel  = 0
barFill.Parent           = barBg

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 120, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0)),
})
gradient.Rotation = 0
gradient.Parent   = barFill

for _, pct in ipairs({ 0.20, 0.40, 0.60, 0.80 }) do
	local tick = Instance.new("Frame")
	tick.Size                   = UDim2.new(0, 3, 1, 0)
	tick.Position               = UDim2.new(pct, -1, 0, 0)
	tick.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
	tick.BackgroundTransparency = 0
	tick.BorderSizePixel        = 0
	tick.ZIndex                 = 3
	tick.Parent                 = barBg
end

local barLabel = Instance.new("TextLabel")
barLabel.Size                   = UDim2.new(1, 0, 1, 0)
barLabel.BackgroundTransparency = 1
barLabel.Text                   = ""
barLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
barLabel.Font                   = Enum.Font.GothamBold
barLabel.TextSize               = 10
barLabel.TextXAlignment         = Enum.TextXAlignment.Center
barLabel.TextYAlignment         = Enum.TextYAlignment.Center
barLabel.ZIndex                 = 2
barLabel.Parent                 = barBg

-- ─── Mise à jour de la barre EXP ─────────────────────────────────────────────

local MAX_LEVEL = PrestigeConfig and PrestigeConfig.MaxLevel or 50

local function updateUI(level, exp, expForNext)
	if level >= MAX_LEVEL then
		barFill.Size  = UDim2.new(1, 0, 1, 0)
		barLabel.Text = "MAX"
	elseif expForNext and expForNext > 0 then
		local ratio = math.clamp(exp / expForNext, 0, 1)
		barFill.Size  = UDim2.new(ratio, 0, 1, 0)
		barLabel.Text = string.format("%d / %d EXP", exp, expForNext)
	else
		barFill.Size  = UDim2.new(1, 0, 1, 0)
		barLabel.Text = "MAX"
	end
end

onLevelChanged.OnClientEvent:Connect(function(level, exp, expForNext)
	updateUI(level, exp, expForNext)
end)

onPrestigeChanged.OnClientEvent:Connect(function() end)
