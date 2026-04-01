--[[
	LevelUIHandler - Affichage du niveau et de la progression EXP

	Écoute l'événement OnLevelChanged (server → client) et met à jour
	l'interface HUD avec le niveau actuel et la barre d'EXP.

	Structure UI attendue dans StarterGui :
	  HUD
	  └── LevelFrame
	      ├── LevelLabel    (TextLabel  → "Niveau X")
	      ├── ExpBar        (Frame      → barre de progression)
	      │   └── Fill      (Frame      → la partie colorée qui grandit)
	      └── ExpLabel      (TextLabel  → "XXX / YYY EXP")

	Si le joueur est Maître Prestige et au niveau max, ExpLabel affiche "∞ EXP"
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")


-- ─── Attendre les remotes ─────────────────────────────────────────────────────
local RemoteInterface = ReplicatedStorage:WaitForChild("RemoteInterface")
local onLevelChanged  = RemoteInterface:WaitForChild("Events"):WaitForChild("OnLevelChanged")

-- ─── Référence à l'UI ─────────────────────────────────────────────────────────
-- LevelFrame est créé dynamiquement par HUDSetup → on attend son apparition
local HUD         = PlayerGui:WaitForChild("HUD")
local LevelFrame  = HUD:WaitForChild("LevelFrame")
local LevelLabel  = LevelFrame:WaitForChild("LevelLabel")
local ExpBar      = LevelFrame:WaitForChild("ExpBar")
local ExpFill     = ExpBar:WaitForChild("Fill")
local ExpLabel    = LevelFrame:WaitForChild("ExpLabel")

-- ─── Mise à jour de l'affichage ───────────────────────────────────────────────
local function updateUI(level, exp, expForNext)
	if not LevelFrame then return end  -- UI pas encore créée dans Studio

	-- Afficher le niveau
	if LevelLabel then
		LevelLabel.Text = "Niveau " .. tostring(level)
	end

	-- Barre d'EXP (système relatif : exp repart à 0 à chaque niveau)
	if ExpFill and ExpBar then
		if expForNext and expForNext > 0 then
			local ratio = math.clamp(exp / expForNext, 0, 1)
			ExpFill.Size = UDim2.new(ratio, 0, 1, 0)
		else
			ExpFill.Size = UDim2.new(1, 0, 1, 0)
		end
	end

	-- Texte EXP
	if ExpLabel then
		if expForNext then
			ExpLabel.Text = string.format("%d / %d EXP", exp, expForNext)
		else
			ExpLabel.Text = "MAX"
		end
	end
end

-- ─── Connexion à l'événement serveur ─────────────────────────────────────────
onLevelChanged.OnClientEvent:Connect(function(level, exp, expForNext)
	updateUI(level, exp, expForNext)
end)
