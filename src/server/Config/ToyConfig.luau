--[[
	Configuration des quotas de toys par rareté
	Les toys n'ont pas de "type" nommé — identifiés uniquement par leur rareté
	Les modèles 3D sont dans ServerStorage/ToyModels/{Rarity}/

	QuotaToGenerator : nombre de toys de cette rareté à collecter
	                   pour recevoir un oeuf de cette rareté
]]

local ToyConfig = {

	Common = {
		QuotaToGenerator = 20,    -- ~30s/oeuf  × 20 = ~10 min
	},

	Uncommon = {
		QuotaToGenerator = 15,    -- ~45s/oeuf  × 15 = ~11 min
	},

	Rare = {
		QuotaToGenerator = 10,    -- ~60s/oeuf  × 10 = ~10 min
	},

	Epic = {
		QuotaToGenerator = 7,     -- ~90s/oeuf  ×  7 = ~10 min
	},

	Legendary = {
		QuotaToGenerator = 5,     -- ~120s/oeuf ×  5 = ~10 min
	},
}

return ToyConfig
