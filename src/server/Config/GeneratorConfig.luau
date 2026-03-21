--[[
	Generator configuration and balancing
	Defines passive income rates per generator type and rarity
	
	Structure per generator:
	- Name: Display name
	- Description: UI description
	- BaseRevenuePerSecond: Income rates by rarity ($/second)
	- PlacementCost: Cost to place (0 = free)
	- ModelName: Reference to 3D model in ServerStorage/Templates/
	
	Note: Generators are obtained by completing toy collection quotas
]]

local GeneratorConfig = {

	Tralalero_Tralala_Generator = {
		Name = "Tralalero Tralala Generator",
		Description = "Generates money passively",

		-- Base income per second by rarity (before rebirth multipliers)
		BaseRevenuePerSecond = {
			Common = 10,
			Rare = 50,
			Epic = 200,
			Legendary = 1000,
		},

		-- Cost to place generator (0 = free)
		PlacementCost = 0,

		-- 3D model reference (create in ServerStorage/Templates/)
		ModelName = "TralaleroTralalaGenerator",
	},

	BrrBrrPatapim = {
		Name = "Brr Brr Patapim Generator",
		Description = "Generates money passively",

		BaseRevenuePerSecond = {
			Common = 10,
			Rare = 50,
			Epic = 200,
			Legendary = 1000,
		},

		PlacementCost = 0,
		ModelName = "BrrBrrPatapimGenerator",
	},
}

return GeneratorConfig