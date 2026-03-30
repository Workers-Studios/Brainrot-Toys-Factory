--[[
	Orchestrateur d'initialisation serveur
	Charge tous les modules et initialise les services dans le bon ordre.

	Ordre d'initialisation :
	1. Framework    : ServiceLocator, Signal (aucune dépendance)
	2. Remotes      : création des RemoteEvents/Functions via Network
	3. Foundation   : persistance des données
	4. Core         : plot, données joueur, économie
	5. Gameplay     : spawners, convoyeurs, collection, générateurs
	6. Economy      : shop et transactions
	7. Handlers     : lifecycle joueur et communication distante

	Pattern : chaque service est enregistré dans ServiceLocator après Init()
	          → les services tardifs peuvent faire ServiceLocator.Get() sans
	            avoir reçu la référence en paramètre.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- Framework (chargé en premier — pas de dépendances)
-- ============================================================
local ServiceLocator = require(script.Parent.Parent.Framework.ServiceLocator)
local Signal         = require(script.Parent.Parent.Framework.Signal)
local Network        = require(ReplicatedStorage.Shared.Network)

-- ============================================================
-- Création des RemoteEvents / RemoteFunctions
-- Effectuée AVANT tout require() qui ferait des WaitForChild()
-- ============================================================
local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then return existing end
	local instance = Instance.new(className)
	instance.Name  = name
	instance.Parent = parent
	return instance
end

local RemoteInterface = getOrCreate(ReplicatedStorage,  "Folder",   "RemoteInterface")
local Events          = getOrCreate(RemoteInterface,    "Folder",   "Events")
local Functions       = getOrCreate(RemoteInterface,    "Folder",   "Functions")
local AdminFolder     = getOrCreate(RemoteInterface,    "Folder",   "Admin")

-- Events
getOrCreate(Events, "RemoteEvent", Network.Events.OnMoneyChanged)
getOrCreate(Events, "RemoteEvent", Network.Events.OnQuotaUpdated)
getOrCreate(Events, "RemoteEvent", Network.Events.OnNotification)
getOrCreate(Events, "RemoteEvent", Network.Events.OnEggsUpdated)
getOrCreate(Events, "RemoteEvent", Network.Events.OnRevenuePerSecondChanged)

-- Functions
getOrCreate(Functions, "RemoteFunction", Network.Functions.PurchaseSpawner)
getOrCreate(Functions, "RemoteFunction", Network.Functions.PlaceSpawner)
getOrCreate(Functions, "RemoteFunction", Network.Functions.RequestPlayerData)

-- Admin
getOrCreate(AdminFolder, "RemoteFunction", Network.Admin.IsAdmin)
getOrCreate(AdminFolder, "RemoteEvent",    Network.Admin.ExecuteCommand)

print("✅ RemoteInterface prêt")

-- ============================================================
-- Import des modules
-- ============================================================
local SpawnerConfig   = require(script.Parent.Parent.Config.SpawnerConfig)
local ToyConfig       = require(script.Parent.Parent.Config.ToyConfig)
local GeneratorConfig = require(script.Parent.Parent.Config.GeneratorConfig)
local GameConfig      = require(script.Parent.Parent.Config.GameConfig)
local PlayerData      = require(script.Parent.Parent.Classes.Data.PlayerData)

local DataService              = require(script.Parent.Parent.Services.Foundation.DataService)
local PlotService              = require(script.Parent.Parent.Services.Core.PlotService)
local PlayerDataService        = require(script.Parent.Parent.Services.Core.PlayerDataService)
local MoneyService             = require(script.Parent.Parent.Services.Core.MoneyService)
local AdminService             = require(script.Parent.Parent.Services.Core.AdminService)
local AntiExploitService       = require(script.Parent.Parent.Services.Core.AntiExploitService)
local SpawnerService           = require(script.Parent.Parent.Services.Gameplay.SpawnerService)
local ConveyorService          = require(script.Parent.Parent.Services.Gameplay.ConveyorService)
local GeneratorService         = require(script.Parent.Parent.Services.Gameplay.GeneratorService)
local CollectionService        = require(script.Parent.Parent.Services.Gameplay.CollectionService)
local PlacementService         = require(script.Parent.Parent.Services.Gameplay.PlacementService)
local GeneratorPlacementService= require(script.Parent.Parent.Services.Gameplay.GeneratorPlacementService)
local ShopService              = require(script.Parent.Parent.Services.Economy.ShopService)
local PlayerLifecycleHandler   = require(script.Parent.Parent.Handlers.PlayerLifecycleHandler)
local RemoteFunctionHandler    = require(script.Parent.Parent.Handlers.RemoteFunctionHandler)
local AutoSaveHandler          = require(script.Parent.Parent.Handlers.AutoSaveHandler)

-- ============================================================
-- Wrapper d'initialisation sécurisé
-- ============================================================
local function safeInit(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		warn("❌ [" .. name .. "] Init échoué :", err)
	else
		print("✅ [" .. name .. "] OK")
	end
end

print("Démarrage de l'initialisation serveur...")

-- Foundation
safeInit("DataService",        function() DataService.Init() end)

-- Core
safeInit("PlotService",        function() PlotService.Init() end)
safeInit("PlayerDataService",  function() PlayerDataService.Init(DataService, PlayerData) end)
safeInit("MoneyService",       function() MoneyService.Init(PlayerDataService) end)
safeInit("AntiExploitService", function() AntiExploitService.Init() end)
safeInit("AdminService",       function() AdminService.Init(PlayerDataService, MoneyService) end)

-- Gameplay
safeInit("SpawnerService",           function() SpawnerService.Init(SpawnerConfig, ToyConfig, PlayerDataService) end)
safeInit("ConveyorService",          function() ConveyorService.Init() end)
safeInit("GeneratorService",         function() GeneratorService.Init(GeneratorConfig, MoneyService, ToyConfig) end)
safeInit("CollectionService",        function() CollectionService.Init(PlayerDataService, ToyConfig, GeneratorService) end)
safeInit("PlacementService",         function() PlacementService.Init(PlayerDataService, SpawnerService, SpawnerConfig) end)
safeInit("GeneratorPlacementService",function() GeneratorPlacementService.Init(PlayerDataService, GeneratorService) end)

-- Economy
safeInit("ShopService", function() ShopService.Init(SpawnerConfig, MoneyService, PlayerDataService) end)

-- Handlers
safeInit("PlayerLifecycleHandler", function() PlayerLifecycleHandler.Init(PlayerDataService, GeneratorService) end)
safeInit("RemoteFunctionHandler",  function() RemoteFunctionHandler.Init(ShopService, PlacementService, PlayerDataService) end)
safeInit("AutoSaveHandler",        function()
	AutoSaveHandler.Init(PlayerDataService, GameConfig)
	AutoSaveHandler.StartAutoSave()
end)

-- ============================================================
-- Enregistrement dans ServiceLocator
-- Effectué après tous les Init() pour que les services soient prêts
-- ============================================================
ServiceLocator.Register("Signal",                   Signal)
ServiceLocator.Register("DataService",              DataService)
ServiceLocator.Register("PlotService",              PlotService)
ServiceLocator.Register("PlayerDataService",        PlayerDataService)
ServiceLocator.Register("MoneyService",             MoneyService)
ServiceLocator.Register("AntiExploitService",       AntiExploitService)
ServiceLocator.Register("AdminService",             AdminService)
ServiceLocator.Register("SpawnerService",           SpawnerService)
ServiceLocator.Register("ConveyorService",          ConveyorService)
ServiceLocator.Register("GeneratorService",         GeneratorService)
ServiceLocator.Register("CollectionService",        CollectionService)
ServiceLocator.Register("PlacementService",         PlacementService)
ServiceLocator.Register("GeneratorPlacementService",GeneratorPlacementService)
ServiceLocator.Register("ShopService",              ShopService)

print("🎮 Serveur initialisé avec succès !")
