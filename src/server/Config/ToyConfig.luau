--[[
	Configuration des quotas de toys par rareté
	Les toys n'ont pas de "type" nommé — identifiés uniquement par leur rareté
	Les modèles 3D sont dans ServerStorage/ToyModels/{Rarity}/

	QuotaToGenerator : nombre de toys de cette rareté à collecter
	                   pour recevoir un oeuf de cette rareté
]]

local ToyConfig = {

	Common = {
		QuotaToGenerator = 10,
	},

	Uncommon = {
		QuotaToGenerator = 8,
	},

	Rare = {
		QuotaToGenerator = 5,
	},

	Epic = {
		QuotaToGenerator = 3,
	},

	Legendary = {
		QuotaToGenerator = 1,
	},
}

return ToyConfig
