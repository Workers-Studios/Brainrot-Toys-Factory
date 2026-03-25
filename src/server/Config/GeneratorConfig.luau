--[[
	Configuration des générateurs (brainrots) par rareté d'oeuf

	Quand un oeuf est posé sur un socle, on pioche aléatoirement un brainrot
	dans la Pool de la rareté de l'oeuf, pondéré par Weight.

	Structure par rareté :
	  Pool = liste de brainrots disponibles
	    Name             : nom affiché
	    ModelName        : nom du modèle dans ServerStorage/GeneratorModels/{Rarity}/
	    Weight           : poids de tirage (relatif aux autres dans la pool)
	    RevenuePerSecond : argent généré par seconde

	Note : ModelName peut être nil → fallback Part colorée
]]

local GeneratorConfig = {

	Common = {
		Pool = {
			{ Name = "Agarrini La Pallini", ModelName = "Agarrini La Pallini", Weight = 60, RevenuePerSecond = 10 },
			{ Name = "Avocadini Guffo",     ModelName = "Avocadini Guffo",     Weight = 40, RevenuePerSecond = 16 },
		},
	},

	Uncommon = {
		Pool = {
			{ Name = "Ballerina Cappuccina", ModelName = "Ballerina Cappuccina", Weight = 55, RevenuePerSecond = 35 },
			{ Name = "Ballerino Lololo",     ModelName = "Ballerino Lololo",     Weight = 45, RevenuePerSecond = 50 },
		},
	},

	Rare = {
		Pool = {
			{ Name = "Bambini Crostini", ModelName = "Bambini Crostini", Weight = 55, RevenuePerSecond = 120 },
			{ Name = "Banana Dancana",   ModelName = "Banana Dancana",   Weight = 45, RevenuePerSecond = 180 },
		},
	},

	Epic = {
		Pool = {
			{ Name = "Brainrot Epic 1", ModelName = nil, Weight = 70, RevenuePerSecond = 500 },
			{ Name = "Brainrot Epic 2", ModelName = nil, Weight = 30, RevenuePerSecond = 800 },
		},
	},

	Legendary = {
		Pool = {
			{ Name = "Brainrot Legendaire 1", ModelName = nil, Weight = 80, RevenuePerSecond = 2500 },
			{ Name = "Brainrot Legendaire 2", ModelName = nil, Weight = 20, RevenuePerSecond = 5000 },
		},
	},
}

return GeneratorConfig
