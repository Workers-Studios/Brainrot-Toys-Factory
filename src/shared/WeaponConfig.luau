--[[
    WeaponConfig - Configuration du système d'armes (batte de baseball)

    Rarités : Common → Legendary
    Knockback    : vélocité appliquée au HRP lors du ragdoll (studs/s)
    RagdollDuration : durée du ragdoll en secondes
    BasePrice    : coût d'achat chez le PNJ
]]

local WeaponConfig = {}

WeaponConfig.Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

WeaponConfig.RarityOrder = {
    Common    = 1,
    Uncommon  = 2,
    Rare      = 3,
    Epic      = 4,
    Legendary = 5,
}

WeaponConfig.RarityData = {
    Common    = { Knockback = 45,  RagdollDuration = 1.5, BasePrice = 500   },
    Uncommon  = { Knockback = 72,  RagdollDuration = 2.0, BasePrice = 2000  },
    Rare      = { Knockback = 105, RagdollDuration = 2.5, BasePrice = 7500  },
    Epic      = { Knockback = 145, RagdollDuration = 3.0, BasePrice = 25000 },
    Legendary = { Knockback = 195, RagdollDuration = 3.5, BasePrice = 75000 },
}

WeaponConfig.Cooldown     = 0.5   -- secondes entre deux frappes
WeaponConfig.HitDistance  = 6     -- studs max pour toucher un joueur
WeaponConfig.ToolName     = "BaseballBat"

WeaponConfig.PVPFolder    = "PvPZone"
WeaponConfig.PVPPartName  = "Zone"

return WeaponConfig
