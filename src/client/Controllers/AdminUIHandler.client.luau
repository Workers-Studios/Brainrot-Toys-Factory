--[[
	Gestionnaire UI admin côté client
	Visible uniquement aux administrateurs autorisés

	Fonctionnalités :
	- Bouton admin dans le HUD
	- Panel avec recherche joueur + autocomplete
	- Commandes : Give/Set Money, Give Spawner
	- Validation côté serveur (AdminService)
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network           = require(ReplicatedStorage.Shared.Network)
local Enums             = require(ReplicatedStorage.Shared.Enums)

local player = Players.LocalPlayer

-- Remotes admin
local remoteInterface      = ReplicatedStorage:WaitForChild("RemoteInterface")
local adminFolder          = remoteInterface:WaitForChild("Admin")
local isAdminRemote        = adminFolder:WaitForChild(Network.Admin.IsAdmin)
local executeCommandRemote = adminFolder:WaitForChild(Network.Admin.ExecuteCommand)

local isAdmin = isAdminRemote:InvokeServer()
if not isAdmin then
	print("Non admin — AdminUI désactivé")
	return
end

local playerGui = player:WaitForChild("PlayerGui")

-- ── ScreenGui ─────────────────────────────────────────────────────────────────
local adminUI = Instance.new("ScreenGui")
adminUI.Name          = "AdminUI"
adminUI.ResetOnSpawn  = false
adminUI.IgnoreGuiInset = true
adminUI.Parent        = playerGui

-- ── Bouton admin ──────────────────────────────────────────────────────────────
local adminButton = Instance.new("ImageButton")
adminButton.Name             = "AdminButton"
adminButton.Size             = UDim2.new(0, 44, 0, 44)
adminButton.Position         = UDim2.new(0, 172, 0, 12)
adminButton.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
adminButton.BorderSizePixel  = 0
adminButton.Image            = ""
adminButton.Parent           = adminUI
Instance.new("UICorner", adminButton).CornerRadius = UDim.new(1, 0)

local adminLabel = Instance.new("TextLabel")
adminLabel.Size               = UDim2.new(1, 0, 1, 0)
adminLabel.BackgroundTransparency = 1
adminLabel.TextColor3         = Color3.fromRGB(255, 255, 255)
adminLabel.Text               = "AD"
adminLabel.Font               = Enum.Font.GothamBold
adminLabel.TextSize           = 18
adminLabel.Parent             = adminButton

adminButton.MouseEnter:Connect(function()
	adminButton.BackgroundColor3 = Color3.fromRGB(51, 59, 68)
end)
adminButton.MouseLeave:Connect(function()
	adminButton.BackgroundColor3 = Color3.fromRGB(26, 31, 36)
end)

-- ── Panel admin ───────────────────────────────────────────────────────────────
local adminPanel = Instance.new("Frame")
adminPanel.Name             = "AdminPanel"
adminPanel.Size             = UDim2.new(0, 400, 0, 500)
adminPanel.Position         = UDim2.new(0.5, -200, 0.5, -250)
adminPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
adminPanel.Visible          = false
adminPanel.Parent           = adminUI
Instance.new("UICorner", adminPanel).CornerRadius = UDim.new(0, 12)

-- Titre
local title = Instance.new("TextLabel")
title.Size               = UDim2.new(1, -20, 0, 40)
title.Position           = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.TextColor3         = Color3.fromRGB(255, 255, 255)
title.Text               = "ADMIN PANEL"
title.Font               = Enum.Font.GothamBold
title.TextSize           = 20
title.TextXAlignment     = Enum.TextXAlignment.Left
title.Parent             = adminPanel

-- Bouton fermer
local closeButton = Instance.new("TextButton")
closeButton.Size             = UDim2.new(0, 30, 0, 30)
closeButton.Position         = UDim2.new(1, -40, 0, 10)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.TextColor3       = Color3.fromRGB(255, 255, 255)
closeButton.Text             = "X"
closeButton.Font             = Enum.Font.GothamBold
closeButton.TextSize         = 18
closeButton.Parent           = adminPanel
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 6)

-- ── Recherche joueur ──────────────────────────────────────────────────────────
local playerLabel = Instance.new("TextLabel")
playerLabel.Size             = UDim2.new(1, -20, 0, 20)
playerLabel.Position         = UDim2.new(0, 10, 0, 60)
playerLabel.BackgroundTransparency = 1
playerLabel.TextColor3       = Color3.fromRGB(200, 200, 200)
playerLabel.Text             = "Player Name:"
playerLabel.Font             = Enum.Font.Gotham
playerLabel.TextSize         = 14
playerLabel.TextXAlignment   = Enum.TextXAlignment.Left
playerLabel.Parent           = adminPanel

local playerSearch = Instance.new("TextBox")
playerSearch.Name            = "PlayerSearch"
playerSearch.Size            = UDim2.new(1, -20, 0, 35)
playerSearch.Position        = UDim2.new(0, 10, 0, 85)
playerSearch.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
playerSearch.TextColor3      = Color3.fromRGB(255, 255, 255)
playerSearch.PlaceholderText = "Type player name..."
playerSearch.Text            = ""
playerSearch.Font            = Enum.Font.Gotham
playerSearch.TextSize        = 14
playerSearch.ClearTextOnFocus = false
playerSearch.Parent          = adminPanel
Instance.new("UICorner", playerSearch).CornerRadius = UDim.new(0, 6)

-- Suggestions
local suggestionsList = Instance.new("ScrollingFrame")
suggestionsList.Name             = "SuggestionsList"
suggestionsList.Size             = UDim2.new(1, -20, 0, 100)
suggestionsList.Position         = UDim2.new(0, 10, 0, 125)
suggestionsList.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
suggestionsList.ScrollBarThickness = 4
suggestionsList.Visible          = false
suggestionsList.Parent           = adminPanel
Instance.new("UICorner", suggestionsList).CornerRadius = UDim.new(0, 6)

local suggestionsLayout = Instance.new("UIListLayout", suggestionsList)
suggestionsLayout.SortOrder = Enum.SortOrder.Name
suggestionsLayout.Padding   = UDim.new(0, 2)

-- ── Champ montant ─────────────────────────────────────────────────────────────
local amountLabel = Instance.new("TextLabel")
amountLabel.Size             = UDim2.new(1, -20, 0, 20)
amountLabel.Position         = UDim2.new(0, 10, 0, 235)
amountLabel.BackgroundTransparency = 1
amountLabel.TextColor3       = Color3.fromRGB(200, 200, 200)
amountLabel.Text             = "Amount:"
amountLabel.Font             = Enum.Font.Gotham
amountLabel.TextSize         = 14
amountLabel.TextXAlignment   = Enum.TextXAlignment.Left
amountLabel.Parent           = adminPanel

local amountInput = Instance.new("TextBox")
amountInput.Name             = "AmountInput"
amountInput.Size             = UDim2.new(1, -20, 0, 35)
amountInput.Position         = UDim2.new(0, 10, 0, 260)
amountInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
amountInput.TextColor3       = Color3.fromRGB(255, 255, 255)
amountInput.PlaceholderText  = "Enter amount..."
amountInput.Text             = ""
amountInput.Font             = Enum.Font.Gotham
amountInput.TextSize         = 14
amountInput.Parent           = adminPanel
Instance.new("UICorner", amountInput).CornerRadius = UDim.new(0, 6)

-- ── Boutons Give / Set Money ──────────────────────────────────────────────────
local giveMoneyButton = Instance.new("TextButton")
giveMoneyButton.Size             = UDim2.new(0.48, 0, 0, 40)
giveMoneyButton.Position         = UDim2.new(0, 10, 0, 310)
giveMoneyButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
giveMoneyButton.TextColor3       = Color3.fromRGB(255, 255, 255)
giveMoneyButton.Text             = "Give Money"
giveMoneyButton.Font             = Enum.Font.GothamBold
giveMoneyButton.TextSize         = 14
giveMoneyButton.Parent           = adminPanel
Instance.new("UICorner", giveMoneyButton).CornerRadius = UDim.new(0, 6)

local setMoneyButton = Instance.new("TextButton")
setMoneyButton.Size             = UDim2.new(0.48, 0, 0, 40)
setMoneyButton.Position         = UDim2.new(0.52, 0, 0, 310)
setMoneyButton.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
setMoneyButton.TextColor3       = Color3.fromRGB(255, 255, 255)
setMoneyButton.Text             = "Set Money"
setMoneyButton.Font             = Enum.Font.GothamBold
setMoneyButton.TextSize         = 14
setMoneyButton.Parent           = adminPanel
Instance.new("UICorner", setMoneyButton).CornerRadius = UDim.new(0, 6)

-- ── Sélection rareté spawner ──────────────────────────────────────────────────
local rarityLabel = Instance.new("TextLabel")
rarityLabel.Size             = UDim2.new(1, -20, 0, 20)
rarityLabel.Position         = UDim2.new(0, 10, 0, 365)
rarityLabel.BackgroundTransparency = 1
rarityLabel.TextColor3       = Color3.fromRGB(200, 200, 200)
rarityLabel.Text             = "Spawner Rarity:"
rarityLabel.Font             = Enum.Font.Gotham
rarityLabel.TextSize         = 14
rarityLabel.TextXAlignment   = Enum.TextXAlignment.Left
rarityLabel.Parent           = adminPanel

local rarityButtons   = {}
local selectedRarity  = Enums.Rarity.Common

-- Génère les boutons depuis Enums.RarityList — scalable automatiquement
for i, rarity in ipairs(Enums.RarityList) do
	local btn = Instance.new("TextButton")
	btn.Name             = rarity .. "Button"
	btn.Size             = UDim2.new(0.18, -2, 0, 30)
	btn.Position         = UDim2.new((i - 1) * 0.20 + 0.01, 0, 0, 390)
	btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	btn.TextColor3       = Color3.fromRGB(255, 255, 255)
	btn.Text             = rarity
	btn.Font             = Enum.Font.Gotham
	btn.TextSize         = 10
	btn.Parent           = adminPanel
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	rarityButtons[rarity] = btn
end

-- Bouton Give Spawner
local giveSpawnerButton = Instance.new("TextButton")
giveSpawnerButton.Size             = UDim2.new(1, -20, 0, 40)
giveSpawnerButton.Position         = UDim2.new(0, 10, 0, 435)
giveSpawnerButton.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
giveSpawnerButton.TextColor3       = Color3.fromRGB(255, 255, 255)
giveSpawnerButton.Text             = "🎁 Give Spawner"
giveSpawnerButton.Font             = Enum.Font.GothamBold
giveSpawnerButton.TextSize         = 14
giveSpawnerButton.Parent           = adminPanel
Instance.new("UICorner", giveSpawnerButton).CornerRadius = UDim.new(0, 6)

-- ── État local ────────────────────────────────────────────────────────────────
local selectedPlayer = nil

local function updateSuggestions(searchText)
	for _, child in ipairs(suggestionsList:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	if searchText == "" then
		suggestionsList.Visible = false
		return
	end

	local matches = {}
	local lower   = searchText:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(lower, 1, true) then
			table.insert(matches, p.Name)
		end
	end

	if #matches == 0 then
		suggestionsList.Visible = false
		return
	end

	for _, playerName in ipairs(matches) do
		local btn = Instance.new("TextButton")
		btn.Name             = playerName
		btn.Size             = UDim2.new(1, -8, 0, 30)
		btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		btn.TextColor3       = Color3.fromRGB(255, 255, 255)
		btn.Text             = playerName
		btn.Font             = Enum.Font.Gotham
		btn.TextSize         = 13
		btn.Parent           = suggestionsList
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

		btn.MouseButton1Click:Connect(function()
			playerSearch.Text  = playerName
			selectedPlayer     = playerName
			suggestionsList.Visible = false
		end)
	end

	suggestionsList.CanvasSize = UDim2.new(0, 0, 0, #matches * 32)
	suggestionsList.Visible    = true
end

local function updateRaritySelection(rarity)
	selectedRarity = rarity
	for r, btn in pairs(rarityButtons) do
		btn.BackgroundColor3 = (r == rarity)
			and Color3.fromRGB(100, 200, 100)
			or  Color3.fromRGB(60, 60, 60)
	end
end

updateRaritySelection(Enums.Rarity.Common)

-- ── Connexions ────────────────────────────────────────────────────────────────
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
	if not selectedPlayer or selectedPlayer == "" then warn("Aucun joueur sélectionné"); return end
	if not amount or amount <= 0 then warn("Montant invalide"); return end
	executeCommandRemote:FireServer("GiveMoney", selectedPlayer, amount)
	print("Donné", amount, "$ à", selectedPlayer)
end)

setMoneyButton.MouseButton1Click:Connect(function()
	local amount = tonumber(amountInput.Text)
	if not selectedPlayer or selectedPlayer == "" then warn("Aucun joueur sélectionné"); return end
	if not amount or amount < 0 then warn("Montant invalide"); return end
	executeCommandRemote:FireServer("SetMoney", selectedPlayer, amount)
	print("Argent de", selectedPlayer, "fixé à", amount)
end)

giveSpawnerButton.MouseButton1Click:Connect(function()
	if not selectedPlayer or selectedPlayer == "" then warn("Aucun joueur sélectionné"); return end
	executeCommandRemote:FireServer("GiveSpawner", selectedPlayer, selectedRarity)
	print("Donné spawner", selectedRarity, "à", selectedPlayer)
end)
