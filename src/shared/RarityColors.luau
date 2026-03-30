--[[
	Couleurs par rareté — source unique pour le client ET le serveur
	Évite la duplication de ces Color3 dans chaque contrôleur/service

	Usage : require(game:GetService("ReplicatedStorage").Shared.RarityColors)
	        local color = RarityColors.Common  → Color3
]]

local RarityColors = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(30,  200, 30),
	Rare      = Color3.fromRGB(0,   120, 255),
	Epic      = Color3.fromRGB(160, 0,   200),
	Legendary = Color3.fromRGB(255, 200, 0),
}

return RarityColors
