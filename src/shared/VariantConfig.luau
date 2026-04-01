--[[
	Configuration des variantes de brainrot
	Chaque brainrot peut exister en 6 variantes cosmétiques.

	Weights          : poids de tirage (somme = 100)
	RevenueMultiplier: multiplicateur de RevenuePerSecond appliqué à la variante
	Colors           : couleur d'affichage (labels, UI)
	Order            : ordre des variantes pour le roll cumulatif
]]

local VariantConfig = {

	-- Poids de tirage (total = 100)
	-- Galaxy, Lava et Rainbow désactivés pour l'instant (0%)
	Weights = {
		Normal  = 70,
		Gold    = 20,
		Diamond = 10,
		Galaxy  = 0,
		Lava    = 0,
		Rainbow = 0,
	},

	-- Multiplicateur de revenus par variante
	RevenueMultiplier = {
		Normal  = 1,
		Gold    = 2,
		Diamond = 5,
		Galaxy  = 10,
		Lava    = 20,
		Rainbow = 50,
	},

	-- Couleur d'affichage dans les labels / UI
	Colors = {
		Normal  = Color3.fromRGB(200, 200, 200),
		Gold    = Color3.fromRGB(255, 200, 0),
		Diamond = Color3.fromRGB(100, 220, 255),
		Galaxy  = Color3.fromRGB(180, 80,  255),
		Lava    = Color3.fromRGB(255, 80,  0),
		Rainbow = Color3.fromRGB(255, 100, 200),
	},

	-- Ordre utilisé pour le roll cumulatif
	Order = { "Normal", "Gold", "Diamond", "Galaxy", "Lava", "Rainbow" },
}

return VariantConfig
