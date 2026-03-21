--[[
	Server initialization and dependency injection orchestrator
	Loads all modules and initializes services in correct order
	
	Initialization order is critical:
	1. Foundation: Data persistence layer
	2. Core: Plot management, player data, and economy
	3. Gameplay: Spawners, conveyors, collection, generators
	4. Economy: Shop and transactions
	5. Handlers: Player lifecycle and remote communication
	
	All services use dependency injection (passed via Init functions)
]]

local Players = game:GetService("Players")

-- Import all configuration modules
local SpawnerConfig = require(script.Parent.Parent.Config.SpawnerConfig)
local ToyConfig = require(script.Parent.Parent.Config.ToyConfig)
local GeneratorConfig = require(script.Parent.Parent.Config.GeneratorConfig)
local GameConfig = require(script.Parent.Parent.Config.GameConfig)

-- Import classes
local PlayerData = require(script.Parent.Parent.Classes.Data.PlayerData)

-- Import foundation services
local DataService = require(script.Parent.Parent.Services.Foundation.DataService)

-- Import core services
local PlotService = require(script.Parent.Parent.Services.Core.PlotService)
local PlayerDataService = require(script.Parent.Parent.Services.Core.PlayerDataService)
local MoneyService = require(script.Parent.Parent.Services.Core.MoneyService)
local AdminService = require(script.Parent.Parent.Services.Core.AdminService)
local AntiExploitService = require(script.Parent.Parent.Services.Core.AntiExploitService)

-- Import gameplay services
local SpawnerService = require(script.Parent.Parent.Services.Gameplay.SpawnerService)
local ConveyorService = require(script.Parent.Parent.Services.Gameplay.ConveyorService)
local GeneratorService = require(script.Parent.Parent.Services.Gameplay.GeneratorService)
local CollectionService = require(script.Parent.Parent.Services.Gameplay.CollectionService)
local PlacementService = require(script.Parent.Parent.Services.Gameplay.PlacementService)
local GeneratorPlacementService = require(script.Parent.Parent.Services.Gameplay.GeneratorPlacementService)

-- Import economy services
local ShopService = require(script.Parent.Parent.Services.Economy.ShopService)

-- Import handlers
local PlayerLifecycleHandler = require(script.Parent.Parent.Handlers.PlayerLifecycleHandler)
local RemoteFunctionHandler = require(script.Parent.Parent.Handlers.RemoteFunctionHandler)
local AutoSaveHandler = require(script.Parent.Parent.Handlers.AutoSaveHandler)

-- Initialize all services in dependency order
print("Server initialization starting...")

-- Foundation layer: Data persistence
DataService.Init()

-- Core layer: Plot management (BEFORE player lifecycle)
PlotService.Init()

-- Core layer: Player data and economy
PlayerDataService.Init(DataService, PlayerData)
MoneyService.Init(PlayerDataService)
AntiExploitService.Init()

-- Core layer: Admin
AdminService.Init(PlayerDataService, MoneyService)

-- Gameplay layer: Core game mechanics
SpawnerService.Init(SpawnerConfig, ToyConfig, PlayerDataService)
ConveyorService.Init()
GeneratorService.Init(GeneratorConfig, MoneyService, ToyConfig)
CollectionService.Init(PlayerDataService, ToyConfig, GeneratorService)
PlacementService.Init(PlayerDataService, SpawnerService, SpawnerConfig)
GeneratorPlacementService.Init(PlayerDataService, GeneratorService)

-- Economy layer: Transactions
ShopService.Init(SpawnerConfig, MoneyService, PlayerDataService)

-- Handler layer: Player lifecycle and communication
PlayerLifecycleHandler.Init(PlayerDataService, GeneratorService)
RemoteFunctionHandler.Init(ShopService, PlacementService, PlayerDataService)

-- Auto-save handler
AutoSaveHandler.Init(PlayerDataService, GameConfig)
AutoSaveHandler.StartAutoSave()

print("Server initialized successfully!")
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
print("  - PlayerLifecycleHandler")
print("  - RemoteFunctionHandler")
print("  - AutoSaveHandler")