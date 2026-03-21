--[[
	Global game configuration and balancing
	Contains economy settings, terrain expansion tiers, and rebirth system parameters
	
	Main sections:
	- Economy: Starting money
	- Terrain: Base plot size, socket counts, expansion tiers
	- Persistence: Auto-save interval
	- Rebirth: Costs and multipliers per level
]]

local GameConfig = {

	-- Starting money for new players (enough for 1 Common spawner)
	StartingMoney = 100,

	-- Base plot size in studs (50x50)
	BasePlotSize = 50,

	-- Initial number of spawner/generator sockets available
	BaseSocketCount = 5,

	-- Terrain expansion tiers
	-- Each tier requires money and rebirth level, unlocks more sockets and plot size
	Expansions = {
		{
			Level = 1,
			Cost = 10000,
			RequiredRebirth = 0,
			AddedSockets = 3,
			AddedPlotSize = 20,
		},
		{
			Level = 2,
			Cost = 50000,
			RequiredRebirth = 5,
			AddedSockets = 5,
			AddedPlotSize = 30,
		},
		{
			Level = 3,
			Cost = 250000,
			RequiredRebirth = 10,
			AddedSockets = 7,
			AddedPlotSize = 40,
		},
		{
			Level = 4,
			Cost = 1000000,
			RequiredRebirth = 15,
			AddedSockets = 10,
			AddedPlotSize = 50,
		},
	},

	-- Maximum expansion level achievable
	MaxExpansions = 4,

	-- Auto-save interval in seconds (300 = 5 minutes)
	AutoSaveInterval = 300,

	-- Money required for each rebirth level
	-- Formula after level 3: previous cost * 5
	RebirthCosts = {
		[1] = 100000,
		[2] = 500000,
		[3] = 2000000,
	},

	-- Permanent revenue multiplier per rebirth level (+20% per rebirth)
	RebirthMultiplier = 1.2,
}

return GameConfig