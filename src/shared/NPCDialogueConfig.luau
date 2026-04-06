--[[
    NPCDialogueConfig - Configuration statique des dialogues PNJ

    Structure par PNJ :
      NPCType : "brainrot" | "spawner"
      Name    : nom affiché dans l'UI
      Intro   : texte d'introduction
      Options : liste de { Label, Action }
        Actions : "SellHeld" | "SellAll" | "OpenSellUI" | "Close"
]]

return {
    BrainrotPNJ = {
        NPCType = "brainrot",
        Name    = "Marchand de Brainrots",
        Intro   = "Bonjour ! Je rachète vos brainrots au meilleur prix.\nQue puis-je faire pour vous ?",
        Options = {
            { Label = "Vendre un brainrot",  Action = "SellHeld"   },
            { Label = "Vendre tout",         Action = "SellAll"    },
            { Label = "Choisir quoi vendre", Action = "OpenSellUI" },
            { Label = "Au revoir",           Action = "Close"      },
        },
    },

    SpawnerPNJ = {
        NPCType = "spawner",
        Name    = "Marchand de Spawners",
        Intro   = "Bonjour ! Je rachète vos spawners.\nQue puis-je faire pour vous ?",
        Options = {
            { Label = "Vendre un spawner",   Action = "SellHeld"   },
            { Label = "Vendre tout",         Action = "SellAll"    },
            { Label = "Choisir quoi vendre", Action = "OpenSellUI" },
            { Label = "Au revoir",           Action = "Close"      },
        },
    },
}
