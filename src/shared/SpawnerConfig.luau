--[[
	Configuration des spawners par rareté
	Chaque spawner a ses propres taux de drop pour les toys

	Structure par rareté :
	- BasePrice       : coût d'achat
	- SpawnRate       : secondes entre chaque spawn
	- RequiredPrestige: niveau de prestige minimum requis pour acheter
	- DropRates       : probabilité de chaque rareté de toy (doit totaliser 1.0)
]]

local SpawnerConfig = {

	Common = {
		BasePrice       = 100,
		SpawnRate       = 5,
		RequiredPrestige = 0,
		DropRates = {
			Common    = 0.85,
			Uncommon  = 0.15,
			Rare      = 0.00,
			Epic      = 0.00,
			Legendary = 0.00,
		},
	},

	Uncommon = {
		BasePrice       = 5000,
		SpawnRate       = 4,
		RequiredPrestige = 0,
		DropRates = {
			Common    = 0.70,
			Uncommon  = 0.18,
			Rare      = 0.08,
			Epic      = 0.00,
			Legendary = 0.00,
		},
	},

	Rare = {
		BasePrice       = 25000,
		SpawnRate       = 3,
		RequiredPrestige = 0,
		DropRates = {
			Common    = 0.55,
			Uncommon  = 0.22,
			Rare      = 0.14,
			Epic      = 0.07,
			Legendary = 0.00,
		},
	},

	Epic = {
		BasePrice       = 100000,
		SpawnRate       = 2,
		RequiredPrestige = 0,
		DropRates = {
			Common    = 0.40,
			Uncommon  = 0.22,
			Rare      = 0.22,
			Epic      = 0.11,
			Legendary = 0.05,
		},
	},

	Legendary = {
		BasePrice       = 750000,
		SpawnRate       = 1,
		RequiredPrestige = 0,
		DropRates = {
			Common    = 0.25,
			Uncommon  = 0.27,
			Rare      = 0.27,
			Epic      = 0.13,
			Legendary = 0.08,
		},
	},
}

return SpawnerConfig
