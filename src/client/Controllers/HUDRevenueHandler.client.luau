--[[
	Affiche la somme des RevenuePerSecond de tous les brainrots posés
	dans le label "MoneyPerSecond" du HUD

	Mis à jour à chaque fois qu'un brainrot est posé ou récupéré.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network           = require(ReplicatedStorage.Shared.Network)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local hud = playerGui:WaitForChild("HUD")
local moneyPerSecondLabel = hud:FindFirstChild("MoneyPerSecond", true)

if not moneyPerSecondLabel then
	warn("[HUDRevenue] Label 'MoneyPerSecond' introuvable dans HUD — vérifier le nom dans Studio")
	return
end

print("[HUDRevenue] Label trouvé :", moneyPerSecondLabel:GetFullName())

local onRevenueChanged = ReplicatedStorage
	:WaitForChild("RemoteInterface")
	:WaitForChild("Events")
	:WaitForChild(Network.Events.OnRevenuePerSecondChanged)

print("[HUDRevenue] Event connecté")

onRevenueChanged.OnClientEvent:Connect(function(totalRevenue)
	moneyPerSecondLabel.Text = tostring(totalRevenue) .. "/s"
end)
