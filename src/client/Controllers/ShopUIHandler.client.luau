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
local player = Players.LocalPlayer

-- Shop UI
local shopUI = player:WaitForChild("PlayerGui"):WaitForChild("ShopUI")
local shopFrame = shopUI:WaitForChild("ShopFrame")
local commonButton = shopFrame:WaitForChild("CommonButton")
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

-- Start with shop closed
shopUI.Enabled = false

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