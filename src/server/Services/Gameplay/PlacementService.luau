--[[
	Manages spawner placement on physical slots and restoration
	Handles player interaction with spawner slots via ProximityPrompts
	
	Main responsibilities:
	- Initialize spawner slots from player's personal plot
	- Handle spawner placement from inventory onto slots (per-player)
	- Create visual representation of placed spawners
	- Start spawner toy generation loops
	- Restore placed spawners on player rejoin
	- Save spawner placements to DataStore
	
	Placement workflow: Player approaches slot → presses E → places spawner from inventory → spawner generates toys
]]

local PlacementService = {}

local PlotService = require(script.Parent.Parent.Core.PlotService)
local ServerStorage = game:GetService("ServerStorage")

local VALID_RARITIES = {Common = true, Uncommon = true, Rare = true, Epic = true, Legendary = true}

local _PlayerDataService = nil
local _SpawnerService = nil
local _SpawnerConfig = nil
local _OnNotification = game:GetService("ReplicatedStorage"):WaitForChild("RemoteInterface"):WaitForChild("Events"):WaitForChild("OnNotification")
local _slots = {}  -- [userId_slotName] = slotData

-- Initializes service (no longer searches for global slots)
-- @param PlayerDataService: service - Player data management service
-- @param SpawnerService: service - Spawner management service
-- @param SpawnerConfig: table - Spawner configuration data
function PlacementService.Init(PlayerDataService, SpawnerService, SpawnerConfig)
	_PlayerDataService = PlayerDataService
	_SpawnerService = SpawnerService
	_SpawnerConfig = SpawnerConfig

	print("PlacementService initialized")
end

-- Initializes spawner slots for a specific player's plot
-- @param userId: number - Player's user ID
function PlacementService.InitializePlotSlots(userId)
	local plot = PlotService.GetPlot(userId)
	if not plot then
		warn("Plot not found for userId:", userId)
		return
	end

	local slotsFolder = plot:FindFirstChild("SpawnerSlots")
	if not slotsFolder then
		warn("SpawnerSlots not found in plot for userId:", userId)
		return
	end

	-- Initialize each slot in the plot
	for _, slot in ipairs(slotsFolder:GetChildren()) do
		-- ⭐ CHANGEMENT: Accepter Parts ET Models
		local slotPart = nil
		local proximityPrompt = nil

		if slot:IsA("Model") and slot.PrimaryPart then
			-- Si c'est un Model
			slotPart = slot.PrimaryPart
			proximityPrompt = slotPart:FindFirstChildOfClass("ProximityPrompt")
		elseif slot:IsA("BasePart") then
			-- ⭐ Si c'est un Part simple (votre cas)
			slotPart = slot
			proximityPrompt = slot:FindFirstChildOfClass("ProximityPrompt")
		else
			continue
		end

		if not proximityPrompt then
			warn("⚠️ No ProximityPrompt found in", slot.Name)
			continue
		end

		-- Create unique slot key
		local slotKey = userId .. "_" .. slot.Name

		-- Store slot data
		_slots[slotKey] = {
			Model             = slot,
			Part              = slotPart,
			ProximityPrompt   = proximityPrompt,
			PlacementConnection = nil,
			PickupConnection    = nil,
			Occupied          = false,
			SpawnerPart       = nil,
			UserId            = userId
		}

		-- Connect prompt placement (stocké pour pouvoir déconnecter)
		_slots[slotKey].PlacementConnection = proximityPrompt.Triggered:Connect(function(player)
			if player.UserId == userId then
				PlacementService.OnSlotTriggered(player, slot)
			end
		end)
	end

	print("Initialized", #slotsFolder:GetChildren(), "spawner slots for plot", userId)
end

-- Retourne la rareté du tool spawner équipé (en main ou dans le backpack)
function PlacementService.GetEquippedSpawnerRarity(player)
	local function isSpawnerTool(tool)
		if not tool:IsA("Tool") then return false end
		if tool:GetAttribute("SpawnerRarity") then return true end
		return VALID_RARITIES[tool.Name] == true
	end
	local function getRarity(tool)
		return tool:GetAttribute("SpawnerRarity") or tool.Name
	end

	if player.Character then
		local tool = player.Character:FindFirstChildOfClass("Tool")
		if tool and isSpawnerTool(tool) then return getRarity(tool) end
	end
	for _, tool in ipairs(player.Backpack:GetChildren()) do
		if isSpawnerTool(tool) then return getRarity(tool) end
	end
	return nil
end

local SPAWNER_RARITY_COLORS = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(30,  180, 30),
	Rare      = Color3.fromRGB(0,   100, 255),
	Epic      = Color3.fromRGB(128, 0,   128),
	Legendary = Color3.fromRGB(255, 215, 0),
}

-- Donne un Tool spawner au backpack du joueur (template Studio ou création par code)
function PlacementService.GiveSpawnerTool(player, rarity)
	-- Essayer le template Studio en priorité
	local spawnerTools = ServerStorage:FindFirstChild("SpawnerTools")
	local toolTemplate = spawnerTools and spawnerTools:FindFirstChild(rarity)
	if toolTemplate then
		local tool = toolTemplate:Clone()
		tool.Name   = rarity
		tool.Parent = player.Backpack
		return
	end

	-- Fallback : créer le Tool entièrement par code
	local tool = Instance.new("Tool")
	tool.Name        = rarity
	tool.ToolTip     = rarity .. " Spawner"
	tool.RequiresHandle = true
	tool:SetAttribute("SpawnerRarity", rarity)

	local handle = Instance.new("Part")
	handle.Name     = "Handle"
	handle.Size     = Vector3.new(1, 1, 1)
	handle.Color    = SPAWNER_RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
	handle.Material = Enum.Material.SmoothPlastic
	handle.Parent   = tool

	tool.Parent = player.Backpack
end

-- Supprime le tool spawner de la main ou du backpack du joueur
function PlacementService.RemoveSpawnerTool(player, rarity)
	if player.Character then
		local tool = player.Character:FindFirstChild(rarity)
		if tool and tool:IsA("Tool") then
			tool:Destroy()
			return
		end
	end
	local tool = player.Backpack:FindFirstChild(rarity)
	if tool and tool:IsA("Tool") then
		tool:Destroy()
	end
end

-- Handles player interaction with spawner slot
function PlacementService.OnSlotTriggered(player, slotModel)
	local userId = player.UserId

	if not PlacementService.IsSlotFree(userId, slotModel.Name) then
		if _OnNotification then
			_OnNotification:FireClient(player, "Ce slot est déjà occupé !", "ERROR")
		end
		return
	end

	-- Lire la rareté depuis le tool équipé
	local rarity = PlacementService.GetEquippedSpawnerRarity(player)
	if not rarity then
		if _OnNotification then
			_OnNotification:FireClient(player, "Équipe un spawner d'abord !", "ERROR")
		end
		return
	end

	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData or not playerData:HasInInventory(rarity) then
		warn("Player doesn't have spawner", rarity)
		return
	end

	local success = PlacementService.PlaceSpawnerOnSlot(userId, rarity, slotModel.Name, player)
	if success then
		print("Spawner placed:", rarity, "on", slotModel.Name)
	end
end

-- Places a spawner on a slot and starts toy generation
-- @param userId: number - Player's user ID
-- @param rarity: string - Spawner rarity
-- @param slotName: string - Target slot name
-- @return boolean - true if placed successfully
function PlacementService.PlaceSpawnerOnSlot(userId, rarity, slotName, player)
	local slotKey = userId .. "_" .. slotName
	local playerData = _PlayerDataService.GetPlayerData(userId)

	if not playerData:HasInInventory(rarity) then
		warn("Player doesn't have spawner", rarity)
		return false
	end

	_slots[slotKey].Occupied = true

	local slotPart = _slots[slotKey].Part
	local spawnerPart = PlacementService.CreateSpawnerPart(rarity, slotPart)
	_slots[slotKey].SpawnerPart = spawnerPart
	-- Rendre tout le slot invisible (Part simple ou Model avec plusieurs Parts)
	local slotModel = _slots[slotKey].Model
	if slotModel:IsA("Model") then
		for _, part in ipairs(slotModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 1
			end
		end
	else
		slotModel.Transparency = 1
	end
	-- Déconnecter la connexion placement et passer en mode "Récupérer"
	if _slots[slotKey].PlacementConnection then
		_slots[slotKey].PlacementConnection:Disconnect()
		_slots[slotKey].PlacementConnection = nil
	end

	local pp = _slots[slotKey].ProximityPrompt
	pp.ActionText          = "Récupérer"
	pp.ObjectText          = rarity .. " Spawner"
	pp.HoldDuration        = 0
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Enabled             = true

	_slots[slotKey].PickupConnection = pp.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer.UserId ~= userId then return end
		PlacementService.PickupSpawner(userId, slotName, triggeringPlayer)
	end)

	playerData:RemoveFromInventory(rarity)

	-- Supprimer le tool de la main du joueur
	if player then
		PlacementService.RemoveSpawnerTool(player, rarity)
	end

	task.spawn(function()
		_SpawnerService.StartSpawner(userId, rarity, spawnerPart, slotName)
	end)

	table.insert(playerData.placedSpawners, {SlotName = slotName, Rarity = rarity})
	_PlayerDataService.SavePlayer(userId)

	return true
end

-- Récupère un spawner placé et le remet dans l'inventaire du joueur
function PlacementService.PickupSpawner(userId, slotName, player)
	local slotKey = userId .. "_" .. slotName
	local slotData = _slots[slotKey]
	if not slotData or not slotData.Occupied then return end

	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return end

	-- Trouver la rareté dans placedSpawners
	local rarity = nil
	for i, placed in ipairs(playerData.placedSpawners) do
		if placed.SlotName == slotName then
			rarity = placed.Rarity
			table.remove(playerData.placedSpawners, i)
			break
		end
	end
	if not rarity then return end

	-- Stopper le spawner
	_SpawnerService.StopSpawner(userId, slotName)

	-- Détruire le visuel du spawner
	local spawnerPart = slotData.SpawnerPart
	if spawnerPart then
		local spawnerModel = spawnerPart.Parent
		if spawnerModel and spawnerModel:IsA("Model") then
			spawnerModel:Destroy()
		else
			spawnerPart:Destroy()
		end
	end
	slotData.SpawnerPart = nil
	slotData.Occupied    = false

	-- Restaurer la visibilité du slot
	local slotModel = slotData.Model
	if slotModel:IsA("Model") then
		for _, part in ipairs(slotModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 0
			end
		end
	else
		slotModel.Transparency = 0
	end

	-- Déconnecter pickup et reconnecter placement
	if slotData.PickupConnection then
		slotData.PickupConnection:Disconnect()
		slotData.PickupConnection = nil
	end

	local pp = slotData.ProximityPrompt
	pp.ActionText   = "Placer"
	pp.ObjectText   = ""
	pp.HoldDuration = 0
	pp.Enabled      = true

	slotData.PlacementConnection = pp.Triggered:Connect(function(player)
		if player.UserId == userId then
			PlacementService.OnSlotTriggered(player, slotData.Model)
		end
	end)

	-- Remettre le spawner dans l'inventaire + redonner le tool
	playerData:AddToInventory(rarity)
	if player then
		PlacementService.GiveSpawnerTool(player, rarity)
	end

	_PlayerDataService.SavePlayer(userId)
end

-- Checks if a slot is available for placement
-- @param userId: number - Player's user ID
-- @param slotName: string - Slot name to check
-- @return boolean - true if slot is free
function PlacementService.IsSlotFree(userId, slotName)
	local slotKey = userId .. "_" .. slotName
	return _slots[slotKey] and not _slots[slotKey].Occupied
end

-- Creates visual spawner part with rarity-based coloring and rotation
-- @param rarity: string - Spawner rarity
-- @param slotPart: BasePart - The slot part (for position AND rotation)
-- @return Part - Created spawner part
function PlacementService.CreateSpawnerPart(rarity, slotPart)
	local targetCFrame = slotPart.CFrame

	-- Cloner le modèle visuel depuis le Tool dans ServerStorage
	local toolTemplate = ServerStorage:FindFirstChild("SpawnerTools") and
		ServerStorage.SpawnerTools:FindFirstChild(rarity)

	if toolTemplate then
		-- Chercher le Model visuel dans le Tool (tout sauf Handle)
		local visualModel = nil
		for _, child in ipairs(toolTemplate:GetChildren()) do
			if child:IsA("Model") then
				visualModel = child
				break
			end
		end

		if visualModel then
			local clone = visualModel:Clone()
			clone.Name = "Spawner_" .. rarity

			-- Ancrer toutes les parts
			for _, part in ipairs(clone:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = true
				end
			end

			clone.Parent = workspace

			-- Poser la base du modèle à la surface du slot
			local _, modelSize = clone:GetBoundingBox()
			local surfaceOffset = slotPart.Size.Y / 2 + modelSize.Y / 2
			clone:PivotTo(targetCFrame * CFrame.new(0, surfaceOffset, 0) * CFrame.Angles(0, math.rad(90), 0))
			-- Point de référence au centre du modèle (les toys spawns à la base)
			local boundingCF, boundingSize = clone:GetBoundingBox()
			local anchor = Instance.new("Part")
			anchor.Name = "SpawnAnchor"
			anchor.Size = Vector3.new(0.1, 0.1, 0.1)
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.Transparency = 1
			anchor.CFrame = CFrame.new(boundingCF.Position - Vector3.new(0, boundingSize.Y / 2, 0))
			anchor.Parent = clone
			return anchor
		end
	end

	-- Fallback : Part colorée si le modèle n'est pas trouvé
	warn("Modèle visuel introuvable pour rareté:", rarity, "— fallback Part colorée")
	local part = Instance.new("Part")
	part.Name = "Spawner_" .. rarity
	part.Size = Vector3.new(2, 2, 2)
	part.Anchored = true
	part.CanCollide = true
	part.CFrame = targetCFrame
	part.Parent = workspace
	return part
end

local EGG_COLORS = {
	Common    = Color3.fromRGB(135, 135, 135),
	Uncommon  = Color3.fromRGB(30,  180, 30),
	Rare      = Color3.fromRGB(0,   100, 255),
	Epic      = Color3.fromRGB(128, 0,   128),
	Legendary = Color3.fromRGB(255, 215, 0),
}

-- Nom du Tool oeuf (identifié par rareté uniquement)
local function eggToolName(rarity)
	return "Oeuf_" .. rarity
end

-- Donne un oeuf stacké dans le backpack (crée ou incrémente Count)
-- @param player  : Player - le joueur
-- @param rarity  : string - rareté de l'oeuf (Common, Rare, ...)
function PlacementService.GiveEggTool(player, rarity)
	local toolName = eggToolName(rarity)

	-- Stack si déjà présent
	local existing = player.Backpack:FindFirstChild(toolName)
		or (player.Character and player.Character:FindFirstChild(toolName))

	if existing and existing:IsA("Tool") then
		existing:SetAttribute("Count", (existing:GetAttribute("Count") or 1) + 1)
		return
	end

	-- Créer le Tool
	local tool = Instance.new("Tool")
	tool.Name          = toolName
	tool.RequiresHandle = true
	tool:SetAttribute("Rarity", rarity)
	tool:SetAttribute("Count",  1)

	local handle = Instance.new("Part")
	handle.Name         = "Handle"
	handle.Size         = Vector3.new(1, 1, 1)
	handle.Color        = EGG_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
	handle.CanCollide   = false
	handle.Massless     = true
	handle.Parent       = tool

	tool.Parent = player.Backpack
end

-- Retourne le Tool oeuf équipé ou le premier du backpack
-- @return tool, rarity
function PlacementService.GetEquippedEggInfo(player)
	local function check(t)
		if t:IsA("Tool") and t.Name:match("^Oeuf_") then
			return t, t:GetAttribute("Rarity")
		end
	end

	if player.Character then
		local t = player.Character:FindFirstChildOfClass("Tool")
		if t then
			local tool, r = check(t)
			if tool then return tool, r end
		end
	end

	for _, t in ipairs(player.Backpack:GetChildren()) do
		local tool, r = check(t)
		if tool then return tool, r end
	end

	return nil, nil
end

-- Retire un oeuf du backpack (décrémente Count ou détruit)
-- @param player : Player - le joueur
-- @param rarity : string - rareté de l'oeuf
function PlacementService.RemoveEggTool(player, rarity)
	local toolName = eggToolName(rarity)
	local tool = (player.Character and player.Character:FindFirstChild(toolName))
		or player.Backpack:FindFirstChild(toolName)

	if not tool or not tool:IsA("Tool") then return end

	local count = tool:GetAttribute("Count") or 1
	if count <= 1 then
		tool:Destroy()
	else
		tool:SetAttribute("Count", count - 1)
	end
end

local BRAINROT_COLORS = {
	Common    = Color3.fromRGB(135, 135, 135),
	Uncommon  = Color3.fromRGB(30, 180, 30),
	Rare      = Color3.fromRGB(0, 100, 255),
	Epic      = Color3.fromRGB(128, 0, 128),
	Legendary = Color3.fromRGB(255, 215, 0),
}

-- Donne un Tool brainrot au backpack du joueur
-- @param player: Player - Le joueur
-- @param generatorType: string - Type de générateur (ex: "Tralalero_Tralala_Generator")
-- @param rarity: string - Rareté du brainrot
function PlacementService.GiveBrainrotTool(player, generatorType, rarity)
	local tool = Instance.new("Tool")
	tool.Name = "Brainrot_" .. generatorType .. "_" .. rarity
	tool.RequiresHandle = true
	tool:SetAttribute("GeneratorType", generatorType)
	tool:SetAttribute("Rarity", rarity)

	-- Essaie de trouver un modèle visuel dans ServerStorage/BrainrotTools
	local brainrotTools = ServerStorage:FindFirstChild("BrainrotTools")
	local template = brainrotTools
		and brainrotTools:FindFirstChild(generatorType)
		and brainrotTools:FindFirstChild(generatorType):FindFirstChild(rarity)

	if template and template:IsA("BasePart") then
		local handle = template:Clone()
		handle.Name = "Handle"
		handle.Parent = tool
	else
		-- Fallback : Part colorée
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(1, 1, 1)
		handle.Color = BRAINROT_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
		handle.Parent = tool
	end

	tool.Parent = player.Backpack
	print("Brainrot tool given:", tool.Name)
end

-- Retourne le Tool brainrot équipé (en main ou premier du backpack)
-- @param player: Player - Le joueur
-- @return Tool|nil, string|nil, string|nil - tool, generatorType, rarity
function PlacementService.GetEquippedBrainrotInfo(player)
	local function checkTool(tool)
		if tool:IsA("Tool") and tool.Name:match("^Brainrot_") then
			local generatorType = tool:GetAttribute("GeneratorType")
			local rarity = tool:GetAttribute("Rarity")
			if generatorType and rarity then
				return tool, generatorType, rarity
			end
		end
	end

	if player.Character then
		local t = player.Character:FindFirstChildOfClass("Tool")
		if t then
			local tool, g, r = checkTool(t)
			if tool then return tool, g, r end
		end
	end

	for _, t in ipairs(player.Backpack:GetChildren()) do
		local tool, g, r = checkTool(t)
		if tool then return tool, g, r end
	end

	return nil, nil, nil
end

-- Supprime le Tool brainrot du joueur
-- @param player: Player - Le joueur
-- @param generatorType: string - Type de générateur
-- @param rarity: string - Rareté
function PlacementService.RemoveBrainrotTool(player, generatorType, rarity)
	local toolName = "Brainrot_" .. generatorType .. "_" .. rarity
	if player.Character then
		local tool = player.Character:FindFirstChild(toolName)
		if tool and tool:IsA("Tool") then tool:Destroy(); return end
	end
	local tool = player.Backpack:FindFirstChild(toolName)
	if tool then tool:Destroy() end
end

-- Gets first available spawner from player inventory
-- @param playerData: PlayerData - Player data instance
-- @return string|nil - Rarity of first available spawner or nil if none
function PlacementService.GetFirstAvailableSpawner(playerData)
	local rarityOrder = {"Common", "Uncommon", "Rare", "Epic", "Legendary"}

	for _, rarity in ipairs(rarityOrder) do
		if playerData.inventory[rarity] and playerData.inventory[rarity] > 0 then
			return rarity
		end
	end

	return nil
end

-- Restores placed spawners from previous session
-- @param userId: number - Player's user ID
function PlacementService.RestorePlacedSpawners(userId)
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then
		print("PlayerData not found for spawner restoration")
		return
	end

	-- Restore each saved spawner
	for _, placedData in ipairs(playerData.placedSpawners) do

		local slotName = placedData.SlotName
		local rarity = placedData.Rarity
		local slotKey = userId .. "_" .. slotName

		-- Find slot
		local slotData = _slots[slotKey]
		if not slotData then
			warn("Slot not found:", slotKey)
			continue
		end

		-- Mark as occupied
		slotData.Occupied = true

		-- ⭐ Recreate visual spawner AVEC ROTATION DU SLOT
		local slotPart = slotData.Part
		local spawnerPart = PlacementService.CreateSpawnerPart(rarity, slotPart)  -- ⭐ Passer le slot
		slotData.SpawnerPart = spawnerPart

		-- Rendre tout le slot invisible
		local slotModel = slotData.Model
		if slotModel:IsA("Model") then
			for _, part in ipairs(slotModel:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 1
				end
			end
		else
			slotModel.Transparency = 1
		end
		-- Déconnecter placement et passer en mode "Récupérer"
		if slotData.PlacementConnection then
			slotData.PlacementConnection:Disconnect()
			slotData.PlacementConnection = nil
		end

		local pp = slotData.ProximityPrompt
		pp.ActionText          = "Récupérer"
		pp.ObjectText          = rarity .. " Spawner"
		pp.HoldDuration        = 0
		pp.MaxActivationDistance = 10
		pp.RequiresLineOfSight = false
		pp.Enabled             = true

		local capturedSlotName = slotName
		slotData.PickupConnection = pp.Triggered:Connect(function(triggeringPlayer)
			if triggeringPlayer.UserId ~= userId then return end
			PlacementService.PickupSpawner(userId, capturedSlotName, triggeringPlayer)
		end)

		-- ⭐ Restart spawner avec spawnerPart
		task.spawn(function()
			_SpawnerService.StartSpawner(userId, rarity, spawnerPart, slotName)
		end)

	end
end

return PlacementService
