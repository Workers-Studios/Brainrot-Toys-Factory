--[[
	Affiche la somme des RevenuePerSecond de tous les brainrots posés
	dans le label "MoneyPerSecond" du HUD

	Mis à jour à chaque fois qu'un brainrot est posé ou récupéré.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local hud = playerGui:WaitForChild("HUD")
local moneyPerSecondLabel = hud:FindFirstChild("MoneyPerSecond", true)

if not moneyPerSecondLabel then
	warn("[HUDRevenue] Label 'MoneyPerSecond' introuvable dans HUD — vérifier le nom dans Studio")
	return
end

local onRevenueChanged = ReplicatedStorage
	:WaitForChild("RemoteInterface")
	:WaitForChild("Events")
	:WaitForChild("OnRevenuePerSecondChanged")

onRevenueChanged.OnClientEvent:Connect(function(totalRevenue)
	moneyPerSecondLabel.Text = tostring(totalRevenue) .. "/s"
end)
