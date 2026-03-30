--[[
	Configuration du système de Prestige
	Inspiré du système de prestige Call of Duty Multijoueur :
	le joueur sacrifie sa progression (reset) en échange d'un rang
	permanent (Prestige) et d'une récompense cumulative.

	Règles :
	  - 10 Prestiges numérotés, chacun demande plus d'argent
	    et un brainrot d'une rareté plus élevée
	  - Chaque Prestige octroie un multiplicateur permanent et un badge visible
	  - Après le Prestige 10 + Niveau 50 → "Maître Prestige" débloqué
	  - Le Maître Prestige supprime le cap de niveau (illimité)

	Valeurs économiques (Money, multiplicateurs) : PLACEHOLDER
	À équilibrer selon les tests de gameplay.
]]

local PrestigeConfig = {

	-- Cap de niveau avant (ou sans) prestige
	MaxLevel    = 50,

	-- Nombre total de prestiges standard
	MaxPrestige = 10,

	-- Multiplicateur cumulatif gagné par prestige (placeholder : ce qu'il multiplie sera défini plus tard)
	MultiplierPerPrestige = 1.2,

	-- ─── Exigences par palier de prestige ─────────────────────────────────────
	-- Money                 : argent que le joueur doit posséder (sera consommé au reset)
	-- RequiredBrainrotRarity: rareté minimale du brainrot à posséder dans l'inventaire
	Requirements = {
		[1]  = { Money = 100000,      RequiredBrainrotRarity = "Common"    },
		[2]  = { Money = 500000,      RequiredBrainrotRarity = "Common"    },
		[3]  = { Money = 1000000,     RequiredBrainrotRarity = "Uncommon"  },
		[4]  = { Money = 2500000,     RequiredBrainrotRarity = "Uncommon"  },
		[5]  = { Money = 5000000,     RequiredBrainrotRarity = "Rare"      },
		[6]  = { Money = 10000000,    RequiredBrainrotRarity = "Rare"      },
		[7]  = { Money = 25000000,    RequiredBrainrotRarity = "Epic"      },
		[8]  = { Money = 50000000,    RequiredBrainrotRarity = "Epic"      },
		[9]  = { Money = 100000000,   RequiredBrainrotRarity = "Legendary" },
		[10] = { Money = 500000000,   RequiredBrainrotRarity = "Legendary" },
	},

	-- ─── Maître Prestige ──────────────────────────────────────────────────────
	-- Accessible UNIQUEMENT après avoir atteint le Prestige 10 ET le Niveau 50
	-- Après ce prestige spécial, le cap de niveau est supprimé (niveaux illimités)
	MasterPrestige = {
		Money                  = 1000000000,
		RequiredBrainrotRarity = "Legendary",
	},

	-- ─── Couleurs des badges par palier ───────────────────────────────────────
	-- Index 1-10 = Prestige 1-10 │ Index 11 = Maître Prestige
	BadgeColors = {
		[1]  = Color3.fromRGB(180, 180, 180),  -- Argent
		[2]  = Color3.fromRGB(100, 220, 100),  -- Vert clair
		[3]  = Color3.fromRGB(30,  200, 30 ),  -- Vert
		[4]  = Color3.fromRGB(0,   160, 255),  -- Bleu
		[5]  = Color3.fromRGB(0,   80,  200),  -- Bleu foncé
		[6]  = Color3.fromRGB(160, 0,   200),  -- Violet
		[7]  = Color3.fromRGB(255, 200, 0  ),  -- Or
		[8]  = Color3.fromRGB(255, 140, 0  ),  -- Orange
		[9]  = Color3.fromRGB(255, 50,  50 ),  -- Rouge
		[10] = Color3.fromRGB(255, 0,   100),  -- Cramoisi
		[11] = Color3.fromRGB(255, 255, 255),  -- Blanc Diamant (Maître Prestige)
	},

	-- ─── Noms d'affichage par palier ──────────────────────────────────────────
	BadgeNames = {
		[0]  = "",                  -- Pas encore de prestige
		[1]  = "Prestige I",
		[2]  = "Prestige II",
		[3]  = "Prestige III",
		[4]  = "Prestige IV",
		[5]  = "Prestige V",
		[6]  = "Prestige VI",
		[7]  = "Prestige VII",
		[8]  = "Prestige VIII",
		[9]  = "Prestige IX",
		[10] = "Prestige X",
		[11] = "✦ Maître Prestige",  -- Maître Prestige
	},
}

return PrestigeConfig
