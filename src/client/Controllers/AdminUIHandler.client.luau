--[[
	Client-side admin UI handler
	Manages admin panel visibility and command execution
	Only visible to authorized admins
	
	Features:
	- Admin button in HUD (visible only to admins)
	- Admin panel with player search and autocomplete
	- Give/Set money commands
	- Give spawner command
	- Secure server-side validation
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- Wait for RemoteInterface
local remoteInterface = ReplicatedStorage:WaitForChild("RemoteInterface")
local adminFolder = remoteInterface:WaitForChild("Admin")
local isAdminRemote = adminFolder:WaitForChild("IsAdmin")
local executeCommandRemote = adminFolder:WaitForChild("ExecuteCommand")

-- Check if player is admin
local isAdmin = isAdminRemote:InvokeServer()

if not isAdmin then
	print("Not admin, AdminUI disabled")
	return
end

-- Get UI elements
local playerGui = player:WaitForChild("PlayerGui")

-- Create AdminUI
local adminUI = Instance.new("ScreenGui")
adminUI.Name = "AdminUI"
adminUI.ResetOnSpawn = false
adminUI.Parent = playerGui
adminUI.IgnoreGuiInset = true

-- Admin Button
local adminButton = Instance.new("ImageButton")
adminButton.Name = "AdminButton"
adminButton.Size = UDim2.new(0, 44, 0, 44)
adminButton.Position = UDim2.new(0, 172, 0, 12)
adminButton.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
adminButton.BorderSizePixel = 0
adminButton.Image = ""
adminButton.Parent = adminUI

-- Make it circular
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(1, 0)
buttonCorner.Parent = adminButton

-- Admin text/icon inside
local adminLabel = Instance.new("TextLabel")
adminLabel.Size = UDim2.new(1, 0, 1, 0)
adminLabel.BackgroundTransparency = 1
adminLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
adminLabel.Text = "AD"
adminLabel.Font = Enum.Font.GothamBold
adminLabel.TextSize = 18
adminLabel.Parent = adminButton

-- Hover effect
adminButton.MouseEnter:Connect(function()
	adminButton.BackgroundColor3 = Color3.fromRGB(51, 59, 68)
end)

adminButton.MouseLeave:Connect(function()
	adminButton.BackgroundColor3 = Color3.fromRGB(26, 31, 36)
end)

-- Admin Panel
local adminPanel = Instance.new("Frame")
adminPanel.Name = "AdminPanel"
adminPanel.Size = UDim2.new(0, 400, 0, 660)
adminPanel.Position = UDim2.new(0.5, -200, 0.5, -330)
adminPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
adminPanel.Visible = false
adminPanel.Parent = adminUI

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = adminPanel

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -20, 0, 40)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "ADMIN PANEL"
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = adminPanel

-- Close Button
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -40, 0, 10)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Text = "X"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.Parent = adminPanel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

-- Player Search
local playerLabel = Instance.new("TextLabel")
playerLabel.Size = UDim2.new(1, -20, 0, 20)
playerLabel.Position = UDim2.new(0, 10, 0, 60)
playerLabel.BackgroundTransparency = 1
playerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
playerLabel.Text = "Player Name:"
playerLabel.Font = Enum.Font.Gotham
playerLabel.TextSize = 14
playerLabel.TextXAlignment = Enum.TextXAlignment.Left
playerLabel.Parent = adminPanel

local playerSearch = Instance.new("TextBox")
playerSearch.Name = "PlayerSearch"
playerSearch.Size = UDim2.new(1, -20, 0, 35)
playerSearch.Position = UDim2.new(0, 10, 0, 85)
playerSearch.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
playerSearch.TextColor3 = Color3.fromRGB(255, 255, 255)
playerSearch.PlaceholderText = "Type player name..."
playerSearch.Text = ""
playerSearch.Font = Enum.Font.Gotham
playerSearch.TextSize = 14
playerSearch.ClearTextOnFocus = false
playerSearch.Parent = adminPanel

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 6)
searchCorner.Parent = playerSearch

-- Player Suggestions List
local suggestionsList = Instance.new("ScrollingFrame")
suggestionsList.Name = "SuggestionsList"
suggestionsList.Size = UDim2.new(1, -20, 0, 100)
suggestionsList.Position = UDim2.new(0, 10, 0, 125)
suggestionsList.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
suggestionsList.ScrollBarThickness = 4
suggestionsList.Visible = false
suggestionsList.Parent = adminPanel

local suggestionsCorner = Instance.new("UICorner")
suggestionsCorner.CornerRadius = UDim.new(0, 6)
suggestionsCorner.Parent = suggestionsList

local suggestionsLayout = Instance.new("UIListLayout")
suggestionsLayout.SortOrder = Enum.SortOrder.Name
suggestionsLayout.Padding = UDim.new(0, 2)
suggestionsLayout.Parent = suggestionsList

-- Amount Input
local amountLabel = Instance.new("TextLabel")
amountLabel.Size = UDim2.new(1, -20, 0, 20)
amountLabel.Position = UDim2.new(0, 10, 0, 235)
amountLabel.BackgroundTransparency = 1
amountLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
amountLabel.Text = "Amount:"
amountLabel.Font = Enum.Font.Gotham
amountLabel.TextSize = 14
amountLabel.TextXAlignment = Enum.TextXAlignment.Left
amountLabel.Parent = adminPanel

local amountInput = Instance.new("TextBox")
amountInput.Name = "AmountInput"
amountInput.Size = UDim2.new(1, -20, 0, 35)
amountInput.Position = UDim2.new(0, 10, 0, 260)
amountInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
amountInput.TextColor3 = Color3.fromRGB(255, 255, 255)
amountInput.PlaceholderText = "Enter amount..."
amountInput.Text = ""
amountInput.Font = Enum.Font.Gotham
amountInput.TextSize = 14
amountInput.Parent = adminPanel

local amountCorner = Instance.new("UICorner")
amountCorner.CornerRadius = UDim.new(0, 6)
amountCorner.Parent = amountInput

-- Give Money Button
local giveMoneyButton = Instance.new("TextButton")
giveMoneyButton.Name = "GiveMoneyButton"
giveMoneyButton.Size = UDim2.new(0.48, 0, 0, 40)
giveMoneyButton.Position = UDim2.new(0, 10, 0, 310)
giveMoneyButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
giveMoneyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
giveMoneyButton.Text = "Give Money"
giveMoneyButton.Font = Enum.Font.GothamBold
giveMoneyButton.TextSize = 14
giveMoneyButton.Parent = adminPanel

local giveMoneyCorner = Instance.new("UICorner")
giveMoneyCorner.CornerRadius = UDim.new(0, 6)
giveMoneyCorner.Parent = giveMoneyButton

-- Set Money Button
local setMoneyButton = Instance.new("TextButton")
setMoneyButton.Name = "SetMoneyButton"
setMoneyButton.Size = UDim2.new(0.48, 0, 0, 40)
setMoneyButton.Position = UDim2.new(0.52, 0, 0, 310)
setMoneyButton.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
setMoneyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
setMoneyButton.Text = "Set Money"
setMoneyButton.Font = Enum.Font.GothamBold
setMoneyButton.TextSize = 14
setMoneyButton.Parent = adminPanel

local setMoneyCorner = Instance.new("UICorner")
setMoneyCorner.CornerRadius = UDim.new(0, 6)
setMoneyCorner.Parent = setMoneyButton

-- Spawner Rarity Dropdown
local rarityLabel = Instance.new("TextLabel")
rarityLabel.Size = UDim2.new(1, -20, 0, 20)
rarityLabel.Position = UDim2.new(0, 10, 0, 365)
rarityLabel.BackgroundTransparency = 1
rarityLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
rarityLabel.Text = "Spawner Rarity:"
rarityLabel.Font = Enum.Font.Gotham
rarityLabel.TextSize = 14
rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
rarityLabel.Parent = adminPanel

local rarityButtons = {}
local rarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary"}
local selectedRarity = "Common"

local rarityCount = #rarities
for i, rarity in ipairs(rarities) do
	local btn = Instance.new("TextButton")
	btn.Name = rarity .. "Button"
	btn.Size = UDim2.new(1 / rarityCount - 0.01, 0, 0, 30)
	btn.Position = UDim2.new((i-1) / rarityCount + 0.005, 0, 0, 390)
	btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = rarity
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 11
	btn.Parent = adminPanel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn

	rarityButtons[rarity] = btn
end

-- Give Spawner Button
local giveSpawnerButton = Instance.new("TextButton")
giveSpawnerButton.Name = "GiveSpawnerButton"
giveSpawnerButton.Size = UDim2.new(1, -20, 0, 40)
giveSpawnerButton.Position = UDim2.new(0, 10, 0, 435)
giveSpawnerButton.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
giveSpawnerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
giveSpawnerButton.Text = "🎁 Give Spawner"
giveSpawnerButton.Font = Enum.Font.GothamBold
giveSpawnerButton.TextSize = 14
giveSpawnerButton.Parent = adminPanel

local giveSpawnerCorner = Instance.new("UICorner")
giveSpawnerCorner.CornerRadius = UDim.new(0, 6)
giveSpawnerCorner.Parent = giveSpawnerButton

-- ─── Section Progression ─────────────────────────────────────────────────────
local progSep = Instance.new("Frame")
progSep.Name = "ProgSeparator"
progSep.Size = UDim2.new(1, -20, 0, 1)
progSep.Position = UDim2.new(0, 10, 0, 490)
progSep.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
progSep.BorderSizePixel = 0
progSep.Parent = adminPanel

local progTitle = Instance.new("TextLabel")
progTitle.Size = UDim2.new(1, -20, 0, 20)
progTitle.Position = UDim2.new(0, 10, 0, 498)
progTitle.BackgroundTransparency = 1
progTitle.TextColor3 = Color3.fromRGB(180, 180, 255)
progTitle.Text = "Progression"
progTitle.Font = Enum.Font.GothamBold
progTitle.TextSize = 14
progTitle.TextXAlignment = Enum.TextXAlignment.Left
progTitle.Parent = adminPanel

-- Add EXP button
local addExpButton = Instance.new("TextButton")
addExpButton.Name = "AddExpButton"
addExpButton.Size = UDim2.new(0.48, 0, 0, 36)
addExpButton.Position = UDim2.new(0, 10, 0, 523)
addExpButton.BackgroundColor3 = Color3.fromRGB(30, 140, 80)
addExpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
addExpButton.Text = "Add EXP"
addExpButton.Font = Enum.Font.GothamBold
addExpButton.TextSize = 13
addExpButton.Parent = adminPanel
Instance.new("UICorner", addExpButton).CornerRadius = UDim.new(0, 6)

-- Set Level button
local setLevelButton = Instance.new("TextButton")
setLevelButton.Name = "SetLevelButton"
setLevelButton.Size = UDim2.new(0.48, 0, 0, 36)
setLevelButton.Position = UDim2.new(0.52, 0, 0, 523)
setLevelButton.BackgroundColor3 = Color3.fromRGB(30, 80, 160)
setLevelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
setLevelButton.Text = "Set Level"
setLevelButton.Font = Enum.Font.GothamBold
setLevelButton.TextSize = 13
setLevelButton.Parent = adminPanel
Instance.new("UICorner", setLevelButton).CornerRadius = UDim.new(0, 6)

-- Set Prestige button
local setPrestigeButton = Instance.new("TextButton")
setPrestigeButton.Name = "SetPrestigeButton"
setPrestigeButton.Size = UDim2.new(0.48, 0, 0, 36)
setPrestigeButton.Position = UDim2.new(0, 10, 0, 567)
setPrestigeButton.BackgroundColor3 = Color3.fromRGB(120, 30, 160)
setPrestigeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
setPrestigeButton.Text = "Set Prestige"
setPrestigeButton.Font = Enum.Font.GothamBold
setPrestigeButton.TextSize = 13
setPrestigeButton.Parent = adminPanel
Instance.new("UICorner", setPrestigeButton).CornerRadius = UDim.new(0, 6)

-- Give Brainrot button (uses selectedRarity from rarity selector above)
local giveBrainrotButton = Instance.new("TextButton")
giveBrainrotButton.Name = "GiveBrainrotButton"
giveBrainrotButton.Size = UDim2.new(0.48, 0, 0, 36)
giveBrainrotButton.Position = UDim2.new(0.52, 0, 0, 567)
giveBrainrotButton.BackgroundColor3 = Color3.fromRGB(180, 100, 20)
giveBrainrotButton.TextColor3 = Color3.fromRGB(255, 255, 255)
giveBrainrotButton.Text = "Give Brainrot"
giveBrainrotButton.Font = Enum.Font.GothamBold
giveBrainrotButton.TextSize = 13
giveBrainrotButton.Parent = adminPanel
Instance.new("UICorner", giveBrainrotButton).CornerRadius = UDim.new(0, 6)

local progNote = Instance.new("TextLabel")
progNote.Size = UDim2.new(1, -20, 0, 18)
progNote.Position = UDim2.new(0, 10, 0, 613)
progNote.BackgroundTransparency = 1
progNote.TextColor3 = Color3.fromRGB(140, 140, 140)
progNote.Text = "Amount = EXP / Level / Prestige  •  Rarity = Brainrot rarity"
progNote.Font = Enum.Font.Gotham
progNote.TextSize = 10
progNote.TextXAlignment = Enum.TextXAlignment.Left
progNote.TextWrapped = true
progNote.Parent = adminPanel

-- Local state
local selectedPlayer = nil

-- Updates player suggestions based on search
local function updateSuggestions(searchText)
	-- Clear existing suggestions
	for _, child in ipairs(suggestionsList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	if searchText == "" then
		suggestionsList.Visible = false
		return
	end

	-- Find matching players
	local matches = {}
	searchText = searchText:lower()

	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(searchText, 1, true) then
			table.insert(matches, p.Name)
		end
	end

	if #matches == 0 then
		suggestionsList.Visible = false
		return
	end

	-- Create suggestion buttons
	for _, playerName in ipairs(matches) do
		local suggestionBtn = Instance.new("TextButton")
		suggestionBtn.Name = playerName
		suggestionBtn.Size = UDim2.new(1, -8, 0, 30)
		suggestionBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		suggestionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		suggestionBtn.Text = playerName
		suggestionBtn.Font = Enum.Font.Gotham
		suggestionBtn.TextSize = 13
		suggestionBtn.Parent = suggestionsList

		local suggestionCorner = Instance.new("UICorner")
		suggestionCorner.CornerRadius = UDim.new(0, 4)
		suggestionCorner.Parent = suggestionBtn

		suggestionBtn.MouseButton1Click:Connect(function()
			playerSearch.Text = playerName
			selectedPlayer = playerName
			suggestionsList.Visible = false
		end)
	end

	suggestionsList.CanvasSize = UDim2.new(0, 0, 0, #matches * 32)
	suggestionsList.Visible = true
end

-- Updates rarity button colors
local function updateRaritySelection(rarity)
	selectedRarity = rarity

	for r, btn in pairs(rarityButtons) do
		if r == rarity then
			btn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
		else
			btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		end
	end
end

-- Initialize Common as selected
updateRaritySelection("Common")

-- Connect events
adminButton.MouseButton1Click:Connect(function()
	adminPanel.Visible = not adminPanel.Visible
end)

closeButton.MouseButton1Click:Connect(function()
	adminPanel.Visible = false
end)

playerSearch:GetPropertyChangedSignal("Text"):Connect(function()
	updateSuggestions(playerSearch.Text)
	selectedPlayer = playerSearch.Text
end)

for rarity, btn in pairs(rarityButtons) do
	btn.MouseButton1Click:Connect(function()
		updateRaritySelection(rarity)
	end)
end

giveMoneyButton.MouseButton1Click:Connect(function()
	local amount = tonumber(amountInput.Text)
	if not selectedPlayer or selectedPlayer == "" then
		warn("No player selected")
		return
	end
	if not amount or amount <= 0 then
		warn("Invalid amount")
		return
	end

	executeCommandRemote:FireServer("GiveMoney", selectedPlayer, amount)
	print("Gave", amount, "$ to", selectedPlayer)
end)

setMoneyButton.MouseButton1Click:Connect(function()
	local amount = tonumber(amountInput.Text)
	if not selectedPlayer or selectedPlayer == "" then
		warn("No player selected")
		return
	end
	if not amount or amount < 0 then
		warn("Invalid amount")
		return
	end

	executeCommandRemote:FireServer("SetMoney", selectedPlayer, amount)
	print("Set", selectedPlayer, "money to", amount)
end)

giveSpawnerButton.MouseButton1Click:Connect(function()
	if not selectedPlayer or selectedPlayer == "" then
		warn("No player selected")
		return
	end

	executeCommandRemote:FireServer("GiveSpawner", selectedPlayer, selectedRarity)
	print("Gave", selectedRarity, "spawner to", selectedPlayer)
end)

addExpButton.MouseButton1Click:Connect(function()
	local amount = tonumber(amountInput.Text)
	if not selectedPlayer or selectedPlayer == "" then warn("No player selected") return end
	if not amount or amount <= 0 then warn("Invalid amount") return end
	executeCommandRemote:FireServer("AddExp", selectedPlayer, amount)
	print("Added", amount, "EXP to", selectedPlayer)
end)

setLevelButton.MouseButton1Click:Connect(function()
	local level = tonumber(amountInput.Text)
	if not selectedPlayer or selectedPlayer == "" then warn("No player selected") return end
	if not level or level < 1 then warn("Invalid level") return end
	executeCommandRemote:FireServer("SetLevel", selectedPlayer, level)
	print("Set", selectedPlayer, "to level", level)
end)

setPrestigeButton.MouseButton1Click:Connect(function()
	local prestige = tonumber(amountInput.Text)
	if not selectedPlayer or selectedPlayer == "" then warn("No player selected") return end
	if not prestige or prestige < 0 then warn("Invalid prestige") return end
	executeCommandRemote:FireServer("SetPrestige", selectedPlayer, prestige)
	print("Set", selectedPlayer, "prestige to", prestige)
end)

giveBrainrotButton.MouseButton1Click:Connect(function()
	if not selectedPlayer or selectedPlayer == "" then warn("No player selected") return end
	executeCommandRemote:FireServer("GiveBrainrot", selectedPlayer, selectedRarity)
	print("Gave", selectedRarity, "brainrot to", selectedPlayer)
end)
