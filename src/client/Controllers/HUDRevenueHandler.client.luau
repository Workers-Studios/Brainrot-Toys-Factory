--[[
	Affiche la somme des RevenuePerSecond de tous les brainrots posés sur les socles
	dans le label "MoneyPerSecond" du HUD.

	Mis à jour à chaque fois qu'un brainrot est posé ou récupéré.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Cherche le label MoneyPerSecond dans le HUD
local hud = playerGui:WaitForChild("HUD")
local background = hud:WaitForChild("Background")
local moneyPerSecondLabel = background:FindFirstChild("MoneyPerSecond", true)

if not moneyPerSecondLabel then
	warn("HUDRevenueHandler: Label 'MoneyPerSecond' introuvable dans HUD")
	return
end

local function formatRevenue(amount)
	return "$" .. tostring(amount) .. "/s"
end

-- Écouter les mises à jour de revenu du serveur
local onRevenueChanged = ReplicatedStorage
	:WaitForChild("RemoteInterface")
	:WaitForChild("Events")
	:WaitForChild("OnRevenuePerSecondChanged")

onRevenueChanged.OnClientEvent:Connect(function(totalRevenue)
	moneyPerSecondLabel.Text = formatRevenue(totalRevenue)
end)
