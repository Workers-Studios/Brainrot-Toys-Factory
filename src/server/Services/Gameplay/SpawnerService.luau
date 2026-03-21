--[[
	Manages spawner toy generation and rarity distribution
	Handles continuous toy spawning loops with weighted RNG
	
	Main responsibilities:
	- Start/stop spawner generation loops per player
	- Determine toy rarity based on spawner tier drop rates
	- Create toy objects with visual properties
	- Register toy ownership for collection tracking
	- Initialize toys on conveyor system
	
	Spawn workflow: Spawner loop → determine rarity → create toy → place on conveyor → track ownership
]]

local SpawnerService = {}

local _SpawnerConfig = nil
local _ToyConfig = nil
local _PlayerDataService = nil
local _activeSpawners = {}  -- Tracks active spawner loops: {userId_rarity = true}

-- Initializes service with required dependencies
-- @param SpawnerConfig: table - Spawner configuration data
-- @param ToyConfig: table - Toy configuration data
-- @param PlayerDataService: service - Player data management service
function SpawnerService.Init(SpawnerConfig, ToyConfig, PlayerDataService)
	_SpawnerConfig = SpawnerConfig
	_ToyConfig = ToyConfig
	_PlayerDataService = PlayerDataService
end

-- Starts continuous toy generation loop for a spawner
-- @param userId: number - Player's user ID
-- @param rarity: string - Spawner rarity tier
-- @param spawnerPart: BasePart - The spawner part
function SpawnerService.StartSpawner(userId, rarity, spawnerPart)
	-- Validate spawner config exists
	if not _SpawnerConfig[rarity] then
		warn("SpawnerConfig not initialized for", rarity)
		return
	end

	-- Mark spawner as active
	local spawnerId = userId .. "_" .. rarity
	_activeSpawners[spawnerId] = true

	-- Continuous spawn loop
	task.spawn(function()
		while _activeSpawners[spawnerId] do
			task.wait(_SpawnerConfig[rarity].SpawnRate)

			-- Check if spawner still active (player might have left)
			if not _activeSpawners[spawnerId] then
				break
			end

			-- Spawn toy (rarity determined inside SpawnToy)
			SpawnerService.SpawnToy(userId, rarity, spawnerPart)
		end
	end)
end

-- Stops spawner generation loop
-- @param userId: number - Player's user ID
-- @param rarity: string - Spawner rarity tier
function SpawnerService.StopSpawner(userId, rarity)
	_activeSpawners[userId .. "_" .. rarity] = nil
end

-- Spawns a toy from a spawner with rarity-based drop rates and double rarity system
-- @param userId: number - Player's user ID
-- @param spawnerRarity: string - Rarity of the spawner ("Common", "Rare", etc.)
-- @param spawnerPart: BasePart - The spawner part (for position and rotation)
function SpawnerService.SpawnToy(userId, spawnerRarity, spawnerPart)
	-- Validate parameters
	if not userId or not spawnerRarity or not spawnerPart then
		warn("Invalid parameters for SpawnToy")
		return
	end

	-- Get spawner configuration
	local spawnerConfig = _SpawnerConfig[spawnerRarity]
	if not spawnerConfig then
		warn("Spawner config not found for rarity:", spawnerRarity)
		return
	end

	-- Get toy TYPE from spawner config
	local toyType = spawnerConfig.ToyType
	if not toyType then
		warn("ToyType not defined for spawner:", spawnerRarity)
		return
	end

	-- Verify toy TYPE exists in ToyConfig
	local toyConfig = _ToyConfig[toyType]
	if not toyConfig then
		warn("Toy type not found in ToyConfig:", toyType)
		return
	end

	-- ROLL for toy RARITY based on drop rates
	local roll = math.random()
	local cumulativeProbability = 0
	local toyRarity = nil

	for rarity, dropRate in pairs(spawnerConfig.DropRates) do
		cumulativeProbability += dropRate
		if roll <= cumulativeProbability then
			toyRarity = rarity
			break
		end
	end

	if not toyRarity then
		warn("Failed to determine toy rarity for spawner:", spawnerRarity)
		return
	end

	-- ⭐ Create toy with TYPE and RARITY
	local toy = Instance.new("Part")
	toy.Name = toyType .. "_" .. toyRarity .. "_" .. userId
	toy.Size = Vector3.new(1, 1, 1)
	toy.Anchored = false
	toy.CanCollide = true

	-- ⭐ POSITION CORRECTE: Au-dessus ET vers l'avant du spawner
	local spawnOffset = spawnerPart.CFrame.Position 
		+ Vector3.new(0, 5, 0)  -- 5 studs au-dessus
		+ (spawnerPart.CFrame.LookVector * -7)  -- 5 studs vers l'avant

	toy.Position = spawnOffset

	-- ⭐ Store toy metadata (DOUBLE RARETÉ)
	toy:SetAttribute("ToyType", toyType)
	toy:SetAttribute("ToyRarity", toyRarity)
	toy:SetAttribute("SpawnerRarity", spawnerRarity)
	toy:SetAttribute("OwnerId", userId)

	-- Color by TOY rarity
	if toyRarity == "Common" then
		toy.Color = Color3.fromRGB(135, 135, 135)
	elseif toyRarity == "Rare" then
		toy.Color = Color3.fromRGB(0, 0, 255)
	elseif toyRarity == "Epic" then
		toy.Color = Color3.fromRGB(128, 0, 128)
	elseif toyRarity == "Legendary" then
		toy.Color = Color3.fromRGB(255, 215, 0)
	end

	-- ⭐ Parent to workspace (toy will fall and trigger ConveyorService.Touched)
	toy.Parent = workspace

	print("✅ Toy spawned:", toy.Name, "at", toy.Position, "LookVector:", spawnerPart.CFrame.LookVector)
end

return SpawnerService