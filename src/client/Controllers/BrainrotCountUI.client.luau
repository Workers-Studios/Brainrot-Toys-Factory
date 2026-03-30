--[[
	Affiche le count des oeufs et brainrots stackés sur les slots de la hotbar
	Style Minecraft : chiffre en bas à droite de chaque slot
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RarityColors      = require(ReplicatedStorage.Shared.RarityColors)

local player    = Players.LocalPlayer
local backpack  = player:WaitForChild("Backpack")
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "EggCountUI"
screenGui.ResetOnSpawn   = false
screenGui.DisplayOrder   = 99
screenGui.IgnoreGuiInset = true
screenGui.Parent         = playerGui

local SLOT_SIZE = 62
local HOTBAR_Y  = 8
local BADGE_W   = 26
local BADGE_H   = 18

local _badges = {}

local function isStackable(tool)
	return tool:IsA("Tool") and (tool.Name:match("^Oeuf_") or tool.Name:match("^Brainrot_"))
end

local function getAllTools()
	local tools = {}
	for _, t in ipairs(backpack:GetChildren()) do
		if t:IsA("Tool") then table.insert(tools, t) end
	end
	local char = player.Character
	if char then
		for _, t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") then table.insert(tools, t) end
		end
	end
	return tools
end

local function getOrCreateBadge(toolName, rarity)
	if _badges[toolName] and _badges[toolName].Parent then
		return _badges[toolName]
	end

	local frame = Instance.new("Frame")
	frame.Name                  = toolName
	frame.Size                  = UDim2.new(0, BADGE_W, 0, BADGE_H)
	frame.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel       = 0
	frame.Visible               = false
	frame.Parent                = screenGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4)

	local lbl = Instance.new("TextLabel")
	lbl.Name              = "Count"
	lbl.Size              = UDim2.new(1, -3, 1, 0)
	lbl.Position          = UDim2.new(0, 3, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3        = RarityColors[rarity] or Color3.fromRGB(255, 255, 255)
	lbl.TextScaled        = true
	lbl.Font              = Enum.Font.GothamBold
	lbl.TextXAlignment    = Enum.TextXAlignment.Right
	lbl.Parent            = frame

	_badges[toolName] = frame
	return frame
end

local function updateBadges()
	local screen   = screenGui.AbsoluteSize
	local allTools = getAllTools()
	local startX   = screen.X / 2 - (#allTools / 2) * SLOT_SIZE

	for _, badge in pairs(_badges) do
		if badge and badge.Parent then badge.Visible = false end
	end

	for i, tool in ipairs(allTools) do
		if not isStackable(tool) then continue end

		local count  = tool:GetAttribute("Count")  or 1
		local rarity = tool:GetAttribute("Rarity") or "Common"
		local badge  = getOrCreateBadge(tool.Name, rarity)

		local slotRight = startX + i * SLOT_SIZE
		badge.Position  = UDim2.new(0, slotRight - BADGE_W - 2, 1, -(HOTBAR_Y + BADGE_H + 2))
		badge:FindFirstChild("Count").Text = "x" .. count
		badge.Visible = true
	end
end

-- Événements backpack
backpack.ChildAdded:Connect(function(c) if c:IsA("Tool") then task.wait(); updateBadges() end end)
backpack.ChildRemoved:Connect(function(c) if c:IsA("Tool") then task.wait(); updateBadges() end end)

local function watchChar(char)
	char.ChildAdded:Connect(function(c) if c:IsA("Tool") then task.wait(); updateBadges() end end)
	char.ChildRemoved:Connect(function(c) if c:IsA("Tool") then task.wait(); updateBadges() end end)
end

player.CharacterAdded:Connect(watchChar)
if player.Character then watchChar(player.Character) end

-- Rafraîchissement Count en temps réel
backpack.ChildAdded:Connect(function(c)
	if isStackable(c) then
		c:GetAttributeChangedSignal("Count"):Connect(updateBadges)
	end
end)

RunService.Heartbeat:Connect(updateBadges)
