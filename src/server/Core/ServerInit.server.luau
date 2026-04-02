--[[
	Server initialization and dependency injection orchestrator
	Loads all modules and initializes services in correct order

	Initialization order is critical:
	1. Foundation: Data persistence layer
	2. Core: Plot management, player data, and economy
	3. Gameplay: Spawners, conveyors, collection, generators
	4. Economy: Shop and transactions
	5. Progression: Level and Prestige systems
	6. Handlers: Player lifecycle and remote communication

	All services use dependency injection (passed via Init functions)
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- ÉTAPE 0 : S'assurer que RemoteInterface et ses enfants
-- existent AVANT tout require() (certains modules ont des
-- WaitForChild() au niveau module).
-- ============================================================
local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then return existing end
	local instance = Instance.new(className)
	instance.Name   = name
	instance.Parent = parent
	return instance
end

local RemoteInterface = getOrCreate(ReplicatedStorage, "Folder",  "RemoteInterface")
local Events          = getOrCreate(RemoteInterface,   "Folder",  "Events")
local Functions       = getOrCreate(RemoteInterface,   "Folder",  "Functions")
local AdminFolder     = getOrCreate(RemoteInterface,   "Folder",  "Admin")

-- ─── Événements existants ───────────────────────────────────────────────────
getOrCreate(Events, "RemoteEvent", "OnMoneyChanged")
getOrCreate(Events, "RemoteEvent", "OnQuotaUpdated")
getOrCreate(Events, "RemoteEvent", "OnNotification")
getOrCreate(Events, "RemoteEvent", "OnEggsUpdated")
getOrCreate(Events, "RemoteEvent", "OnRevenuePerSecondChanged")

-- ─── Nouveaux événements (Prestige & Niveau) ────────────────────────────────
getOrCreate(Events, "RemoteEvent", "OnLevelChanged")      -- level, exp, expForNext
getOrCreate(Events, "RemoteEvent", "OnPrestigeChanged")   -- prestigeLevel, isMasterPrestige

-- ─── Fonctions existantes ───────────────────────────────────────────────────
getOrCreate(Functions, "RemoteFunction", "PurchaseSpawner")
getOrCreate(Functions, "RemoteFunction", "PlaceSpawner")
getOrCreate(Functions, "RemoteFunction", "RequestPlayerData")

-- ─── Nouvelle fonction (demande de prestige) ────────────────────────────────
getOrCreate(Functions, "RemoteFunction", "RequestPrestige")

-- ─── Admin ──────────────────────────────────────────────────────────────────
getOrCreate(AdminFolder, "RemoteFunction", "IsAdmin")
getOrCreate(AdminFolder, "RemoteEvent",    "ExecuteCommand")

print("✅ RemoteInterface prêt")

-- ─── Import configuration ───────────────────────────────────────────────────
local SpawnerConfig   = require(game:GetService("ReplicatedStorage").Shared.SpawnerConfig)
local ToyConfig       = require(script.Parent.Parent.Config.ToyConfig)
local GeneratorConfig = require(script.Parent.Parent.Config.GeneratorConfig)
local GameConfig      = require(script.Parent.Parent.Config.GameConfig)

-- ─── Import classes ─────────────────────────────────────────────────────────
local PlayerData = require(script.Parent.Parent.Classes.Data.PlayerData)

-- ─── Import foundation ──────────────────────────────────────────────────────
local DataService = require(script.Parent.Parent.Services.Foundation.DataService)

-- ─── Import core services ───────────────────────────────────────────────────
local PlotService        = require(script.Parent.Parent.Services.Core.PlotService)
local PlayerDataService  = require(script.Parent.Parent.Services.Core.PlayerDataService)
local MoneyService       = require(script.Parent.Parent.Services.Core.MoneyService)
local AdminService       = require(script.Parent.Parent.Services.Core.AdminService)
local AntiExploitService = require(script.Parent.Parent.Services.Core.AntiExploitService)

-- ─── Import gameplay services ───────────────────────────────────────────────
local SpawnerService            = require(script.Parent.Parent.Services.Gameplay.SpawnerService)
local ConveyorService           = require(script.Parent.Parent.Services.Gameplay.ConveyorService)
local GeneratorService          = require(script.Parent.Parent.Services.Gameplay.GeneratorService)
local CollectionService         = require(script.Parent.Parent.Services.Gameplay.CollectionService)
local PlacementService          = require(script.Parent.Parent.Services.Gameplay.PlacementService)
local GeneratorPlacementService = require(script.Parent.Parent.Services.Gameplay.GeneratorPlacementService)

-- ─── Import economy services ────────────────────────────────────────────────
local ShopService = require(script.Parent.Parent.Services.Economy.ShopService)

-- ─── Import progression services ────────────────────────────────────────────
local LevelService   = require(script.Parent.Parent.Services.Progression.LevelService)
local PrestigeService = require(script.Parent.Parent.Services.Progression.PrestigeService)

-- ─── Import handlers ────────────────────────────────────────────────────────
local PlayerLifecycleHandler   = require(script.Parent.Parent.Handlers.PlayerLifecycleHandler)
local RemoteFunctionHandler    = require(script.Parent.Parent.Handlers.RemoteFunctionHandler)
local AutoSaveHandler          = require(script.Parent.Parent.Handlers.AutoSaveHandler)
local DebugClearHandler        = require(script.Parent.Parent.Handlers.DebugClearHandler)

-- ─── Wrapper d'init sécurisé ────────────────────────────────────────────────
local function safeInit(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		warn("❌ [" .. name .. "] Init failed:", err)
	else
		print("✅ [" .. name .. "] OK")
	end
end

print("Server initialization starting...")

-- ─── Foundation ─────────────────────────────────────────────────────────────
safeInit("DataService",    function() DataService.Init() end)

-- ─── Core ────────────────────────────────────────────────────────────────────
safeInit("PlotService",         function() PlotService.Init() end)
safeInit("PlayerDataService",   function() PlayerDataService.Init(DataService, PlayerData) end)
safeInit("MoneyService",        function() MoneyService.Init(PlayerDataService) end)
safeInit("AntiExploitService",  function() AntiExploitService.Init() end)

-- ─── Gameplay ────────────────────────────────────────────────────────────────
safeInit("SpawnerService",             function() SpawnerService.Init(SpawnerConfig, ToyConfig, PlayerDataService) end)
safeInit("ConveyorService",            function() ConveyorService.Init() end)
safeInit("GeneratorService",           function() GeneratorService.Init(GeneratorConfig, MoneyService, ToyConfig) end)
safeInit("CollectionService",          function() CollectionService.Init(PlayerDataService, ToyConfig, GeneratorService) end)
safeInit("PlacementService",           function() PlacementService.Init(PlayerDataService, SpawnerService, SpawnerConfig) end)
safeInit("GeneratorPlacementService",  function() GeneratorPlacementService.Init(PlayerDataService, GeneratorService) end)

-- ─── Economy ─────────────────────────────────────────────────────────────────
safeInit("ShopService", function() ShopService.Init(SpawnerConfig, MoneyService, PlayerDataService) end)

-- ─── Progression ─────────────────────────────────────────────────────────────
safeInit("LevelService",    function() LevelService.Init(PlayerDataService) end)
safeInit("PrestigeService", function() PrestigeService.Init(PlayerDataService, PlacementService, ToyConfig) end)
safeInit("AdminService",    function() AdminService.Init(PlayerDataService, MoneyService, LevelService, PrestigeService) end)

-- ─── Handlers ────────────────────────────────────────────────────────────────
safeInit("PlayerLifecycleHandler", function()
	PlayerLifecycleHandler.Init(PlayerDataService, GeneratorService)
end)
safeInit("RemoteFunctionHandler", function()
	RemoteFunctionHandler.Init(ShopService, PlacementService, PlayerDataService)
end)
safeInit("AutoSaveHandler", function()
	AutoSaveHandler.Init(PlayerDataService, GameConfig)
	AutoSaveHandler.StartAutoSave()
end)
safeInit("DebugClearHandler", function()
	DebugClearHandler.Init(PlayerDataService)
end)

-- ─── Envoi des données initiales de progression au joueur lors de la connexion ──
Players.PlayerAdded:Connect(function(player)
	-- Attendre que PlayerDataService ait chargé les données
	task.defer(function()
		local userId = player.UserId
		-- Petit délai pour laisser le lifecycle handler charger les données en premier
		task.wait(2)
		if game.Players:GetPlayerByUserId(userId) then
			LevelService.SendInitialData(userId)
			PrestigeService.SendInitialData(userId)
		end
	end)
end)

-- ─── Connecter la RemoteFunction RequestPrestige ─────────────────────────────
local requestPrestigeFunc = Functions:WaitForChild("RequestPrestige")
requestPrestigeFunc.OnServerInvoke = function(player)
	local success, message = PrestigeService.DoPrestige(player.UserId)

	if success then
		-- Renvoyer les nouvelles données de level au client aussi
		LevelService.SendInitialData(player.UserId)
	end

	return success, message
end

print("🎮 Server initialized successfully!")
print("Services loaded:")
print("  - DataService")
print("  - PlotService")
print("  - PlayerDataService")
print("  - MoneyService")
print("  - AntiExploitService")
print("  - AdminService")
print("  - SpawnerService")
print("  - ConveyorService")
print("  - GeneratorService")
print("  - CollectionService")
print("  - PlacementService")
print("  - GeneratorPlacementService")
print("  - ShopService")
print("  - LevelService")
print("  - PrestigeService")
print("  - PlayerLifecycleHandler")
print("  - RemoteFunctionHandler")
print("  - AutoSaveHandler")
