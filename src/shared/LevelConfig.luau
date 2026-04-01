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

	-- EXP gagné à la découverte d'un brainrot (pose de l'oeuf sur le socle)
	-- Calculé : BrainrotDiscovered.Tiers[rarity] * BrainrotDiscovered.VariantMultiplier[variant]
	BrainrotDiscovered = {

		-- EXP de base par tier (variante Normal)
		Tiers = {
			Common      =    50,
			Uncommon    =   150,
			Rare        =   400,
			Epic        = 1_000,
			Legendary   = 2_500,
			Mythic      = 6_000,
			BrainrotGod = 15_000,
			Secret      = 10_000,
			OG          = 20_000,
		},

		-- Multiplicateur selon la variante
		VariantMultiplier = {
			Normal  = 1,
			Gold    = 2,
			Diamond = 5,
		},
	},

	-- Poser un spawner sur un slot
	SpawnerPlaced = 10,
}

return LevelConfig
