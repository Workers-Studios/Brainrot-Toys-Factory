--[[
	Spawner configuration and balancing
	Defines spawner stats and toy rarity drop rates per spawner tier

	Structure per spawner tier:
	- BasePrice: Purchase cost
	- SpawnRate: Seconds between toy spawns
	- RequiredRebirth: Minimum rebirth level to unlock
	- ToyType: Which toy type this spawner generates
	- DropRates: Probability distribution for toy rarities (must sum to 1.0)

	Note: Higher tier spawners spawn faster and have better drop rates
]]
local SpawnerConfig = {
	Common = {
		BasePrice = 100,
		SpawnRate = 5,
		RequiredRebirth = 0,
		ToyType = "TralaleroTralala",
		DropRates = {
			Common    = 0.80,
			Uncommon  = 0.12,
			Rare      = 0.05,
			Epic      = 0.02,
			Legendary = 0.01,
		}
	},
	Uncommon = {
		BasePrice = 250,
		SpawnRate = 4,
		RequiredRebirth = 0,
		ToyType = "TralaleroTralala",
		DropRates = {
			Common    = 0.70,
			Uncommon  = 0.18,
			Rare      = 0.08,
			Epic      = 0.03,
			Legendary = 0.01,
		}
	},
	Rare = {
		BasePrice = 500,
		SpawnRate = 3,
		RequiredRebirth = 0,
		ToyType = "TralaleroTralala",
		DropRates = {
			Common    = 0.55,
			Uncommon  = 0.22,
			Rare      = 0.14,
			Epic      = 0.07,
			Legendary = 0.02,
		}
	},
	Epic = {
		BasePrice = 2000,
		SpawnRate = 2,
		RequiredRebirth = 0,
		ToyType = "TralaleroTralala",
		DropRates = {
			Common    = 0.40,
			Uncommon  = 0.22,
			Rare      = 0.22,
			Epic      = 0.11,
			Legendary = 0.05,
		}
	},
	Legendary = {
		BasePrice = 10000,
		SpawnRate = 1,
		RequiredRebirth = 0,
		ToyType = "TralaleroTralala",
		DropRates = {
			Common    = 0.25,
			Uncommon  = 0.27,
			Rare      = 0.27,
			Epic      = 0.13,
			Legendary = 0.08,
		}
	}
}
return SpawnerConfig
