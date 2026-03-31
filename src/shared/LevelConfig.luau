--[[
	Configuration du système de niveaux et d'EXP

	Système d'EXP relatif : playerData.exp représente l'EXP dans le niveau actuel
	(repart à 0 à chaque level up, le surplus est conservé).

	Niveaux 1-50  : floor(500 * level^1.5) arrondi à la centaine
	Niveaux 51+   : floor(50000 * (level-49)^1.4) — illimité après Maître Prestige
]]

local LevelConfig = {}

LevelConfig.MaxLevel = 50

-- Seuil d'EXP requis pour passer AU niveau suivant depuis ce niveau
-- Niveaux 1-50 pré-calculés (arrondi centaine), 51+ calculés à la volée
local _table = {}
for lvl = 1, 50 do
	_table[lvl] = math.round(500 * lvl ^ 1.5 / 100) * 100
end

function LevelConfig.GetExpRequired(level)
	if level <= 50 then
		return _table[level]
	else
		return math.floor(50000 * (level - 49) ^ 1.4)
	end
end

-- ─── Récompenses d'EXP par action ───────────────────────────────────────────
LevelConfig.ExpRewards = {

	BrainrotGenerated = {
		Common    = 5,
		Uncommon  = 15,
		Rare      = 35,
		Epic      = 75,
		Legendary = 150,
	},

	BrainrotSold = {
		Common    = 2,
		Uncommon  = 8,
		Rare      = 18,
		Epic      = 40,
		Legendary = 80,
	},

	GearSlotFilled = 25,
	SpawnerPlaced  = 10,
	QuotaCompleted = 50,

	SpawnerPurchased = {
		Common    = 3,
		Uncommon  = 8,
		Rare      = 20,
		Epic      = 50,
		Legendary = 100,
	},
}

return LevelConfig
