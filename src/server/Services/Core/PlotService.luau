--[[
	Plot management service
	Handles player plot creation, assignment, and cleanup
	
	Each player gets their own plot with:
	- 5 spawner slots
	- 10 generator slots
	- Personal conveyors
	- Personal collection zone
	
	Supports up to 8 players simultaneously with random slot assignment
]]

local PlotService = {}

-- Private variables
local _plots = {}        -- [userId] = {plot = Model, slotNumber = number}
local _plotPositions = {} -- Table of Vector3 positions
local _mapCenter = Vector3.new(0, 0, 0)  -- Centre calculé depuis les marqueurs
local _activePlots = 0
local MAX_PLOTS = 8
local _availableSlots = {}  -- Table of available slot numbers

-- Offset Y appliqué au-dessus du repère de position (ajuste selon ton template)
local PLOT_SPAWN_Y_OFFSET = 5

-- Services
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- Initializes plot service and caches plot positions
function PlotService.Init()
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then
		warn("❌ CONFIGURATION MANQUANTE : Crée un dossier nommé 'Plots' dans Workspace contenant 8 Models (un par emplacement de slot)")
		return
	end

	-- ⭐ Stocker nom + position ensemble (supporte Models ET BaseParts)
	local plotData = {}

	for _, child in ipairs(plotsFolder:GetChildren()) do
		local positionPart = nil

		if child:IsA("Model") then
			-- Priorité au PrimaryPart, sinon premier BasePart trouvé
			positionPart = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
		elseif child:IsA("BasePart") then
			positionPart = child
		end

		if positionPart then
			table.insert(plotData, {
				name = child.Name,
				position = positionPart.Position
			})
		end
	end

	-- Sort by position
	table.sort(plotData, function(a, b)
		return a.position.X < b.position.X or (a.position.X == b.position.X and a.position.Z < b.position.Z)
	end)

	-- ⭐ Afficher mapping
	print("📍 SLOT MAPPING:")
	for i, data in ipairs(plotData) do
		table.insert(_plotPositions, data.position)
		print("  Slot", i, "=", data.name, "at", data.position)
	end

	-- Récupérer le centre de la map depuis le modèle "Marchand"
	local marchand = Workspace:FindFirstChild("Maps")
		and Workspace.Maps:FindFirstChild("Hub Centrale")
		and Workspace.Maps["Hub Centrale"]:FindFirstChild("Decoration")
		and Workspace.Maps["Hub Centrale"].Decoration:FindFirstChild("Marchand")

	if marchand then
		local marchandPart = marchand:IsA("BasePart") and marchand
			or (marchand.PrimaryPart)
			or marchand:FindFirstChildWhichIsA("BasePart")
		if marchandPart then
			_mapCenter = marchandPart.Position
			print("📍 Centre de la map → Marchand :", _mapCenter)
		else
			warn("❌ Marchand trouvé mais sans BasePart — vérifie son PrimaryPart")
		end
	else
		warn("❌ Modèle 'Marchand' introuvable dans Workspace.Maps.Hub Centrale.Decoration — centre par défaut utilisé")
	end

	-- Initialize available slots
	for i = 1, #_plotPositions do
		table.insert(_availableSlots, i)
	end

	print("PlotService initialized with", #_plotPositions, "plot positions")
end

-- Creates and assigns a plot to a player
-- @param userId: number - Player's user ID
-- @return Model - The created plot, or nil if no space
function PlotService.CreatePlot(userId)
	-- Check if player already has a plot
	if _plots[userId] then
		warn("Player", userId, "already has plot")
		return _plots[userId].plot  -- ⭐ Retourner le plot du plotData
	end

	-- Check if slots available
	if #_availableSlots == 0 then
		if #_plotPositions == 0 then
			warn("❌ Aucun emplacement de slot trouvé — crée le dossier Workspace.Plots avec 8 Models")
		else
			warn("❌ Serveur complet (", MAX_PLOTS, "/", MAX_PLOTS, "joueurs)")
		end
		return nil
	end

	-- Get template
	local template = ServerStorage:FindFirstChild("PlayerPlotTemplate")
	if not template then
		warn("❌ PlayerPlotTemplate not found in ServerStorage! Vérifie que le modèle est bien dans ServerStorage et nommé 'PlayerPlotTemplate'")
		return nil
	end

	-- Clone template
	local plot = template:Clone()
	plot.Name = "Plot_" .. userId

	-- Choose random available slot
	local randomIndex = math.random(1, #_availableSlots)
	local slotNumber = _availableSlots[randomIndex]

	-- Remove slot from available slots
	table.remove(_availableSlots, randomIndex)

	-- Get position for this slot
	local position = _plotPositions[slotNumber]
	if not position then
		warn("❌ No plot position found for slot", slotNumber, "- vérifie que Workspace.Plots contient bien 8 emplacements")
		return nil
	end

	-- Calculer la direction vers le centre (sur le plan XZ uniquement)
	local spawnPosition = position + Vector3.new(0, PLOT_SPAWN_Y_OFFSET, 0)
	local centerAtSameHeight = Vector3.new(_mapCenter.X, spawnPosition.Y, _mapCenter.Z)

	-- Extraire l'angle Y exact depuis CFrame.lookAt, puis snapper au multiple de 90° le plus proche
	-- +180° car le front du template est sur +Z (lookAt vise avec -Z)
	local lookCFrame = CFrame.lookAt(spawnPosition, centerAtSameHeight)
	local _, rawAngleY, _ = lookCFrame:ToEulerAnglesYXZ()
	local snappedAngle = (math.round(math.deg(rawAngleY) / 90) * 90 + 90) % 360
	local cframe = CFrame.new(spawnPosition) * CFrame.Angles(0, math.rad(snappedAngle), 0)

	-- Position plot
	plot:PivotTo(cframe)

	-- Find or create PlayerPlots folder
	local playerPlotsFolder = Workspace:FindFirstChild("PlayerPlots")
	if not playerPlotsFolder then
		playerPlotsFolder = Instance.new("Folder")
		playerPlotsFolder.Name = "PlayerPlots"
		playerPlotsFolder.Parent = Workspace
	end

	-- Parent plot to workspace
	plot.Parent = playerPlotsFolder

	-- ⭐ Track plot WITH slot number
	_plots[userId] = {
		plot = plot,
		slotNumber = slotNumber
	}
	_activePlots += 1

	print("✅ Plot créé pour", userId, "au slot", slotNumber, "→ rotation snappée :", snappedAngle, "°")
	print("   Slots restants :", #_availableSlots)

	return plot
end

-- Removes a player's plot and frees the slot
-- @param userId: number - Player's user ID
function PlotService.RemovePlot(userId)
	local plotData = _plots[userId]
	if not plotData then
		return
	end

	-- Destroy plot
	plotData.plot:Destroy()

	-- Free the slot (make it available again)
	table.insert(_availableSlots, plotData.slotNumber)

	-- Untrack
	_plots[userId] = nil
	_activePlots -= 1

	print("Plot removed for", userId, "- Slot", plotData.slotNumber, "is now available")
end

-- Gets a player's plot
-- @param userId: number - Player's user ID
-- @return Model - The player's plot, or nil if none
function PlotService.GetPlot(userId)
	local plotData = _plots[userId]
	return plotData and plotData.plot or nil
end

return PlotService
