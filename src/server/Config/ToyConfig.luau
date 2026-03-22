local ToyConfig = {
	TralaleroTralala = {
		Name = "Tralalero Tralala",
		Description = "The most basic toy",
		IconId = "rbxassetid://...",

		-- DOUBLE RARETÉ: [ToyRarity][SpawnerRarity]
		SellValue = {
			Common = {
				Common    = 5,
				Uncommon  = 7,
				Rare      = 10,
				Epic      = 20,
				Legendary = 40,
			},
			Uncommon = {
				Common    = 12,
				Uncommon  = 17,
				Rare      = 25,
				Epic      = 50,
				Legendary = 100,
			},
			Rare = {
				Common    = 25,
				Uncommon  = 35,
				Rare      = 50,
				Epic      = 100,
				Legendary = 200,
			},
			Epic = {
				Common    = 100,
				Uncommon  = 150,
				Rare      = 200,
				Epic      = 400,
				Legendary = 800,
			},
			Legendary = {
				Common    = 500,
				Uncommon  = 750,
				Rare      = 1000,
				Epic      = 2000,
				Legendary = 4000,
			},
		},

		QuotaToGenerator = {
			Common    = 100,
			Uncommon  = 75,
			Rare      = 50,
			Epic      = 20,
			Legendary = 10,
		},
		GeneratorType = "Tralalero_Tralala_Generator",
	},

	BrrBrrPatapim = {
		Name = "Brr Brr Patapim",
		Description = "Advanced toy",
		IconId = "rbxassetid://...",

		-- DOUBLE RARETÉ: [ToyRarity][SpawnerRarity]
		SellValue = {
			Common = {
				Common    = 10,
				Uncommon  = 15,
				Rare      = 20,
				Epic      = 40,
				Legendary = 80,
			},
			Uncommon = {
				Common    = 25,
				Uncommon  = 35,
				Rare      = 50,
				Epic      = 100,
				Legendary = 200,
			},
			Rare = {
				Common    = 50,
				Uncommon  = 75,
				Rare      = 100,
				Epic      = 200,
				Legendary = 400,
			},
			Epic = {
				Common    = 200,
				Uncommon  = 300,
				Rare      = 400,
				Epic      = 800,
				Legendary = 1600,
			},
			Legendary = {
				Common    = 1000,
				Uncommon  = 1500,
				Rare      = 2000,
				Epic      = 4000,
				Legendary = 8000,
			},
		},

		QuotaToGenerator = {
			Common    = 100,
			Uncommon  = 75,
			Rare      = 50,
			Epic      = 20,
			Legendary = 10,
		},
		GeneratorType = "Brr_Brr_Patapim_Generator",
	},
}
return ToyConfig
