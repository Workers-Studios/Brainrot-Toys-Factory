--[[
	Configuration individuelle des brainrots (partagée client/serveur)
	Chaque entrée correspond exactement au nom du dossier dans BrainrotModels/{Rarity}/

	Si un brainrot est absent de ce fichier, il utilisera le RevenuePerSecond
	par défaut de sa rareté défini dans GeneratorConfig.

	Pour ajouter un brainrot : copier une ligne existante de la bonne rareté
	et ajuster le RevenuePerSecond.
]]

local BrainrotConfig = {

	Common = {
		["Lirili Larila"]        = { RevenuePerSecond = 8  },
		["Talpa Di Fero"]        = { RevenuePerSecond = 9  },
		["Tim Cheese"]           = { RevenuePerSecond = 10 },
		["Garamararam"]          = { RevenuePerSecond = 10 },
		["Pipi Kiwi"]            = { RevenuePerSecond = 11 },
		["Fluri Flura"]          = { RevenuePerSecond = 12 },
		["Madudung"]             = { RevenuePerSecond = 13 },
		["Tric Trac Barabum"]    = { RevenuePerSecond = 15 },
	},

	Uncommon = {
		["Boneca Ambalabu"]                = { RevenuePerSecond = 30 },
		["Chimpanzini Bananini"]           = { RevenuePerSecond = 32 },
		["Te Te Te Sahur"]                 = { RevenuePerSecond = 33 },
		["Brri Brri Bicus Dicus Bombicus"] = { RevenuePerSecond = 35 },
		["Trulimero Trulicina"]            = { RevenuePerSecond = 36 },
		["Svinina Bombardino"]             = { RevenuePerSecond = 38 },
		["Trippi Troppi"]                  = { RevenuePerSecond = 40 },
	},

	Rare = {
		["Bandito Bobrito"]       = { RevenuePerSecond = 100 },
		["Karkerkar Kurkur"]      = { RevenuePerSecond = 105 },
		["Cacto Hipopotamo"]      = { RevenuePerSecond = 110 },
		["Gangster Footera"]      = { RevenuePerSecond = 115 },
		["Orcalero Orcala"]       = { RevenuePerSecond = 120 },
		["Cappuccino Assassino"]  = { RevenuePerSecond = 125 },
		["Ta Ta Ta Ta Sahur"]     = { RevenuePerSecond = 130 },
		["Zibra Zubra Zibralini"] = { RevenuePerSecond = 140 },
	},

	Epic = {
		["Avocadini Guffo"]           = { RevenuePerSecond = 450 },
		["Bananita Dolphinita"]       = { RevenuePerSecond = 470 },
		["Ballerina Cappuccina"]      = { RevenuePerSecond = 480 },
		["Tigroligre Frutonni"]       = { RevenuePerSecond = 490 },
		["Bambini Crostini"]          = { RevenuePerSecond = 500 },
		["Brr Brr Patapim"]           = { RevenuePerSecond = 520 },
		["Torrtuginni Dragonfrutini"] = { RevenuePerSecond = 530 },
		["Dragon Cannelloni"]         = { RevenuePerSecond = 550 },
	},

	Legendary = {
		["Pipi Potato"]               = { RevenuePerSecond = 2100 },
		["Blueberrinni Octopusini"]   = { RevenuePerSecond = 2200 },
		["Esok Sekolah"]              = { RevenuePerSecond = 2300 },
		["Burbaloni Loliloli"]        = { RevenuePerSecond = 2400 },
		["Pandaccini Bananini"]       = { RevenuePerSecond = 2400 },
		["Espresso Signora"]          = { RevenuePerSecond = 2500 },
		["Chef Crabracadabra"]        = { RevenuePerSecond = 2600 },
		["Lionel Cactuseli"]          = { RevenuePerSecond = 2600 },
		["Frigo Camelo"]              = { RevenuePerSecond = 2700 },
		["Ganganzelli Trulala"]       = { RevenuePerSecond = 2800 },
		["Rhino Toasterino"]          = { RevenuePerSecond = 2800 },
		["Glorbo Fruttodirillo"]      = { RevenuePerSecond = 2900 },
		["La Grande Combinaison"]     = { RevenuePerSecond = 3000 },
		["Strawberrelli Flamingelli"] = { RevenuePerSecond = 3200 },
		["Tralaledon"]                = { RevenuePerSecond = 3500 },
	},
}

return BrainrotConfig
