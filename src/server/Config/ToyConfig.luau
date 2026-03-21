local ToyConfig = {
	TralaleroTralala = {
		Name = "Tralalero Tralala",
		Description = "The most basic toy",
		IconId = "rbxassetid://...",

		-- ⭐ DOUBLE RARETÉ: [ToyRarity][SpawnerRarity]
		SellValue = {
			-- Toy Common
			Common = {
				Common = 5,        -- Toy Common from Spawner Common
				Rare = 10,         -- Toy Common from Spawner Rare
				Epic = 20,         -- Toy Common from Spawner Epic
				Legendary = 40,    -- Toy Common from Spawner Legendary
			},
			-- Toy Rare
			Rare = {
				Common = 25,       -- Toy Rare from Spawner Common
				Rare = 50,         -- Toy Rare from Spawner Rare
				Epic = 100,        -- Toy Rare from Spawner Epic
				Legendary = 200,   -- Toy Rare from Spawner Legendary
			},
			-- Toy Epic
			Epic = {
				Common = 100,
				Rare = 200,
				Epic = 400,
				Legendary = 800,
			},
			-- Toy Legendary
			Legendary = {
				Common = 500,
				Rare = 1000,
				Epic = 2000,
				Legendary = 4000,
			},
		},

		QuotaToGenerator = {
			Common = 100,
			Rare = 50,
			Epic = 20,
			Legendary = 10,
		},
		GeneratorType = "Tralalero_Tralala_Generator",
	},

	BrrBrrPatapim = {
		Name = "Brr Brr Patapim",
		Description = "Advanced toy",
		IconId = "rbxassetid://...",

		-- ⭐ DOUBLE RARETÉ
		SellValue = {
			Common = {
				Common = 10,
				Rare = 20,
				Epic = 40,
				Legendary = 80,
			},
			Rare = {
				Common = 50,
				Rare = 100,
				Epic = 200,
				Legendary = 400,
			},
			Epic = {
				Common = 200,
				Rare = 400,
				Epic = 800,
				Legendary = 1600,
			},
			Legendary = {
				Common = 1000,
				Rare = 2000,
				Epic = 4000,
				Legendary = 8000,
			},
		},

		QuotaToGenerator = {
			Common = 100,
			Rare = 50,
			Epic = 20,
			Legendary = 10,
		},
		GeneratorType = "Brr_Brr_Patapim_Generator",
	},
}
return ToyConfig