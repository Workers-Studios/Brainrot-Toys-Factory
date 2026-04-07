--[[
    WeaponService - Gestion des armes, zone PvP, ragdoll et boutique

    Responsabilités :
      - Détection entrée/sortie zone PvP (via Heartbeat)
      - Validation des frappes côté serveur (zone, cooldown, distance)
      - Application du ragdoll + knockback à la victime
      - Achat et équipement d'armes (lié à playerData.weaponData)
      - Remise de l'outil au respawn
]]

local WeaponService = {}

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local WeaponConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponConfig"))

local _PlayerDataService = nil

-- ─── State ────────────────────────────────────────────────────────────────────

local pvpZone   = nil          -- BasePart "Zone" dans le folder PvPZone
local inPVPZone = {}           -- { [userId] = bool }
local cooldowns = {}           -- { [userId] = lastSwingTick }
local ragdolled = {}           -- { [userId] = bool }

-- ─── PvP Zone ─────────────────────────────────────────────────────────────────

local function initPVPZone()
    local folder = workspace:FindFirstChild(WeaponConfig.PVPFolder)
    if not folder then
        warn("[WeaponService] PvP folder not found:", WeaponConfig.PVPFolder)
        return
    end
    pvpZone = folder:FindFirstChild(WeaponConfig.PVPPartName)
    if not pvpZone then
        warn("[WeaponService] PvP zone part not found:", WeaponConfig.PVPPartName)
        return
    end
    pvpZone.CanCollide   = false
    pvpZone.Transparency = 1
    print("✅ [WeaponService] PvP zone loaded")
end

local function isInsideZone(position)
    if not pvpZone then return false end
    local local_pos = pvpZone.CFrame:PointToObjectSpace(position)
    local s = pvpZone.Size
    return math.abs(local_pos.X) <= s.X / 2
       and math.abs(local_pos.Y) <= s.Y / 2
       and math.abs(local_pos.Z) <= s.Z / 2
end

local function updateZoneMembership()
    for _, p in ipairs(Players:GetPlayers()) do
        local chr = p.Character
        if chr then
            local hrp = chr:FindFirstChild("HumanoidRootPart")
            if hrp then
                inPVPZone[p.UserId] = isInsideZone(hrp.Position)
            end
        end
    end
end

-- ─── Tool management ─────────────────────────────────────────────────────────

local function getToolTemplate()
    local bat = ServerStorage:FindFirstChild(WeaponConfig.ToolName)
    if not bat then
        warn("[WeaponService] Tool not found in ServerStorage:", WeaponConfig.ToolName)
    end
    return bat
end

local function removeWeaponFromPlayer(player)
    -- Backpack
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("IsWeapon") then
                item:Destroy()
            end
        end
    end
    -- Character (outil équipé)
    local chr = player.Character
    if chr then
        for _, item in ipairs(chr:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("IsWeapon") then
                item:Destroy()
            end
        end
    end
end

local function giveWeaponTool(player, rarity)
    removeWeaponFromPlayer(player)

    local template = getToolTemplate()
    if not template then return end

    local tool = template:Clone()
    tool.Name = WeaponConfig.ToolName .. "_" .. rarity
    tool:SetAttribute("IsWeapon",     true)
    tool:SetAttribute("WeaponRarity", rarity)

    -- Supprimer les scripts (gardez animation et son)
    for _, desc in ipairs(tool:GetDescendants()) do
        if desc:IsA("Script") or desc:IsA("LocalScript") then
            desc:Destroy()
        end
    end

    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        tool.Parent = backpack
    end
end

-- ─── Ragdoll + Knockback ──────────────────────────────────────────────────────

local function applyRagdoll(victim, attackerHRP, knockback, duration)
    local chr = victim.Character
    if not chr then return end
    local hrp = chr:FindFirstChild("HumanoidRootPart")
    local hum = chr:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    if ragdolled[victim.UserId] then return end

    ragdolled[victim.UserId] = true

    -- Désactiver les Motor6D → membres indépendants (ragdoll visuel)
    local motors = {}
    for _, desc in ipairs(chr:GetDescendants()) do
        if desc:IsA("Motor6D") then
            motors[#motors + 1] = desc
            desc.Enabled = false
        end
    end

    hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping,   false)

    -- Empêcher la mort durant le ragdoll (dégâts de chute éventuels)
    local healthConn
    healthConn = hum.HealthChanged:Connect(function(hp)
        if hp < hum.MaxHealth * 0.2 then
            hum.Health = hum.MaxHealth
        end
    end)

    -- Direction de knockback (horizontal + légère composante verticale)
    local dir2D = Vector3.new(
        hrp.Position.X - attackerHRP.Position.X,
        0,
        hrp.Position.Z - attackerHRP.Position.Z
    )
    if dir2D.Magnitude < 0.01 then dir2D = attackerHRP.CFrame.LookVector end
    local launchDir = (dir2D.Unit + Vector3.new(0, 0.45, 0)).Unit

    hrp.AssemblyLinearVelocity = launchDir * knockback

    -- Restauration après la durée
    task.delay(duration, function()
        healthConn:Disconnect()

        if not chr or not chr.Parent or not hum or not hum.Parent then
            ragdolled[victim.UserId] = nil
            return
        end

        for _, motor in ipairs(motors) do
            if motor and motor.Parent then
                motor.Enabled = true
            end
        end

        hum.Health = hum.MaxHealth
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping,   true)
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)

        ragdolled[victim.UserId] = nil
    end)
end

-- ─── Hit validation ───────────────────────────────────────────────────────────

function WeaponService.ProcessHit(attacker, victimUserId)
    if not _PlayerDataService then return false, "Service not ready" end

    local victim = Players:GetPlayerByUserId(victimUserId)
    if not victim          then return false, "Target not found" end
    if victim == attacker  then return false, "Cannot hit self"  end

    -- Zone PvP
    if not inPVPZone[attacker.UserId] then return false, "Attacker not in PvP zone" end
    if not inPVPZone[victim.UserId]   then return false, "Victim not in PvP zone"   end

    -- Cooldown
    local now  = tick()
    local last = cooldowns[attacker.UserId] or 0
    if now - last < WeaponConfig.Cooldown then return false, "Cooldown active" end

    -- Vérification distance (anti-cheat : +3 studs de tolérance réseau)
    local aChr = attacker.Character
    local vChr = victim.Character
    if not aChr or not vChr then return false, "Character missing" end

    local aHRP = aChr:FindFirstChild("HumanoidRootPart")
    local vHRP = vChr:FindFirstChild("HumanoidRootPart")
    if not aHRP or not vHRP then return false, "HRP missing" end

    if (aHRP.Position - vHRP.Position).Magnitude > WeaponConfig.HitDistance + 3 then
        return false, "Too far"
    end

    -- Arme équipée
    local pd = _PlayerDataService.GetPlayerData(attacker.UserId)
    if not pd then return false, "No player data" end

    local rarity = pd.weaponData and pd.weaponData.equipped
    if not rarity then return false, "No weapon equipped" end

    local rarityData = WeaponConfig.RarityData[rarity]
    if not rarityData then return false, "Invalid rarity" end

    -- Appliquer le cooldown
    cooldowns[attacker.UserId] = now

    -- Ragdoll + knockback
    applyRagdoll(victim, aHRP, rarityData.Knockback, rarityData.RagdollDuration)

    return true
end

-- ─── Weapon shop ─────────────────────────────────────────────────────────────

function WeaponService.GetShopData(userId)
    local pd = _PlayerDataService.GetPlayerData(userId)
    if not pd then return {}, nil end

    local wdata    = pd.weaponData or { owned = {}, equipped = nil }
    local ownedSet = {}
    for _, r in ipairs(wdata.owned) do ownedSet[r] = true end

    local result = {}
    for _, rarity in ipairs(WeaponConfig.Rarities) do
        local data = WeaponConfig.RarityData[rarity]
        result[#result + 1] = {
            Rarity    = rarity,
            Price     = data.BasePrice,
            Knockback = data.Knockback,
            Duration  = data.RagdollDuration,
            Owned     = ownedSet[rarity] == true,
            Equipped  = wdata.equipped == rarity,
        }
    end

    return result, wdata.equipped
end

function WeaponService.BuyWeapon(player, rarity)
    if not WeaponConfig.RarityData[rarity] then
        return false, "Invalid rarity"
    end

    local pd = _PlayerDataService.GetPlayerData(player.UserId)
    if not pd then return false, "Player data not found" end

    pd.weaponData = pd.weaponData or { owned = {}, equipped = nil }

    -- Déjà possédé ?
    for _, r in ipairs(pd.weaponData.owned) do
        if r == rarity then return false, "Already owned" end
    end

    local price = WeaponConfig.RarityData[rarity].BasePrice
    if pd:GetMoney() < price then
        return false, "Not enough money"
    end

    pd:RemoveMoney(price)
    table.insert(pd.weaponData.owned, rarity)
    pd.weaponData.equipped = rarity

    giveWeaponTool(player, rarity)

    return true, "Purchased!"
end

function WeaponService.EquipWeapon(player, rarity)
    local pd = _PlayerDataService.GetPlayerData(player.UserId)
    if not pd then return false, "Player data not found" end

    pd.weaponData = pd.weaponData or { owned = {}, equipped = nil }

    local owns = false
    for _, r in ipairs(pd.weaponData.owned) do
        if r == rarity then owns = true; break end
    end
    if not owns then return false, "Not owned" end

    pd.weaponData.equipped = rarity
    giveWeaponTool(player, rarity)

    return true
end

-- ─── Init ─────────────────────────────────────────────────────────────────────

function WeaponService.Init(PlayerDataService)
    _PlayerDataService = PlayerDataService

    initPVPZone()

    -- Mise à jour de la zone PvP chaque frame
    RunService.Heartbeat:Connect(updateZoneMembership)

    -- Nettoyage au départ du joueur
    Players.PlayerRemoving:Connect(function(p)
        inPVPZone[p.UserId] = nil
        cooldowns[p.UserId] = nil
        ragdolled[p.UserId] = nil
    end)

    -- Remettre l'arme au respawn
    Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function()
            task.wait(1)
            local pd = _PlayerDataService.GetPlayerData(p.UserId)
            if pd and pd.weaponData and pd.weaponData.equipped then
                giveWeaponTool(p, pd.weaponData.equipped)
            end
        end)
    end)
end

return WeaponService
