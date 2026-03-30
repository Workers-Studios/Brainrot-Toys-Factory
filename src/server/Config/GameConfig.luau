--[[
	Global game configuration and balancing
	Contains economy settings, terrain expansion tiers, and auto-save interval.

	Le système Rebirth a été remplacé par le système Prestige.
	La configuration du Prestige se trouve dans src/shared/PrestigeConfig.luau

	Main sections:
	- Economy  : Starting money
	- Terrain  : Base plot size, socket counts, expansion tiers
	- Persistence: Auto-save interval
]]

local GameConfig = {

	-- Starting money for new players (enough for 1 Common spawner)
	StartingMoney = 100,

	-- Base plot size in studs (50x50)
	BasePlotSize = 50,

	-- Initial number of spawner/generator sockets available
	BaseSocketCount = 5,

	-- Terrain expansion tiers
	-- Each tier requires money and a prestige level, unlocks more sockets and plot size
	Expansions = {
		{
			Level            = 1,
			Cost             = 10000,
			RequiredPrestige = 0,
			AddedSockets     = 3,
			AddedPlotSize    = 20,
		},
		{
			Level            = 2,
			Cost             = 50000,
			RequiredPrestige = 2,
			AddedSockets     = 5,
			AddedPlotSize    = 30,
		},
		{
			Level            = 3,
			Cost             = 250000,
			RequiredPrestige = 5,
			AddedSockets     = 7,
			AddedPlotSize    = 40,
		},
		{
			Level            = 4,
			Cost             = 1000000,
			RequiredPrestige = 8,
			AddedSockets     = 10,
			AddedPlotSize    = 50,
		},
	},

	-- Maximum expansion level achievable
	MaxExpansions = 4,

	-- Auto-save interval in seconds (300 = 5 minutes)
	AutoSaveInterval = 300,
}

return GameConfig
