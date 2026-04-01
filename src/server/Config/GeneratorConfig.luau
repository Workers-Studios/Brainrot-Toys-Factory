--[[
	Configuration des générateurs (brainrots) par rareté d'oeuf

	Le pool de brainrots est construit DYNAMIQUEMENT en scannant
	ServerStorage/BrainrotModels/{Rarity}/ au démarrage du serveur.
	Il suffit d'ajouter/supprimer des dossiers dans Studio, sans toucher ce fichier.

	Seul le revenu de base par rareté est défini ici.
	Tous les brainrots d'une même rareté ont le même revenu de base.
]]

local GeneratorConfig = {

	Common    = { RevenuePerSecond = 10  },
	Uncommon  = { RevenuePerSecond = 35  },
	Rare      = { RevenuePerSecond = 120 },
	Epic      = { RevenuePerSecond = 500 },
	Legendary = { RevenuePerSecond = 2500 },
}

return GeneratorConfig
