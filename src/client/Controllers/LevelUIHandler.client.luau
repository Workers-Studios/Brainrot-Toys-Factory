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

-- ─── Modules partagés (requis une seule fois au niveau module) ────────────────
local LevelConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LevelConfig"))

-- ─── Attendre les remotes ─────────────────────────────────────────────────────
local RemoteInterface = ReplicatedStorage:WaitForChild("RemoteInterface")
local onLevelChanged  = RemoteInterface:WaitForChild("Events"):WaitForChild("OnLevelChanged")

-- ─── Référence à l'UI ─────────────────────────────────────────────────────────
-- On attend l'existence des éléments UI (peuvent être chargés après le script)
local HUD         = PlayerGui:WaitForChild("HUD", 10)
local LevelFrame  = HUD and HUD:FindFirstChild("LevelFrame")
local LevelLabel  = LevelFrame and LevelFrame:FindFirstChild("LevelLabel")
local ExpBar      = LevelFrame and LevelFrame:FindFirstChild("ExpBar")
local ExpFill     = ExpBar     and ExpBar:FindFirstChild("Fill")
local ExpLabel    = LevelFrame and LevelFrame:FindFirstChild("ExpLabel")

-- ─── Mise à jour de l'affichage ───────────────────────────────────────────────
local function updateUI(level, exp, expForNext)
	if not LevelFrame then return end  -- UI pas encore créée dans Studio

	-- Afficher le niveau
	if LevelLabel then
		LevelLabel.Text = "Niveau " .. tostring(level)
	end

	-- Barre d'EXP
	if ExpFill and ExpBar then
		if expForNext and expForNext > 0 then
			-- EXP de la tranche actuelle
			local expBase = LevelConfig.ExpRequired[level] or 0
			local expInLevel  = exp - expBase
			local expNeeded   = expForNext - expBase

			local ratio = math.clamp(expInLevel / math.max(expNeeded, 1), 0, 1)
			ExpFill.Size = UDim2.new(ratio, 0, 1, 0)
		else
			-- Niveau maximum → barre pleine
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
