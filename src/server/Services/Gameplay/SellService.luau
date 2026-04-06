--[[
    SellService - Gestion de la vente d'items aux PNJ

    Prix de vente :
      Brainrot : math.floor(RevenuePerSecond × 60)   (= 1 minute de revenu)
      Spawner  : math.floor(BasePrice × 0.5)          (= 50 % du prix d'achat)

    API publique :
      SellHeldBrainrot(player)                     → success, price, message
      SellHeldSpawner(player)                      → success, price, message
      SellAllBrainrots(player)                     → success, total, message
      SellAllSpawners(player)                      → success, total, message
      SellSelectedBrainrots(player, names)         → success, total, message
      SellSelectedSpawners(player, rarityList)     → success, total, message
      GetBrainrotSellInventory(userId)             → { {name,rarity,price}, ... }
      GetSpawnerSellInventory(userId)              → { {rarity,count,priceEach}, ... }
]]

local SellService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BRAINROT_MULTIPLIER = 60   -- RPS × 60
local SPAWNER_RATIO       = 0.5  -- 50 % du BasePrice

local _PlayerDataService = nil
local _PlacementService  = nil
local _SpawnerConfig     = nil
local _onMoneyChanged    = nil

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function calcBrainrotPrice(brainrot)
    return math.max(1, math.floor((brainrot.RevenuePerSecond or 0) * BRAINROT_MULTIPLIER))
end

local function calcSpawnerPrice(rarity)
    local cfg = _SpawnerConfig and _SpawnerConfig[rarity]
    if not cfg then return 0 end
    return math.floor(cfg.BasePrice * SPAWNER_RATIO)
end

-- Crédite l'argent directement sur playerData et notifie le client
local function grantMoney(player, amount)
    if amount <= 0 then return end
    local pd = _PlayerDataService.GetPlayerData(player.UserId)
    if not pd then return end
    pd:AddMoney(amount)
    if _onMoneyChanged then
        _onMoneyChanged:FireClient(player, pd.money)
    end
    _PlayerDataService.SavePlayer(player.UserId)
end

-- ─── Sell Held ────────────────────────────────────────────────────────────────

function SellService.SellHeldBrainrot(player)
    local character = player.Character
    if not character then return false, 0, "Personnage introuvable." end

    -- Cherche l'outil équipé avec l'attribut BrainrotName
    local tool, brainrotName
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") then
            local attr = item:GetAttribute("BrainrotName")
            if attr then tool = item; brainrotName = attr; break end
        end
    end

    if not tool then return false, 0, "Aucun brainrot équipé en main." end

    local pd = _PlayerDataService.GetPlayerData(player.UserId)
    if not pd then return false, 0, "Données introuvables." end

    -- Récupère les données du brainrot dans l'inventaire
    local brainrotData
    for _, b in ipairs(pd.brainrotInventory) do
        if b.Name == brainrotName then brainrotData = b; break end
    end
    if not brainrotData then return false, 0, "Brainrot introuvable en inventaire." end

    local price = calcBrainrotPrice(brainrotData)
    pd:RemoveBrainrot(brainrotName)
    _PlacementService.RemoveBrainrotTool(player, brainrotName)
    grantMoney(player, price)

    return true, price, string.format("Brainrot vendu pour $%d !", price)
end

function SellService.SellHeldSpawner(player)
    local character = player.Character
    if not character then return false, 0, "Personnage introuvable." end

    local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
    local tool, rarity

    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") then
            -- Attribut SpawnerRarity en priorité
            local attr = item:GetAttribute("SpawnerRarity")
            if attr then tool = item; rarity = attr; break end
            -- Fallback : nom correspondant à une rareté connue
            for _, r in ipairs(RARITIES) do
                if item.Name == r or item.Name == "spawner_" .. r:lower() then
                    tool = item; rarity = r; break
                end
            end
            if tool then break end
        end
    end

    if not tool then return false, 0, "Aucun spawner équipé en main." end

    local pd = _PlayerDataService.GetPlayerData(player.UserId)
    if not pd then return false, 0, "Données introuvables." end
    if not pd:HasInInventory(rarity) then return false, 0, "Spawner introuvable en inventaire." end

    local price = calcSpawnerPrice(rarity)
    pd:RemoveFromInventory(rarity)
    _PlacementService.RemoveSpawnerTool(player, rarity)
    grantMoney(player, price)

    return true, price, string.format("Spawner %s vendu pour $%d !", rarity, price)
end

-- ─── Sell All ─────────────────────────────────────────────────────────────────

function SellService.SellAllBrainrots(player)
    local pd = _PlayerDataService.GetPlayerData(player.UserId)
    if not pd then return false, 0, "Données introuvables." end
    if #pd.brainrotInventory == 0 then return false, 0, "Inventaire brainrot vide." end

    local total = 0
    local names = {}
    for _, b in ipairs(pd.brainrotInventory) do
        total = total + calcBrainrotPrice(b)
        table.insert(names, b.Name)
    end

    pd.brainrotInventory = {}
    for _, n in ipairs(names) do
        _PlacementService.RemoveBrainrotTool(player, n)
    end
    grantMoney(player, total)

    return true, total, string.format("%d brainrot(s) vendus pour $%d !", #names, total)
end

function SellService.SellAllSpawners(player)
    local pd = _PlayerDataService.GetPlayerData(player.UserId)
    if not pd then return false, 0, "Données introuvables." end

    local total, count = 0, 0
    for rarity, qty in pairs(pd.inventory) do
        if qty and qty > 0 then
            total = total + calcSpawnerPrice(rarity) * qty
            count = count + qty
            for _ = 1, qty do
                _PlacementService.RemoveSpawnerTool(player, rarity)
            end
            pd.inventory[rarity] = 0
        end
    end

    if count == 0 then return false, 0, "Inventaire spawner vide." end
    grantMoney(player, total)

    return true, total, string.format("%d spawner(s) vendus pour $%d !", count, total)
end

-- ─── Sell Selected ────────────────────────────────────────────────────────────

-- names : { "BrainrotA", "BrainrotB", ... }  (peut contenir des doublons)
function SellService.SellSelectedBrainrots(player, names)
    local pd = _PlayerDataService.GetPlayerData(player.UserId)
    if not pd then return false, 0, "Données introuvables." end
    if not names or #names == 0 then return false, 0, "Aucun item sélectionné." end

    -- Construire un comptage des noms à vendre
    local toSell = {}
    for _, n in ipairs(names) do toSell[n] = (toSell[n] or 0) + 1 end

    local total, sold = 0, 0
    -- Calculer le prix sur les brainrots qui matchent
    local remaining = {}
    for k, v in pairs(toSell) do remaining[k] = v end

    for _, b in ipairs(pd.brainrotInventory) do
        if remaining[b.Name] and remaining[b.Name] > 0 then
            total = total + calcBrainrotPrice(b)
            remaining[b.Name] = remaining[b.Name] - 1
            sold = sold + 1
        end
    end

    if sold == 0 then return false, 0, "Aucun item valide trouvé." end

    -- Supprimer les brainrots vendus
    for _, n in ipairs(names) do
        pd:RemoveBrainrot(n)
        _PlacementService.RemoveBrainrotTool(player, n)
    end
    grantMoney(player, total)

    return true, total, string.format("%d brainrot(s) vendus pour $%d !", sold, total)
end

-- rarityList : { {rarity="Common", count=2}, ... }
function SellService.SellSelectedSpawners(player, rarityList)
    local pd = _PlayerDataService.GetPlayerData(player.UserId)
    if not pd then return false, 0, "Données introuvables." end
    if not rarityList or #rarityList == 0 then return false, 0, "Aucun item sélectionné." end

    local total, count = 0, 0
    for _, item in ipairs(rarityList) do
        local rarity = item.rarity
        local want   = item.count or 1
        local have   = pd.inventory[rarity] or 0
        local sell   = math.min(want, have)
        if sell > 0 then
            total = total + calcSpawnerPrice(rarity) * sell
            count = count + sell
            for _ = 1, sell do
                pd:RemoveFromInventory(rarity)
                _PlacementService.RemoveSpawnerTool(player, rarity)
            end
        end
    end

    if count == 0 then return false, 0, "Aucun item valide trouvé." end
    grantMoney(player, total)

    return true, total, string.format("%d spawner(s) vendus pour $%d !", count, total)
end

-- ─── Inventory Queries ────────────────────────────────────────────────────────

-- Retourne la liste des brainrots avec leurs prix de vente (pour l'UI)
function SellService.GetBrainrotSellInventory(userId)
    local pd = _PlayerDataService.GetPlayerData(userId)
    if not pd then return {} end
    local result = {}
    for _, b in ipairs(pd.brainrotInventory) do
        table.insert(result, {
            Name             = b.Name,
            Rarity           = b.Rarity,
            RevenuePerSecond = b.RevenuePerSecond,
            Price            = calcBrainrotPrice(b),
        })
    end
    return result
end

-- Retourne la liste des spawners avec leurs prix de vente (pour l'UI)
function SellService.GetSpawnerSellInventory(userId)
    local pd = _PlayerDataService.GetPlayerData(userId)
    if not pd then return {} end
    local result = {}
    local ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
    for _, rarity in ipairs(ORDER) do
        local qty = pd.inventory[rarity] or 0
        if qty > 0 then
            table.insert(result, {
                Rarity    = rarity,
                Count     = qty,
                PriceEach = calcSpawnerPrice(rarity),
            })
        end
    end
    return result
end

-- ─── Init ─────────────────────────────────────────────────────────────────────

function SellService.Init(PlayerDataService, PlacementService, SpawnerConfig)
    _PlayerDataService = PlayerDataService
    _PlacementService  = PlacementService
    _SpawnerConfig     = SpawnerConfig
    _onMoneyChanged    = ReplicatedStorage
        :WaitForChild("RemoteInterface")
        :WaitForChild("Events")
        :WaitForChild("OnMoneyChanged")
    print("✅ [SellService] initialisé")
end

return SellService
