--[[
	Spawner configuration and balancing
	Defines spawner stats and toy rarity drop rates per spawner tier
	
	Structure per spawner tier:
	- BasePrice: Purchase cost (0 = free for MVP)
	- SpawnRate: Seconds between toy spawns
	- RequiredRebirth: Minimum rebirth level to unlock
	- ToyType: Which toy type this spawner generates
	- DropRates: Probability distribution for toy rarities (must sum to 1.0)
	
	Note: Higher tier spawners spawn faster and have better drop rates
]]
local SpawnerConfig = {
	Common = {
		BasePrice = 100,
		SpawnRate = 5,  -- Spawns a toy every 5 seconds
		RequiredRebirth = 0,
		ToyType = "TralaleroTralala",
		-- Toy rarity drop rates (heavily weighted toward Common, must sum to 1.0)
		DropRates = {
			Common = 0.85,     -- 85%
			Rare = 0.10,       -- 10%
			Epic = 0.04,       -- 4%
			Legendary = 0.01,  -- 1%
		}
	},
	Rare = {
		BasePrice = 500,
		SpawnRate = 3,  -- Faster spawn rate
		RequiredRebirth = 0,
		ToyType = "TralaleroTralala",
		-- Better drop rates than Common
		DropRates = {
			Common = 0.70,
			Rare = 0.20,
			Epic = 0.08,
			Legendary = 0.02,
		}
	},
	Epic = {
		BasePrice = 2000,
		SpawnRate = 2,
		RequiredRebirth = 0,
		ToyType = "TralaleroTralala",
		-- Even better drop rates
		DropRates = {
			Common = 0.55,
			Rare = 0.25,
			Epic = 0.15,
			Legendary = 0.05,
		}
	},
	Legendary = {
		BasePrice = 10000,
		SpawnRate = 1,  -- Fastest spawn rate
		RequiredRebirth = 0,
		ToyType = "TralaleroTralala",
		-- Best drop rates
		DropRates = {
			Common = 0.40,
			Rare = 0.30,
			Epic = 0.20,
			Legendary = 0.10,
		}
	}
}
return SpawnerConfig