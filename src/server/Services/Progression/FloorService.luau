--[[
	FloorService - Gestion des étages débloquables

	Responsabilités :
	- Construire et positionner les plots d'étage au-dessus du plot de base
	- Renommer les slots pour éviter les conflits de clés (F1_Slot, F2_Slot…)
	- Initialiser spawner slots, generator slots et convoyeurs de chaque étage
	- Restaurer les étages à la reconnexion (dérivés du prestigeLevel)
	- Nettoyer les plots d'étage à la déconnexion

	Déclenchement :
	- UnlockFloor()   → appelé par PrestigeService après chaque prestige
	- RestoreFloors() → appelé par PlayerLifecycleHandler au join,
	                    AVANT RestorePlacedSpawners / RestorePlacedGenerators
	- RemoveFloors()  → appelé par PlayerLifecycleHandler à la déconnexion
]]

local FloorService = {}

local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotService               = require(script.Parent.Parent.Core.PlotService)
local PlacementService          = require(script.Parent.Parent.Gameplay.PlacementService)
local GeneratorPlacementService = require(script.Parent.Parent.Gameplay.GeneratorPlacementService)
local ConveyorService           = require(script.Parent.Parent.Gameplay.ConveyorService)
local FloorConfig               = require(ReplicatedStorage.Shared.FloorConfig)

local _PlayerDataService = nil
local _floors            = {}  -- [userId] = { [floorNumber] = Model }
local _roofs             = {}  -- [userId] = Model

-- ─── Init ──────────────────────────────────────────────────────────────────────

function FloorService.Init(PlayerDataService)
	_PlayerDataService = PlayerDataService
	print("✅ [FloorService] initialisé")
end

-- ─── Interne : construit et positionne le toit ────────────────────────────────
-- Placé à base_pivot + TotalHeight (76.167), même rotation que le plot de base.
-- Appelé une seule fois par joueur (dès le join, indépendamment du prestige).
-- @param userId : number
-- @return Model | nil
local function buildRoof(userId)
	if _roofs[userId] then return _roofs[userId] end  -- déjà présent

	local basePlot = PlotService.GetPlot(userId)
	if not basePlot then
		warn(string.format("[FloorService] ❌ Plot de base introuvable pour le toit (joueur %d)", userId))
		return nil
	end

	local template = ServerStorage:FindFirstChild("PlayerRoofPlotTemplate")
	if not template then
		warn("[FloorService] ❌ PlayerRoofPlotTemplate introuvable dans ServerStorage")
		return nil
	end

	local roofPlot  = template:Clone()
	roofPlot.Name   = "Roof_" .. userId

	-- Positionner exactement à la limite haute : base_pivot + TotalHeight
	local baseCFrame = basePlot:GetPivot()
	local roofCFrame = CFrame.new(baseCFrame.Position + Vector3.new(0, FloorConfig.TotalHeight, 0))
		* baseCFrame.Rotation

	roofPlot:PivotTo(roofCFrame)

	local playerPlotsFolder = workspace:FindFirstChild("PlayerPlots")
		or (function()
			local f = Instance.new("Folder")
			f.Name = "PlayerPlots"
			f.Parent = workspace
			return f
		end)()
	roofPlot.Parent = playerPlotsFolder

	_roofs[userId] = roofPlot
	print(string.format("[FloorService] ✅ Toit construit pour joueur %d", userId))
	return roofPlot
end

-- ─── Interne : construit et positionne le plot d'un étage ─────────────────────
-- @param userId      : number
-- @param floorNumber : number  (1 ou 2)
-- @return Model | nil
local function buildFloorPlot(userId, floorNumber)
	-- Référence : plot de base pour étage 1, étage précédent pour les suivants
	local refPlot = floorNumber == 1
		and PlotService.GetPlot(userId)
		or  (_floors[userId] and _floors[userId][floorNumber - 1])

	if not refPlot then
		warn(string.format("[FloorService] ❌ Référence de plot introuvable pour étage %d (joueur %d)", floorNumber, userId))
		return nil
	end

	local template = ServerStorage:FindFirstChild("PlayerPlotTemplate")
	if not template then
		warn("[FloorService] ❌ PlayerPlotTemplate introuvable dans ServerStorage")
		return nil
	end

	local floorPlot  = template:Clone()
	floorPlot.Name   = "Floor_" .. floorNumber .. "_" .. userId

	-- Préfixer les slots pour éviter les conflits de clés entre étages
	-- ex. "SpawnerSlot1" → "F1_SpawnerSlot1"
	local prefix = "F" .. floorNumber .. "_"

	local spawnerSlots = floorPlot:FindFirstChild("SpawnerSlots")
	if spawnerSlots then
		for _, slot in ipairs(spawnerSlots:GetChildren()) do
			slot.Name = prefix .. slot.Name
		end
	end

	local generatorSlots = floorPlot:FindFirstChild("GeneratorSlots")
	if generatorSlots then
		for _, slot in ipairs(generatorSlots:GetChildren()) do
			slot.Name = prefix .. slot.Name
		end
	end

	-- Positionner au-dessus du plot de référence, même rotation.
	-- On utilise FloorHeight comme pas fixe entre pivots (plus fiable que la bounding box).
	-- Base → F1 : +76.167  |  F1 → F2 : +76.167  |  soit F2 = base + 152.334
	local refCFrame   = refPlot:GetPivot()
	local floorCFrame = CFrame.new(refCFrame.Position + Vector3.new(0, FloorConfig.FloorHeight, 0))
		* refCFrame.Rotation

	floorPlot:PivotTo(floorCFrame)

	-- Parenter dans PlayerPlots
	local playerPlotsFolder = workspace:FindFirstChild("PlayerPlots")
	if not playerPlotsFolder then
		playerPlotsFolder        = Instance.new("Folder")
		playerPlotsFolder.Name   = "PlayerPlots"
		playerPlotsFolder.Parent = workspace
	end
	floorPlot.Parent = playerPlotsFolder

	-- Tracker
	if not _floors[userId] then _floors[userId] = {} end
	_floors[userId][floorNumber] = floorPlot

	print(string.format("[FloorService] ✅ Étage %d construit pour joueur %d", floorNumber, userId))
	return floorPlot
end

-- ─── Interne : initialise les slots d'un étage (synchrone) ────────────────────
-- @param userId    : number
-- @param floorPlot : Model
local function initializeFloor(userId, floorPlot)
	local ok1, e1 = pcall(function()
		PlacementService.InitializeSlotsFromPlot(userId, floorPlot)
	end)
	if not ok1 then warn("[FloorService] PlacementService error :", e1) end

	local ok2, e2 = pcall(function()
		GeneratorPlacementService.InitializeSlotsFromPlot(userId, floorPlot)
	end)
	if not ok2 then warn("[FloorService] GeneratorPlacementService error :", e2) end

	local ok3, e3 = pcall(function()
		ConveyorService.AppendPlotConveyors(userId, floorPlot)
	end)
	if not ok3 then warn("[FloorService] ConveyorService error :", e3) end
end

-- ─── API publique ─────────────────────────────────────────────────────────────

-- Débloque et construit un étage pour la session en cours
-- Appelé par PrestigeService immédiatement après un prestige
-- @param userId      : number
-- @param floorNumber : number
-- @return boolean success
function FloorService.UnlockFloor(userId, floorNumber)
	-- Déjà construit pour cette session ?
	if _floors[userId] and _floors[userId][floorNumber] then
		return false
	end

	local config = FloorConfig.Floors[floorNumber]
	if not config then
		warn("[FloorService] Configuration introuvable pour l'étage", floorNumber)
		return false
	end

	local floorPlot = buildFloorPlot(userId, floorNumber)
	if not floorPlot then return false end

	-- Petit délai pour laisser le plot se stabiliser dans le monde
	task.wait(0.5)

	initializeFloor(userId, floorPlot)

	-- Toit : se place en même temps que le dernier étage
	if floorNumber == FloorConfig.MaxFloors then
		buildRoof(userId)
	end

	print(string.format("[FloorService] ⭐ Étage %d débloqué pour joueur %d", floorNumber, userId))
	return true
end

-- Restaure les étages déjà débloqués à la reconnexion
-- Dérive l'état depuis playerData.prestigeLevel — aucune sauvegarde séparée
-- ⚠️  Doit être appelé AVANT RestorePlacedSpawners / RestorePlacedGenerators
-- @param userId : number
function FloorService.RestoreFloors(userId)
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData or playerData.prestigeLevel == 0 then return end

	for floorNumber = 1, FloorConfig.MaxFloors do
		local config = FloorConfig.Floors[floorNumber]
		if config and playerData.prestigeLevel >= config.RequiredPrestige then
			local floorPlot = buildFloorPlot(userId, floorNumber)
			if floorPlot then
				initializeFloor(userId, floorPlot)
			end
		end
	end

	-- Toit : même condition que le dernier étage (prestige 2)
	local roofConfig = FloorConfig.Floors[FloorConfig.MaxFloors]
	if roofConfig and playerData.prestigeLevel >= roofConfig.RequiredPrestige then
		buildRoof(userId)
	end

	print(string.format("[FloorService] Étages restaurés pour joueur %d", userId))
end

-- Supprime tous les plots d'étage d'un joueur (appelé à la déconnexion)
-- @param userId : number
function FloorService.RemoveFloors(userId)
	-- Détruire les étages
	if _floors[userId] then
		for _, floorPlot in pairs(_floors[userId]) do
			if floorPlot and floorPlot.Parent then
				floorPlot:Destroy()
			end
		end
		_floors[userId] = nil
	end

	-- Détruire le toit
	if _roofs[userId] then
		if _roofs[userId].Parent then
			_roofs[userId]:Destroy()
		end
		_roofs[userId] = nil
	end
end

return FloorService
