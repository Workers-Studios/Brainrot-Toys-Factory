--[[
	Gestionnaire UI du shop côté client
	Gère les boutons d'achat, l'affichage de l'argent et le toggle du shop

	Structure UI attendue :
	- HUD/Background/MenuIcon/Shop/Button (toggle)
	- HUD/Background/Money (affichage argent)
	- ShopUI/ShopFrame/{Common,Rare,Epic,Legendary}Button
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network           = require(ReplicatedStorage.Shared.Network)

local player = Players.LocalPlayer

-- UI
local shopUI      = player:WaitForChild("PlayerGui"):WaitForChild("ShopUI")
local shopFrame   = shopUI:WaitForChild("ShopFrame")
local commonButton    = shopFrame:WaitForChild("CommonButton")
local rareButton      = shopFrame:WaitForChild("RareButton")
local epicButton      = shopFrame:WaitForChild("EpicButton")
local legendaryButton = shopFrame:WaitForChild("LegendaryButton")

local hudUI          = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
local backgroundFrame = hudUI:WaitForChild("Background")
local menuIcon        = backgroundFrame:WaitForChild("MenuIcon")
local shopButton      = menuIcon:WaitForChild("Shop"):WaitForChild("Button")
local moneyDisplay    = backgroundFrame:WaitForChild("Money")

-- Remotes
local RemoteInterface = ReplicatedStorage:WaitForChild("RemoteInterface")
local purchaseSpawner = RemoteInterface:WaitForChild("Functions"):WaitForChild(Network.Functions.PurchaseSpawner)
local onMoneyChanged  = RemoteInterface:WaitForChild("Events"):WaitForChild(Network.Events.OnMoneyChanged)

local isProcessing = false
shopUI.Enabled = false

-- Toggle shop
local function toggleShop()
	shopUI.Enabled = not shopUI.Enabled
end

-- Achat d'un spawner
local function onPurchaseButtonClicked(rarity)
	if isProcessing then return end
	isProcessing = true

	local success, message = purchaseSpawner:InvokeServer(rarity)
	if success then
		print("✅ Achat réussi :", message)
	else
		warn("❌ Achat échoué :", message)
	end

	isProcessing = false
end

-- Mise à jour de l'affichage argent
local function updateMoneyDisplay(newMoney)
	moneyDisplay.Text = "$" .. tostring(newMoney)
end

-- Connexions boutons d'achat
commonButton.MouseButton1Click:Connect(function()    onPurchaseButtonClicked("Common") end)
rareButton.MouseButton1Click:Connect(function()      onPurchaseButtonClicked("Rare") end)
epicButton.MouseButton1Click:Connect(function()      onPurchaseButtonClicked("Epic") end)
legendaryButton.MouseButton1Click:Connect(function() onPurchaseButtonClicked("Legendary") end)

-- Écoute les mises à jour d'argent du serveur
onMoneyChanged.OnClientEvent:Connect(updateMoneyDisplay)

-- Toggle
shopButton.MouseButton1Click:Connect(toggleShop)
