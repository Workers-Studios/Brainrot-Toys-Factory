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
local _plots = {}  -- [userId] = {plot = Model, slotNumber = number}
local _plotPositions = {}  -- Table of Vector3 positions
local _activePlots = 0
local MAX_PLOTS = 8
local _availableSlots = {}  -- Table of available slot numbers

-- Services
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- Initializes plot service and caches plot positions
function PlotService.Init()
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then
		error("Plots folder not found in Workspace!")
	end

	-- ⭐ Stocker nom + position ensemble
	local plotData = {}

	for _, child in ipairs(plotsFolder:GetChildren()) do
		if child:IsA("Model") then
			local positionPart = child:FindFirstChildWhichIsA("BasePart")
			if positionPart then
				table.insert(plotData, {
					name = child.Name,
					position = positionPart.Position
				})
			end
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
		warn("Server full, cannot create plot for", userId)
		return nil
	end

	-- Get template
	local template = ServerStorage:FindFirstChild("PlayerPlotTemplate")
	if not template then
		error("PlayerPlotTemplate not found in ServerStorage!")
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
		error("No plot position available for slot", slotNumber)
	end

	-- Rotation by slot
	local rotations = {
		180, -- slot7
		180, -- slot8
		90,  -- slot1
		270, -- slot5
		90,  -- slot2
		270, -- slot6
		0,   -- slot3
		0    -- slot4
	}

	local rotation = rotations[slotNumber] or 0

	-- Create CFrame with position AND rotation
	local cframe = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation), 0)

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
	
	local spawnCheck = plot:FindFirstChild("SpawnLocation", true)
	if spawnCheck then
		print("✅ SpawnLocation found in plot at", spawnCheck.Position)
	else
		warn("❌ SpawnLocation NOT FOUND in plot!")
		print("Plot children:")
		for _, child in ipairs(plot:GetChildren()) do
			print("  -", child.Name, child.ClassName)
		end
	end

	-- ⭐ Track plot WITH slot number
	_plots[userId] = {
		plot = plot,
		slotNumber = slotNumber
	}
	_activePlots += 1

	print("✅ Plot created for", userId, "at RANDOM slot", slotNumber, "with rotation", rotation, "°")
	print("   Remaining available slots:", #_availableSlots)

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
