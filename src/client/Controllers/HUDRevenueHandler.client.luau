--[[
	Affiche la somme des RevenuePerSecond de tous les brainrots posés sur les socles
	dans le label "MoneyPerSecond" du HUD.

	Mis à jour à chaque fois qu'un brainrot est posé ou récupéré.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Cherche le label MoneyPerSecond dans le HUD (cherche récursivement)
local hud = playerGui:WaitForChild("HUD")
local background = hud:WaitForChild("Background")

-- Chercher récursivement dans tout le HUD (pas seulement Background)
local moneyPerSecondLabel = hud:FindFirstChild("MoneyPerSecond", true)

if not moneyPerSecondLabel then
	warn("[HUDRevenue] Label 'MoneyPerSecond' introuvable dans HUD — vérifier le nom dans Studio")
	return
end

print("[HUDRevenue] Label trouvé:", moneyPerSecondLabel:GetFullName())

-- Écouter les mises à jour de revenu du serveur
local onRevenueChanged = ReplicatedStorage
	:WaitForChild("RemoteInterface")
	:WaitForChild("Events")
	:WaitForChild("OnRevenuePerSecondChanged")

print("[HUDRevenue] Event connecté")

onRevenueChanged.OnClientEvent:Connect(function(totalRevenue)
	print("[HUDRevenue] Reçu:", totalRevenue)
	moneyPerSecondLabel.Text = tostring(totalRevenue) .. "/s"
end)
