--[[
	Manages passive income generators and their revenue loops
	Handles generator creation, income generation, and lifecycle management
	
	Main responsibilities:
	- Create generators with appropriate income rates based on rarity
	- Run asynchronous income loops that generate money over time
	- Track active generators per player
	- Stop all generators on player disconnect
	
	Income rates are defined in GeneratorConfig per rarity tier
]]

local GeneratorService = {}

local _GeneratorConfig  = nil
local _MoneyService     = nil
local _ToyConfig        = nil
local _activeGenerators = {}  -- [generatorId] = true
local _serverStartTime  = tick()  -- horloge globale partagée

-- Initializes service with required dependencies
-- @param GeneratorConfig: table - Generator configuration data
-- @param MoneyService: service - Money transaction service
-- @param ToyConfig: table - Toy configuration data (for generator type mapping)
function GeneratorService.Init(GeneratorConfig, MoneyService, ToyConfig)
	_GeneratorConfig = GeneratorConfig
	_MoneyService = MoneyService
	_ToyConfig = ToyConfig
end

-- Creates a generator and starts its income loop
-- @param userId: number - Player's user ID
-- @param toyType: string - Type of toy (used to determine generator type)
-- @param rarity: string - Rarity tier (determines income rate)
function GeneratorService.CreateGenerator(userId, toyType, rarity)
	-- Get generator type from toy configuration
	local generatorType = _ToyConfig[toyType].GeneratorType
	if not generatorType then
		warn("No generator defined for", toyType)
		return
	end

	-- Validate generator configuration exists
	local generatorConfig = _GeneratorConfig[generatorType]
	if not generatorConfig then
		warn("Generator config not found for", generatorType)
		return
	end

	-- Get income rate for this rarity
	local incomeRate = generatorConfig.BaseRevenuePerSecond[rarity]
	local incomeInterval = 1  -- Generate income every 1 second

	-- Start income generation loop (key = userId_generatorType for StopAllGenerators compatibility)
	GeneratorService.StartGeneratorLoop(userId, userId .. "_" .. generatorType, incomeRate, incomeInterval)

	print("Generator created:", generatorType, "for", userId)
end

-- Starts asynchronous income generation loop
-- @param userId: number - Player's user ID
-- @param generatorType: string - Type of generator
-- @param incomeRate: number - Money generated per interval
-- @param incomeInterval: number - Seconds between income generation
function GeneratorService.StartGeneratorLoop(userId, generatorId, incomeRate, incomeInterval)
	_activeGenerators[generatorId] = true

	task.spawn(function()
		while _activeGenerators[generatorId] do
			-- Synchronisation globale : tous les générateurs tirent au même tick
			local elapsed  = tick() - _serverStartTime
			local nextTick = (math.floor(elapsed / incomeInterval) + 1) * incomeInterval
			task.wait(nextTick - elapsed)

			if not _activeGenerators[generatorId] then break end
			_MoneyService.AddMoney(userId, incomeRate)
		end
	end)
end

-- Stoppe un générateur spécifique par son ID
function GeneratorService.StopGenerator(generatorId)
	_activeGenerators[generatorId] = nil
end

-- Stops all generators for a player (called on disconnect)
-- @param userId: number - Player's user ID
function GeneratorService.StopAllGenerators(userId)
	for key, _ in pairs(_activeGenerators) do
		if key:match("^" .. userId .. "_") then
			_activeGenerators[key] = nil
		end
	end
end

return GeneratorService