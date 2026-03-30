--[[
	Configuration du système de niveaux et d'EXP

	Le joueur monte de niveau (1 → 50) en gagnant de l'EXP via ses actions.
	Après le Maître Prestige, le cap de 50 est supprimé (niveaux illimités).

	Toutes les valeurs sont des PLACEHOLDERS : à équilibrer selon les tests.

	Formule d'EXP requise par niveau :
	  ExpRequired[level] = floor(100 * level^1.6)
	  → Niveau  1 → 2  : 100 EXP
	  → Niveau 10 → 11 : ~2512 EXP
	  → Niveau 49 → 50 : ~32 000 EXP  (approximatif)
]]

local LevelConfig = {}

-- Cap de niveau (identique à PrestigeConfig.MaxLevel — dupliqué ici pour éviter une dépendance circulaire)
LevelConfig.MaxLevel = 50

-- EXP total cumulé requis pour ATTEINDRE chaque niveau
-- Calculé dynamiquement pour éviter la duplication manuelle
-- Index = niveau cible (2 à 200, 200 couvre les niveaux illimités post-Maître Prestige)
LevelConfig.ExpRequired = (function()
	local t = { [1] = 0 }  -- Le niveau 1 ne coûte rien
	for level = 2, 200 do
		t[level] = math.floor(100 * (level ^ 1.6))
	end
	return t
end)()

-- ─── Récompenses d'EXP par action ──────────────────────────────────────────
-- Toutes les valeurs sont des PLACEHOLDERS
LevelConfig.ExpRewards = {

	-- Brainrot généré par un générateur (selon la rareté)
	BrainrotGenerated = {
		Common    = 5,
		Uncommon  = 15,
		Rare      = 35,
		Epic      = 75,
		Legendary = 150,
	},

	-- Brainrot vendu (selon la rareté)
	BrainrotSold = {
		Common    = 2,
		Uncommon  = 8,
		Rare      = 18,
		Epic      = 40,
		Legendary = 80,
	},

	-- Slot d'engrenage rempli
	GearSlotFilled = 25,

	-- Spawner posé sur un slot de plot
	SpawnerPlaced = 10,

	-- Quota complété (rareté quelconque)
	QuotaCompleted = 50,

	-- Achat d'un spawner dans la boutique (selon la rareté)
	SpawnerPurchased = {
		Common    = 3,
		Uncommon  = 8,
		Rare      = 20,
		Epic      = 50,
		Legendary = 100,
	},
}

return LevelConfig
