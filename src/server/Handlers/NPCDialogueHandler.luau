--[[
    NPCDialogueHandler - Gestion des interactions PNJ côté serveur

    - Attache un ProximityPrompt (touche E) à chaque PNJ
    - Ouvre le dialogue côté client via OpenNPCDialogue
    - Traite les actions de vente et renvoie NPCSellResult au client
    - Fournit l'inventaire de vente via la RemoteFunction NPCGetSellInventory
]]

local NPCDialogueHandler = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local _SellService = nil

local ev
local function getEv()
    if not ev then
        ev = ReplicatedStorage:WaitForChild("RemoteInterface"):WaitForChild("Events")
    end
    return ev
end

local fn
local function getFn()
    if not fn then
        fn = ReplicatedStorage:WaitForChild("RemoteInterface"):WaitForChild("Functions")
    end
    return fn
end

-- ─── Helpers ─────────────────────────────────────────────────────────────────

-- Retourne la Part racine d'un NPC (HumanoidRootPart, PrimaryPart, ou première BasePart)
local function getRootPart(npc)
    if npc:IsA("Model") then
        return npc:FindFirstChild("HumanoidRootPart")
            or (npc.PrimaryPart)
            or npc:FindFirstChildWhichIsA("BasePart")
    elseif npc:IsA("BasePart") then
        return npc
    end
    return nil
end

-- Attache ou récupère un ProximityPrompt sur un NPC
local function ensureProximityPrompt(root, objectText)
    local pp = root:FindFirstChildOfClass("ProximityPrompt")
    if pp then return pp end
    pp = Instance.new("ProximityPrompt")
    pp.ActionText           = "Parler"
    pp.ObjectText           = objectText
    pp.KeyboardKeyCode      = Enum.KeyCode.E
    pp.HoldDuration         = 0
    pp.MaxActivationDistance = 8
    pp.Parent               = root
    return pp
end

-- ─── NPC Setup ────────────────────────────────────────────────────────────────

-- Recherche récursive dans tout le workspace (gère les NPC dans des dossiers/modèles)
local function findInWorkspace(name)
    local found = workspace:FindFirstChild(name, true)
    if found then return found end
    -- Attendre jusqu'à 30s en re-cherchant chaque seconde
    for _ = 1, 30 do
        task.wait(1)
        found = workspace:FindFirstChild(name, true)
        if found then return found end
    end
    return nil
end

local function setupNPC(npcName, npcId, objectText)
    task.spawn(function()
        local npc = findInWorkspace(npcName)
        if not npc then
            warn("[NPCDialogueHandler] NPC introuvable après 30s :", npcName)
            return
        end

        local root = getRootPart(npc)
        if not root then
            warn("[NPCDialogueHandler] Pas de BasePart sur :", npcName)
            return
        end

        -- Supprimer tout ProximityPrompt existant pour éviter les doublons
        local existing = root:FindFirstChildOfClass("ProximityPrompt")
        if existing then existing:Destroy() end

        local pp = Instance.new("ProximityPrompt")
        pp.ActionText            = "Parler"
        pp.ObjectText            = objectText
        pp.KeyboardKeyCode       = Enum.KeyCode.E
        pp.HoldDuration          = 0
        pp.MaxActivationDistance = 8
        pp.Parent                = root

        pp.Triggered:Connect(function(player)
            getEv().OpenNPCDialogue:FireClient(player, npcId)
        end)

        print("✅ [NPCDialogueHandler]", npcName, "prêt")
    end)
end

-- ─── Init ─────────────────────────────────────────────────────────────────────

function NPCDialogueHandler.Init(SellService)
    _SellService = SellService

    -- Attacher les PNJ
    setupNPC("BrainrotPNJ", "BrainrotPNJ", "Marchand Brainrot")
    setupNPC("SpawnerPNJ",  "SpawnerPNJ",  "Marchand Spawner")

    local events    = getEv()
    local functions = getFn()

    -- ── Vendre un (item équipé en main) ──────────────────────────────────────
    events.NPCSellHeld.OnServerEvent:Connect(function(player, npcType)
        local ok, money, msg
        if npcType == "brainrot" then
            ok, money, msg = _SellService.SellHeldBrainrot(player)
        else
            ok, money, msg = _SellService.SellHeldSpawner(player)
        end
        events.NPCSellResult:FireClient(player, ok, money, msg)
    end)

    -- ── Vendre tout ───────────────────────────────────────────────────────────
    events.NPCSellAll.OnServerEvent:Connect(function(player, npcType)
        local ok, money, msg
        if npcType == "brainrot" then
            ok, money, msg = _SellService.SellAllBrainrots(player)
        else
            ok, money, msg = _SellService.SellAllSpawners(player)
        end
        events.NPCSellResult:FireClient(player, ok, money, msg)
    end)

    -- ── Vendre sélection ──────────────────────────────────────────────────────
    events.NPCSellItems.OnServerEvent:Connect(function(player, npcType, items)
        local ok, money, msg
        if npcType == "brainrot" then
            ok, money, msg = _SellService.SellSelectedBrainrots(player, items)
        else
            ok, money, msg = _SellService.SellSelectedSpawners(player, items)
        end
        events.NPCSellResult:FireClient(player, ok, money, msg)
    end)

    -- ── Inventaire de vente (RemoteFunction) ──────────────────────────────────
    functions.NPCGetSellInventory.OnServerInvoke = function(player, npcType)
        if npcType == "brainrot" then
            return _SellService.GetBrainrotSellInventory(player.UserId)
        else
            return _SellService.GetSpawnerSellInventory(player.UserId)
        end
    end

    print("✅ [NPCDialogueHandler] initialisé")
end

return NPCDialogueHandler
