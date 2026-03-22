--[[
	Manages generator placement on physical slots and restoration
	Handles player interaction with generator slots via ProximityPrompts
	
	Main responsibilities:
	- Initialize generator slots from player's personal plot
	- Handle generator placement from inventory onto slots (per-player)
	- Create visual representation of placed generators
	- Start generator income loops
	- Restore placed generators on player rejoin
	- Save generator placements to DataStore
	
	Placement workflow: Player approaches slot → presses E → places generator from inventory → generator generates income
]]

local GeneratorPlacementService = {}

local PlotService = require(script.Parent.Parent.Core.PlotService)
local PlacementService = require(script.Parent.PlacementService)

local _PlayerDataService = nil
local _GeneratorService = nil
local _generatorSlots = {}  -- [userId_slotName] = slotData

-- Initializes service (no longer searches for global slots)
-- @param PlayerDataService: service - Player data management service
-- @param GeneratorService: service - Generator management service
function GeneratorPlacementService.Init(PlayerDataService, GeneratorService)
	_PlayerDataService = PlayerDataService
	_GeneratorService = GeneratorService

	print("GeneratorPlacementService initialized")
end

-- Initializes generator slots for a specific player's plot
-- @param userId: number - Player's user ID
function GeneratorPlacementService.InitializePlotSlots(userId)
	local plot = PlotService.GetPlot(userId)
	if not plot then
		warn("Plot not found for userId:", userId)
		return
	end

	local slotsFolder = plot:FindFirstChild("GeneratorSlots")
	if not slotsFolder then
		warn("GeneratorSlots not found in plot for userId:", userId)
		return
	end

	-- Initialize each slot in the plot
	for _, slotModel in ipairs(slotsFolder:GetChildren()) do
		if not slotModel:IsA("Model") or not slotModel.PrimaryPart then
			continue
		end

		local proximityPrompt = slotModel.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
		if not proximityPrompt then
			continue
		end

		-- Connect prompt (ownership check)
		proximityPrompt.Triggered:Connect(function(player)
			if player.UserId == userId then
				GeneratorPlacementService.OnSlotTriggered(player, slotModel)
			end
		end)

		-- Create unique slot key
		local slotKey = userId .. "_" .. slotModel.Name

		-- Store slot data
		_generatorSlots[slotKey] = {
			Model = slotModel,
			Occupied = false,
			GeneratorPart = nil,
			UserId = userId
		}
	end

	print("Initialized", #slotsFolder:GetChildren(), "generator slots for plot", userId)
end

-- Handles player interaction with generator slot
-- @param player: Player - Player who triggered the slot
-- @param slotModel: Model - Slot model triggered
function GeneratorPlacementService.OnSlotTriggered(player, slotModel)
	local userId = player.UserId
	local slotKey = userId .. "_" .. slotModel.Name

	local slotData = _generatorSlots[slotKey]
	if not slotData then
		warn("Slot data not found:", slotKey)
		return
	end

	-- Check if slot already occupied
	if slotData.Occupied then
		print("Slot already occupied")
		return
	end

	-- Get player data
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then
		warn("PlayerData not found for", userId)
		return
	end

	-- Lire le Tool brainrot équipé
	local player = game.Players:GetPlayerByUserId(userId)
	local _, generatorType, rarity = PlacementService.GetEquippedBrainrotInfo(player)

	if not generatorType then
		warn("Aucun brainrot équipé pour", userId)
		return
	end

	-- Mark slot as occupied
	slotData.Occupied = true

	-- Create visual generator
	local generatorPart = Instance.new("Part")
	generatorPart.Name = generatorType
	generatorPart.Size = Vector3.new(4, 3, 4)
	generatorPart.Position = slotData.Model.PrimaryPart.Position + Vector3.new(0, 2, 0)
	generatorPart.Anchored = true
	generatorPart.CanCollide = true

	-- Color by rarity
	if rarity == "Common" then
		generatorPart.Color = Color3.fromRGB(135, 135, 135)
	elseif rarity == "Uncommon" then
		generatorPart.Color = Color3.fromRGB(30, 180, 30)
	elseif rarity == "Rare" then
		generatorPart.Color = Color3.fromRGB(0, 100, 255)
	elseif rarity == "Epic" then
		generatorPart.Color = Color3.fromRGB(128, 0, 128)
	elseif rarity == "Legendary" then
		generatorPart.Color = Color3.fromRGB(255, 215, 0)
	end

	generatorPart.Parent = slotData.Model
	slotData.GeneratorPart = generatorPart

	-- Disable proximity prompt
	local proximityPrompt = slotData.Model:FindFirstChild("ProximityPrompt", true)
	if proximityPrompt then
		proximityPrompt.Enabled = false
	end

	-- Supprimer le Tool de la main du joueur
	PlacementService.RemoveBrainrotTool(player, generatorType, rarity)

	-- Get income rate from config
	local GeneratorConfig = require(game.ServerScriptService.Config.GeneratorConfig)
	local incomeRate = GeneratorConfig[generatorType].BaseRevenuePerSecond[rarity]

	-- Start generator loop with unique ID
	local generatorId = slotKey
	_GeneratorService.StartGeneratorLoop(userId, generatorId, incomeRate, 1)

	-- Save placement to DataStore
	table.insert(playerData.placedGenerators, {
		SlotName = slotModel.Name,
		GeneratorType = generatorType,
		Rarity = rarity
	})

	_PlayerDataService.SavePlayer(userId)

	print("Generator placed:", generatorType, rarity, "on", slotModel.Name)
end

-- Gets first available generator from player inventory
-- @param playerData: PlayerData - Player data instance
-- @return string|nil, string|nil - Generator type and rarity, or nil if none available
function GeneratorPlacementService.GetFirstAvailableGenerator(playerData)
	local GeneratorConfig = require(game.ServerScriptService.Config.GeneratorConfig)
	local rarityOrder = {"Common", "Rare", "Epic", "Legendary"}

	-- Check each generator type
	for generatorType, _ in pairs(GeneratorConfig) do
		for _, rarity in ipairs(rarityOrder) do
			if playerData.generatorInventory[generatorType] and 
				playerData.generatorInventory[generatorType][rarity] and
				playerData.generatorInventory[generatorType][rarity] > 0 then
				return generatorType, rarity
			end
		end
	end

	return nil, nil
end

-- Restores placed generators from previous session
-- @param userId: number - Player's user ID
function GeneratorPlacementService.RestorePlacedGenerators(userId)
	print("RestorePlacedGenerators called for", userId)

	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then
		print("PlayerData not found")
		return
	end

	print("Generators to restore:", #playerData.placedGenerators)

	local GeneratorConfig = require(game.ServerScriptService.Config.GeneratorConfig)

	-- Restore each saved generator
	for _, placedData in ipairs(playerData.placedGenerators) do
		local slotName = placedData.SlotName
		local generatorType = placedData.GeneratorType
		local rarity = placedData.Rarity

		-- Create unique slot key
		local slotKey = userId .. "_" .. slotName

		-- Find slot
		local slotData = _generatorSlots[slotKey]
		if not slotData then
			warn("Slot not found:", slotKey)
			continue
		end

		-- Mark as occupied
		slotData.Occupied = true

		-- Recreate visual generator
		local generatorPart = Instance.new("Part")
		generatorPart.Name = generatorType
		generatorPart.Size = Vector3.new(4, 3, 4)
		generatorPart.Position = slotData.Model.PrimaryPart.Position + Vector3.new(0, 2, 0)
		generatorPart.Anchored = true
		generatorPart.CanCollide = true

		-- Color by rarity
		if rarity == "Common" then
			generatorPart.Color = Color3.fromRGB(135, 135, 135)
		elseif rarity == "Rare" then
			generatorPart.Color = Color3.fromRGB(0, 0, 255)
		elseif rarity == "Epic" then
			generatorPart.Color = Color3.fromRGB(128, 0, 128)
		elseif rarity == "Legendary" then
			generatorPart.Color = Color3.fromRGB(255, 215, 0)
		end

		generatorPart.Parent = slotData.Model
		slotData.GeneratorPart = generatorPart

		-- Disable proximity prompt
		local proximityPrompt = slotData.Model:FindFirstChild("ProximityPrompt", true)
		if proximityPrompt then
			proximityPrompt.Enabled = false
		end

		-- Restart income generation with unique ID
		local incomeRate = GeneratorConfig[generatorType].BaseRevenuePerSecond[rarity]
		local generatorId = slotKey
		_GeneratorService.StartGeneratorLoop(userId, generatorId, incomeRate, 1)

		print("Generator restored:", slotName, generatorType, rarity)
	end
end

return GeneratorPlacementService