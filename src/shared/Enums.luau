--[[
	Enums partagés client/serveur
	Centralise toutes les valeurs discrètes du jeu pour éviter les magic strings

	Usage (serveur) : require(game:GetService("ReplicatedStorage").Shared.Enums)
	Usage (client)  : require(game:GetService("ReplicatedStorage").Shared.Enums)
]]

local Enums = {}

-- Raretés disponibles dans le jeu
Enums.Rarity = {
	Common    = "Common",
	Uncommon  = "Uncommon",
	Rare      = "Rare",
	Epic      = "Epic",
	Legendary = "Legendary",
}

-- Ordre croissant des raretés (utile pour itérations et affichage)
Enums.RarityList = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
}

-- Lookup rapide : Enums.RaritySet["Common"] == true
Enums.RaritySet = {}
for _, r in ipairs(Enums.RarityList) do
	Enums.RaritySet[r] = true
end

return Enums
