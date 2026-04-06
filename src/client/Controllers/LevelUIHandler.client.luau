--[[
	LevelUIHandler - Affichage du niveau et de la progression EXP

	- LevelFrame (rectangle HUD) : caché, bouton Prestige reparenté dans HUD
	- Niveau : BillboardGui au-dessus de la tête du joueur
	- Barre EXP : full width, collée en bas de l'écran, créée par code
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local PrestigeConfig     = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PrestigeConfig"))

local RemoteInterface    = ReplicatedStorage:WaitForChild("RemoteInterface")
local onLevelChanged     = RemoteInterface:WaitForChild("Events"):WaitForChild("OnLevelChanged")
local onPrestigeChanged  = RemoteInterface:WaitForChild("Events"):WaitForChild("OnPrestigeChanged")

-- ─── HUD : cacher le LevelFrame, garder le bouton Prestige ───────────────────
local HUD        = PlayerGui:WaitForChild("HUD")
local LevelFrame = HUD:WaitForChild("LevelFrame")

-- Récupérer le bouton Prestige avant de cacher le frame
local prestigeButton = LevelFrame:FindFirstChild("PrestigeButton")
	or LevelFrame:FindFirstChildWhichIsA("TextButton")
	or LevelFrame:FindFirstChildWhichIsA("ImageButton")

if prestigeButton then
	prestigeButton.Parent = HUD
end

-- Masquer tout le LevelFrame
LevelFrame.Visible = false

-- ─── BillboardGui : niveau + prestige au-dessus de la tête (tous les joueurs) ──
--
-- Les billboards sont créés côté client à partir des attributs character
-- PlayerLevel / PlayerPrestige / PlayerIsMaster mis à jour par le serveur.
-- Comme les attributs sont répliqués automatiquement, tous les clients voient
-- les niveaux de tous les joueurs.

local function makeBillboard()
	local bb = Instance.new("BillboardGui")
	bb.Name         = "LevelBillboard"
	bb.Size         = UDim2.new(0, 160, 0, 58)
	bb.StudsOffset  = Vector3.new(0, 1.7, 0)
	bb.AlwaysOnTop  = false
	bb.MaxDistance  = 60
	bb.ResetOnSpawn = false

	-- Prestige (top)
	local pLabel = Instance.new("TextLabel")
	pLabel.Name                   = "PrestigeLabel"
	pLabel.Size                   = UDim2.new(1, 0, 0, 16)
	pLabel.Position               = UDim2.new(0, 0, 0, 0)
	pLabel.BackgroundTransparency = 1
	pLabel.Text                   = ""
	pLabel.TextColor3             = Color3.fromRGB(255, 215, 0)
	pLabel.Font                   = Enum.Font.GothamBold
	pLabel.TextSize               = 10
	pLabel.TextStrokeTransparency = 0.4
	pLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
	pLabel.TextXAlignment         = Enum.TextXAlignment.Center
	pLabel.Parent                 = bb

	-- Level (middle)
	local lLabel = Instance.new("TextLabel")
	lLabel.Name                   = "LevelLabel"
	lLabel.Size                   = UDim2.new(1, 0, 0, 22)
	lLabel.Position               = UDim2.new(0, 0, 0, 16)
	lLabel.BackgroundTransparency = 1
	lLabel.Text                   = "Lv. ?"
	lLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
	lLabel.Font                   = Enum.Font.GothamBold
	lLabel.TextSize               = 14
	lLabel.TextStrokeTransparency = 0.4
	lLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
	lLabel.TextXAlignment         = Enum.TextXAlignment.Center
	lLabel.Parent                 = bb

	-- Name (bottom)
	local nLabel = Instance.new("TextLabel")
	nLabel.Name                   = "NameLabel"
	nLabel.Size                   = UDim2.new(1, 0, 0, 18)
	nLabel.Position               = UDim2.new(0, 0, 0, 38)
	nLabel.BackgroundTransparency = 1
	nLabel.Text                   = ""
	nLabel.TextColor3             = Color3.fromRGB(200, 220, 255)
	nLabel.Font                   = Enum.Font.Gotham
	nLabel.TextSize               = 12
	nLabel.TextStrokeTransparency = 0.4
	nLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
	nLabel.TextXAlignment         = Enum.TextXAlignment.Center
	nLabel.Parent                 = bb

	return bb, lLabel, pLabel, nLabel
end

local function refreshBillboard(character, lLabel, pLabel)
	local level    = character:GetAttribute("PlayerLevel")    or 1
	local prestige = character:GetAttribute("PlayerPrestige") or 0
	local isMaster = character:GetAttribute("PlayerIsMaster") or false

	lLabel.Text = "Lv. " .. tostring(level)

	if isMaster then
		pLabel.Text       = "⭐ Maître Prestige"
		pLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	elseif prestige > 0 then
		pLabel.Text       = "Prestige " .. tostring(prestige)
		pLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	else
		pLabel.Text = ""
	end
end

local function setupBillboard(character)
	local head = character:WaitForChild("Head", 10)
	if not head then return end

	-- Supprimer un ancien billboard s'il reste
	local old = head:FindFirstChild("LevelBillboard")
	if old then old:Destroy() end

	local bb, lLabel, pLabel, nLabel = makeBillboard()
	bb.Parent = head

	-- Set player display name (static, won't change)
	local p = Players:GetPlayerFromCharacter(character)
	if p then
		nLabel.Text = p.DisplayName
	end

	refreshBillboard(character, lLabel, pLabel)

	-- Mise à jour dynamique via les attributs répliqués
	character:GetAttributeChangedSignal("PlayerLevel"):Connect(function()
		refreshBillboard(character, lLabel, pLabel)
	end)
	character:GetAttributeChangedSignal("PlayerPrestige"):Connect(function()
		refreshBillboard(character, lLabel, pLabel)
	end)
	character:GetAttributeChangedSignal("PlayerIsMaster"):Connect(function()
		refreshBillboard(character, lLabel, pLabel)
	end)
end

-- Initialiser pour tous les joueurs déjà présents
for _, p in ipairs(Players:GetPlayers()) do
	if p.Character then setupBillboard(p.Character) end
	p.CharacterAdded:Connect(setupBillboard)
end
Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(setupBillboard)
	if p.Character then setupBillboard(p.Character) end
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
gradient.Color    = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 120, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0)),
})
gradient.Rotation = 0
gradient.Parent   = barFill

-- Ticks à 25 %, 50 %, 75 %
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

-- ─── Mise à jour de l'affichage ───────────────────────────────────────────────
local MAX_LEVEL = PrestigeConfig and PrestigeConfig.MaxLevel or 50

local function updateUI(level, exp, expForNext)
	levelLabel.Text = "Niveau " .. tostring(level)

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

-- ─── Connexion aux événements serveur ────────────────────────────────────────
onLevelChanged.OnClientEvent:Connect(function(level, exp, expForNext)
	updateUI(level, exp, expForNext)
end)

onPrestigeChanged.OnClientEvent:Connect(function(prestigeLevel, isMasterPrestige)
	if isMasterPrestige then
		prestigeLabel.Text      = "⭐ Maître Prestige"
		prestigeLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	elseif prestigeLevel and prestigeLevel > 0 then
		prestigeLabel.Text      = "Prestige " .. tostring(prestigeLevel)
		prestigeLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	else
		prestigeLabel.Text = ""
	end
end)
