--[[
    WeaponHandler - ProximityPrompts des WeaponPNJ + RemoteEvents armes

    Attache un ProximityPrompt à tout enfant du folder NPCVendors dont le nom
    commence par "WeaponPNJ". Le prompt ouvre l'UI de boutique d'armes côté client.
]]

local WeaponHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponConfig"))

local _WeaponService = nil

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function getEvents()
    return ReplicatedStorage.RemoteInterface.Events
end
local function getFunctions()
    return ReplicatedStorage.RemoteInterface.Functions
end

local function getRootPart(model)
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChildWhichIsA("BasePart")
end

-- ─── NPC Setup ────────────────────────────────────────────────────────────────

local function setupNPC(npc)
    local root = getRootPart(npc)
    if not root then
        warn("[WeaponHandler] No BasePart on:", npc.Name)
        return
    end

    local existing = root:FindFirstChildOfClass("ProximityPrompt")
    if existing then existing:Destroy() end

    local pp = Instance.new("ProximityPrompt")
    pp.ActionText            = "Parler"
    pp.ObjectText            = "Vendeur d'Armes"
    pp.KeyboardKeyCode       = Enum.KeyCode.E
    pp.HoldDuration          = 0
    pp.MaxActivationDistance = 8
    pp.RequiresLineOfSight   = false
    pp.Parent                = root

    pp.Triggered:Connect(function(player)
        getEvents().OpenNPCDialogue:FireClient(player, "WeaponPNJ")
    end)

    print("✅ [WeaponHandler]", npc.Name, "ready")
end

local function setupAllNPCs()
    local folder = workspace:FindFirstChild("NPCVendors")
    if not folder then
        warn("[WeaponHandler] NPCVendors folder not found")
        return
    end
    for _, child in ipairs(folder:GetChildren()) do
        if child.Name:sub(1, #"WeaponPNJ") == "WeaponPNJ" then
            setupNPC(child)
        end
    end
end

-- ─── Init ─────────────────────────────────────────────────────────────────────

function WeaponHandler.Init(WeaponService)
    _WeaponService = WeaponService

    setupAllNPCs()

    -- RemoteFunction : données de la boutique
    getFunctions().WeaponGetShopData.OnServerInvoke = function(player)
        return _WeaponService.GetShopData(player.UserId)
    end

    -- RemoteEvent : acheter une arme
    getEvents().WeaponBuy.OnServerEvent:Connect(function(player, rarity)
        local success, msg = _WeaponService.BuyWeapon(player, rarity)
        getEvents().WeaponBuyResult:FireClient(player, success, msg)
    end)

    -- RemoteEvent : équiper une arme possédée
    getEvents().WeaponEquip.OnServerEvent:Connect(function(player, rarity)
        _WeaponService.EquipWeapon(player, rarity)
    end)

    -- RemoteEvent : frappe (client envoie l'UserId de la cible)
    getEvents().WeaponSwing.OnServerEvent:Connect(function(player, victimUserId)
        _WeaponService.ProcessHit(player, victimUserId)
    end)
end

return WeaponHandler
