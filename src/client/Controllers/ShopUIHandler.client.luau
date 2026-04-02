--[[
	Client-side shop UI handler with HUD integration
	Manages spawner purchase buttons, shop visibility toggle, and money display in HUD
	
	Main responsibilities:
	- Toggle shop UI visibility via HUD button
	- Connect purchase buttons to server RemoteFunction
	- Update money display in HUD when player money changes
	- Show purchase feedback via output
	- Prevent double-click spam with processing lock
	
	UI Structure expected:
	- HUD/Background/MenuIcon/Shop/Button (shop toggle button)
	- HUD/Background/Money (money display label)
	- ShopUI/ShopFrame/ (purchase buttons: Common, Rare, Epic, Legendary)
]]

-- IMPORTS & VARIABLES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpawnerConfig = require(ReplicatedStorage.Shared.SpawnerConfig)
local player = Players.LocalPlayer

-- Shop UI
local shopUI = player:WaitForChild("PlayerGui"):WaitForChild("ShopUI")
local shopFrame = shopUI:WaitForChild("ShopFrame")
local commonButton = shopFrame:WaitForChild("CommonButton")
local uncommonButton = shopFrame:WaitForChild("UncommonButton")
local rareButton = shopFrame:WaitForChild("RareButton")
local epicButton = shopFrame:WaitForChild("EpicButton")
local legendaryButton = shopFrame:WaitForChild("LegendaryButton")

-- HUD UI (Money Display)
local hudUI = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
local backgroundFrame = hudUI:WaitForChild("Background")
local menuIcon = backgroundFrame:WaitForChild("MenuIcon")
local shop = menuIcon:WaitForChild("Shop")
local shopButton = shop:WaitForChild("Button")
local moneyDisplay = backgroundFrame:WaitForChild("Money")

-- Remote communication
local purchaseSpawner = ReplicatedStorage:WaitForChild("RemoteInterface"):WaitForChild("Functions"):WaitForChild("PurchaseSpawner")
local onMoneyChanged = ReplicatedStorage:WaitForChild("RemoteInterface"):WaitForChild("Events"):WaitForChild("OnMoneyChanged")

local currentMoney = 0
local isProcessing = false

-- Met à jour le texte de prix sur un bouton depuis SpawnerConfig
local function applyPrice(button, rarity)
	local cfg = SpawnerConfig[rarity]
	if not cfg then return end
	local priceText = "$" .. tostring(cfg.BasePrice)
	-- Cherche d'abord un label enfant dédié au prix
	local priceLabel = button:FindFirstChild("PriceLabel") or button:FindFirstChild("Price")
	if priceLabel then
		priceLabel.Text = priceText
	else
		-- Sinon on injecte directement dans le Text du bouton
		-- On remplace uniquement la partie prix (après le saut de ligne s'il y en a un)
		local existing = button.Text
		local newline = existing:find("\n")
		if newline then
			button.Text = existing:sub(1, newline) .. priceText
		else
			button.Text = existing .. "\n" .. priceText
		end
	end
end

-- Start with shop closed
shopUI.Enabled = false

-- Appliquer les prix depuis la config dès le chargement
applyPrice(commonButton,   "Common")
applyPrice(uncommonButton, "Uncommon")
applyPrice(rareButton,     "Rare")
applyPrice(epicButton,     "Epic")
applyPrice(legendaryButton,"Legendary")

-- Toggles shop UI visibility
local function toggleShop()
	shopUI.Enabled = not shopUI.Enabled
end

-- Handles spawner purchase button click
-- @param rarity: string - Spawner rarity to purchase
local function onPurchaseButtonClicked(rarity)
	if isProcessing then
		return
	end

	isProcessing = true
	print("Tentative d'achat", rarity)

	local success, message = purchaseSpawner:InvokeServer(rarity)

	if success then
		print("✅ Achat réussi:", message)
	else
		warn("❌ Achat échoué:", message)
	end

	isProcessing = false
end

-- Updates money display in HUD
-- @param newMoney: number - New money amount
local function updateMoneyDisplay(newMoney)
	currentMoney = newMoney
	moneyDisplay.Text = "$" .. tostring(newMoney)
end

-- Connect purchase buttons
commonButton.MouseButton1Click:Connect(function()
	onPurchaseButtonClicked("Common")
end)

uncommonButton.MouseButton1Click:Connect(function()
	onPurchaseButtonClicked("Uncommon")
end)

rareButton.MouseButton1Click:Connect(function()
	onPurchaseButtonClicked("Rare")
end)

epicButton.MouseButton1Click:Connect(function()
	onPurchaseButtonClicked("Epic")
end)

legendaryButton.MouseButton1Click:Connect(function()
	onPurchaseButtonClicked("Legendary")
end)

-- Listen for money updates from server
onMoneyChanged.OnClientEvent:Connect(updateMoneyDisplay)

-- Connect shop toggle button
shopButton.MouseButton1Click:Connect(toggleShop)