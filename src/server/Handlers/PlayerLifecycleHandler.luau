--[[
	Handles player connection and disconnection events
	Manages player data loading, plot creation, placement restoration, and cleanup
	
	Main responsibilities:
	- Create personal plot for each player
	- Load player data on join
	- Teleport player to their plot
	- Initialize plot slots (spawners, generators, conveyors)
	- Restore placed spawners and generators from previous session
	- Stop generators and save data on disconnect
	- Remove plot on disconnect
	
	Connected to: Players.PlayerAdded, Players.PlayerRemoving
]]

local PlayerLifecycleHandler = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies (required once)
local PlotService = require(script.Parent.Parent.Services.Core.PlotService)
local PlacementService = require(script.Parent.Parent.Services.Gameplay.PlacementService)
local SpawnerConfig = require(script.Parent.Parent.Config.SpawnerConfig)
local GeneratorPlacementService = require(script.Parent.Parent.Services.Gameplay.GeneratorPlacementService)
local ConveyorService = require(script.Parent.Parent.Services.Gameplay.ConveyorService)
local ToyConfig = require(script.Parent.Parent.Config.ToyConfig)

-- Private references
local _PlayerDataService = nil
local _GeneratorService = nil

-- Initializes handler and connects to player events
-- @param PlayerDataService: service - Player data management service
-- @param GeneratorService: service - Generator management service
function PlayerLifecycleHandler.Init(PlayerDataService, GeneratorService)
	_PlayerDataService = PlayerDataService
	_GeneratorService = GeneratorService

	Players.PlayerAdded:Connect(PlayerLifecycleHandler.OnPlayerAdded)
	Players.PlayerRemoving:Connect(PlayerLifecycleHandler.OnPlayerRemoving)

	-- Gère les joueurs déjà présents au moment de l'init (cas Studio + edge cases serveur)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(PlayerLifecycleHandler.OnPlayerAdded, player)
	end

	print("PlayerLifecycleHandler initialized")
end

-- Handles player join: creates plot, loads data, and restores placements
-- @param player: Player - Roblox player instance
function PlayerLifecycleHandler.OnPlayerAdded(player)
	local userId = player.UserId

	-- ⭐ CREATE PLAYER PLOT
	local plot
	local plotSuccess, plotErr = pcall(function()
		plot = PlotService.CreatePlot(userId)
	end)

	if not plotSuccess then
		warn("❌ CreatePlot error for", player.Name, ":", plotErr)
		player:Kick("Erreur lors de la création du plot. Contacte un administrateur.")
		return
	end

	if not plot then
		player:Kick("Serveur complet (8/8 joueurs) ou configuration manquante.")
		return
	end

	-- ⭐ WAIT FOR PLOT TO BE READY
	task.wait(0.5)

	-- Load player data from DataStore
	_PlayerDataService.LoadPlayer(userId)

	-- ⭐ TELEPORT PLAYER TO THEIR PLOT (improved)
	local function TeleportToPlot(character)
		-- Attendre que HumanoidRootPart soit prêt avant toute tentative de téléport
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
		if not humanoidRootPart then
			warn("⚠️ HumanoidRootPart not found for", player.Name)
			return
		end

		-- Try multiple times if needed
		for attempt = 1, 3 do
			-- Refresh plot reference
			local currentPlot = PlotService.GetPlot(userId)
			if not currentPlot then
				warn("⚠️ Plot not found for", userId, "attempt", attempt)
				task.wait(0.5)
				continue
			end

			-- Find spawn location
			local spawnLocation = currentPlot:FindFirstChild("SpawnLocation", true)

			if spawnLocation and spawnLocation:IsA("BasePart") then
				character:PivotTo(spawnLocation.CFrame * CFrame.new(0, 5, 0))
				return
			end

			-- Fallback : PrimaryPart
			if currentPlot.PrimaryPart then
				character:PivotTo(currentPlot.PrimaryPart.CFrame * CFrame.new(0, 10, 0))
				return
			end

			-- Fallback ultime : centre du plot via GetBoundingBox
			local cf, _ = currentPlot:GetBoundingBox()
			if cf then
				character:PivotTo(cf * CFrame.new(0, 10, 0))
				return
			end

			task.wait(0.5)
		end

		-- Toutes les tentatives ont échoué
		warn("❌ Failed to teleport player", player.Name, "after 3 attempts")
	end

	-- Connect to character spawn
	player.CharacterAdded:Connect(TeleportToPlot)

	-- Teleport if character already exists
	if player.Character then
		task.spawn(function()
			TeleportToPlot(player.Character)
		end)
	end

	-- Sync data to client
	task.spawn(function()
		task.wait(0.5)

		local playerData = _PlayerDataService.GetPlayerData(userId)
		if not playerData then
			warn("PlayerData not found for", userId)
			return
		end

		-- Sync money
		local OnMoneyChanged = ReplicatedStorage.RemoteInterface.Events.OnMoneyChanged
		OnMoneyChanged:FireClient(player, playerData.money)

		-- Sync quotas (structure plate : [rarity] = count)
		local OnQuotaUpdated = ReplicatedStorage.RemoteInterface.Events.OnQuotaUpdated
		for rarity, currentCount in pairs(playerData.quotaProgress) do
			local toyData = ToyConfig[rarity]
			if toyData then
				OnQuotaUpdated:FireClient(player, rarity, currentCount, toyData.QuotaToGenerator)
			end
		end

	end)

	-- Wait for plot to be ready
	task.wait(1)

	-- ⭐ INITIALIZE PLOT SLOTS
	local success1, err1 = pcall(function()
		PlacementService.InitializePlotSlots(userId)
	end)
	if not success1 then
		warn("Error initializing spawner slots:", err1)
	end

	local success2, err2 = pcall(function()
		GeneratorPlacementService.InitializePlotSlots(userId)
	end)
	if not success2 then
		warn("Error initializing generator slots:", err2)
	end

	local success3, err3 = pcall(function()
		ConveyorService.InitializePlotConveyors(userId)
	end)
	if not success3 then
		warn("Error initializing conveyors:", err3)
	end

	-- ⭐ REDONNER LES TOOLS SPAWNER ET OEUFS DE L'INVENTAIRE
	task.spawn(function()
		local playerData = _PlayerDataService.GetPlayerData(userId)
		if playerData then
			-- Spawner tools
			for rarity, count in pairs(playerData.inventory) do
				if SpawnerConfig[rarity] then
					for i = 1, count do
						PlacementService.GiveSpawnerTool(player, rarity)
					end
				end
			end
			-- Egg tools (oeufs) — structure plate : [rarity] = count
			for rarity, count in pairs(playerData.generatorInventory) do
				if count and count > 0 then
					for _ = 1, count do
						PlacementService.GiveEggTool(player, rarity)
					end
				end
			end
			-- Brainrot tools (récupérés depuis les socles)
			for _, b in ipairs(playerData.brainrotInventory or {}) do
				PlacementService.GiveBrainrotTool(player, b.Name, b.ModelName or "", b.Rarity, b.RevenuePerSecond)
			end
		end
	end)

	-- ⭐ RESTORE PLACED SPAWNERS AND GENERATORS
	local success4, err4 = pcall(function()
		PlacementService.RestorePlacedSpawners(userId)
	end)
	if not success4 then
		warn("Error restoring spawners:", err4)
	end

	local success5, err5 = pcall(function()
		GeneratorPlacementService.RestorePlacedGenerators(userId)
	end)
	if not success5 then
		warn("Error restoring generators:", err5)
	end

	-- Sync revenue/s après restore (délai pour que le client soit connecté à l'event)
	task.spawn(function()
		task.wait(1)
		GeneratorPlacementService.SyncRevenueToClient(userId)
	end)

	print("✅ Player connected:", player.Name)
end

-- Handles player disconnect: stops generators, saves data, and removes plot
-- @param player: Player - Roblox player instance
function PlayerLifecycleHandler.OnPlayerRemoving(player)
	local userId = player.UserId

	-- Stop conveyor loops
	ConveyorService.StopConveyors(userId)

	-- Stop all active generator loops
	_GeneratorService.StopAllGenerators(userId)

	-- Save player data immediately on disconnect (bypass debounce)
	_PlayerDataService.SavePlayerImmediate(userId)

	-- Remove from memory
	_PlayerDataService.RemovePlayer(userId)

	-- ⭐ REMOVE PLOT
	PlotService.RemovePlot(userId)

	print("❌ Player disconnected:", player.Name)
end

return PlayerLifecycleHandler
