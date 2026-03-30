--[[
	Gestion des connexions / déconnexions joueurs
	Orchestre la création du plot, le chargement des données, la restauration
	des placements et le nettoyage au départ

	Connexions : Players.PlayerAdded, Players.PlayerRemoving
]]

local PlayerLifecycleHandler = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network           = require(ReplicatedStorage.Shared.Network)

local PlotService               = require(script.Parent.Parent.Services.Core.PlotService)
local PlacementService          = require(script.Parent.Parent.Services.Gameplay.PlacementService)
local SpawnerConfig             = require(script.Parent.Parent.Config.SpawnerConfig)
local GeneratorPlacementService = require(script.Parent.Parent.Services.Gameplay.GeneratorPlacementService)
local ConveyorService           = require(script.Parent.Parent.Services.Gameplay.ConveyorService)
local ToyConfig                 = require(script.Parent.Parent.Config.ToyConfig)

local _PlayerDataService = nil
local _GeneratorService  = nil

-- Remotes (créées par ServerInit avant ce require)
local _Events           = ReplicatedStorage:WaitForChild("RemoteInterface"):WaitForChild("Events")
local _OnMoneyChanged   = _Events:WaitForChild(Network.Events.OnMoneyChanged)
local _OnQuotaUpdated   = _Events:WaitForChild(Network.Events.OnQuotaUpdated)

-- Initialise le handler
function PlayerLifecycleHandler.Init(PlayerDataService, GeneratorService)
	_PlayerDataService = PlayerDataService
	_GeneratorService  = GeneratorService

	Players.PlayerAdded:Connect(PlayerLifecycleHandler.OnPlayerAdded)
	Players.PlayerRemoving:Connect(PlayerLifecycleHandler.OnPlayerRemoving)

	-- Gère les joueurs déjà présents (cas Studio / edge cases)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(PlayerLifecycleHandler.OnPlayerAdded, player)
	end

	print("PlayerLifecycleHandler initialized")
end

-- Gère l'arrivée d'un joueur : plot, data, téléport, restoration
function PlayerLifecycleHandler.OnPlayerAdded(player)
	local userId = player.UserId

	-- Création du plot
	local plot
	local ok, err = pcall(function()
		plot = PlotService.CreatePlot(userId)
	end)
	if not ok then
		warn("❌ CreatePlot error pour", player.Name, ":", err)
		player:Kick("Erreur lors de la création du plot. Contacte un administrateur.")
		return
	end
	if not plot then
		player:Kick("Serveur complet (8/8 joueurs) ou configuration manquante.")
		return
	end

	task.wait(0.5)

	-- Chargement des données
	_PlayerDataService.LoadPlayer(userId)

	-- Téléportation au plot
	local function teleportToPlot(character)
		local hrp = character:WaitForChild("HumanoidRootPart", 10)
		if not hrp then
			warn("⚠️ HumanoidRootPart introuvable pour", player.Name)
			return
		end

		for attempt = 1, 3 do
			local currentPlot = PlotService.GetPlot(userId)
			if not currentPlot then task.wait(0.5); continue end

			local spawnLocation = currentPlot:FindFirstChild("SpawnLocation", true)
			if spawnLocation and spawnLocation:IsA("BasePart") then
				character:PivotTo(spawnLocation.CFrame * CFrame.new(0, 5, 0))
				return
			end
			if currentPlot.PrimaryPart then
				character:PivotTo(currentPlot.PrimaryPart.CFrame * CFrame.new(0, 10, 0))
				return
			end
			local cf, _ = currentPlot:GetBoundingBox()
			if cf then
				character:PivotTo(cf * CFrame.new(0, 10, 0))
				return
			end
			task.wait(0.5)
		end

		warn("❌ Téléportation échouée après 3 tentatives pour", player.Name)
	end

	player.CharacterAdded:Connect(teleportToPlot)
	if player.Character then
		task.spawn(teleportToPlot, player.Character)
	end

	-- Sync données client
	task.spawn(function()
		task.wait(0.5)
		local playerData = _PlayerDataService.GetPlayerData(userId)
		if not playerData then
			warn("PlayerData introuvable pour", userId)
			return
		end

		_OnMoneyChanged:FireClient(player, playerData.money)

		for rarity, currentCount in pairs(playerData.quotaProgress) do
			local toyData = ToyConfig[rarity]
			if toyData then
				_OnQuotaUpdated:FireClient(player, rarity, currentCount, toyData.QuotaToGenerator)
			end
		end
	end)

	task.wait(1)

	-- Initialisation des slots
	local function safeCall(label, fn)
		local s, e = pcall(fn)
		if not s then warn("Erreur", label, ":", e) end
	end

	safeCall("InitializePlotSlots",           function() PlacementService.InitializePlotSlots(userId) end)
	safeCall("InitializePlotSlots (Generator)",function() GeneratorPlacementService.InitializePlotSlots(userId) end)
	safeCall("InitializePlotConveyors",        function() ConveyorService.InitializePlotConveyors(userId) end)

	-- Redonner les tools de l'inventaire
	task.spawn(function()
		local playerData = _PlayerDataService.GetPlayerData(userId)
		if not playerData then return end

		for rarity, count in pairs(playerData.inventory) do
			if SpawnerConfig[rarity] then
				for _ = 1, count do
					PlacementService.GiveSpawnerTool(player, rarity)
				end
			end
		end

		for rarity, count in pairs(playerData.generatorInventory) do
			if count and count > 0 then
				for _ = 1, count do
					PlacementService.GiveEggTool(player, rarity)
				end
			end
		end

		for _, b in ipairs(playerData.brainrotInventory or {}) do
			PlacementService.GiveBrainrotTool(player, b.Name, b.ModelName or "", b.Rarity, b.RevenuePerSecond)
		end
	end)

	-- Restauration des placements
	safeCall("RestorePlacedSpawners",    function() PlacementService.RestorePlacedSpawners(userId) end)
	safeCall("RestorePlacedGenerators",  function() GeneratorPlacementService.RestorePlacedGenerators(userId) end)

	-- Sync revenue/s après restore
	task.spawn(function()
		task.wait(1)
		GeneratorPlacementService.SyncRevenueToClient(userId)
	end)

	print("✅ Joueur connecté :", player.Name)
end

-- Gère le départ d'un joueur : arrêt générateurs, save, nettoyage
function PlayerLifecycleHandler.OnPlayerRemoving(player)
	local userId = player.UserId

	ConveyorService.StopConveyors(userId)
	_GeneratorService.StopAllGenerators(userId)
	_PlayerDataService.SavePlayerImmediate(userId)
	_PlayerDataService.RemovePlayer(userId)
	PlotService.RemovePlot(userId)

	print("❌ Joueur déconnecté :", player.Name)
end

return PlayerLifecycleHandler
