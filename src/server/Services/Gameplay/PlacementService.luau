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

		-- Connect prompt (ownership check)
		proximityPrompt.Triggered:Connect(function(player)
			if player.UserId == userId then
				PlacementService.OnSlotTriggered(player, slot)
			end
		end)

		-- Create unique slot key
		local slotKey = userId .. "_" .. slot.Name

		-- Store slot data
		_slots[slotKey] = {
			Model = slot,
			Part = slotPart,
			ProximityPrompt = proximityPrompt,
			Occupied = false,
			SpawnerPart = nil,
			UserId = userId
		}
	end

	print("Initialized", #slotsFolder:GetChildren(), "spawner slots for plot", userId)
end

-- Handles player interaction with spawner slot
-- @param player: Player - Player who triggered the slot
-- @param slotModel: Model - Slot model triggered
function PlacementService.OnSlotTriggered(player, slotModel)
	local userId = player.UserId
	local slotKey = userId .. "_" .. slotModel.Name  -- ⭐ Clé unique

	-- Validate slot is available
	if not PlacementService.IsSlotFree(userId, slotModel.Name) then
		warn("Slot already occupied")
		return
	end

	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then
		warn("PlayerData not found for", userId)
		return
	end

	-- Get first available spawner from inventory
	local rarity = PlacementService.GetFirstAvailableSpawner(playerData)

	if not rarity then
		warn("No spawner available in inventory")
		if _OnNotification then
			_OnNotification:FireClient(game.Players:GetPlayerByUserId(userId), "No spawner available", "ERROR")
		end
		return
	end

	-- Attempt placement
	local success = PlacementService.PlaceSpawnerOnSlot(userId, rarity, slotModel.Name)

	if success then
		print("Spawner placed successfully:", rarity, "on", slotModel.Name)
	else
		warn("Spawner placement failed")
	end
end

-- Places a spawner on a slot and starts toy generation
-- @param userId: number - Player's user ID
-- @param rarity: string - Spawner rarity
-- @param slotName: string - Target slot name
-- @return boolean - true if placed successfully
function PlacementService.PlaceSpawnerOnSlot(userId, rarity, slotName)
	local slotKey = userId .. "_" .. slotName
	local playerData = _PlayerDataService.GetPlayerData(userId)

	-- Validate player has spawner in inventory
	if not playerData:HasInInventory(rarity) then
		warn("Player doesn't have spawner", rarity)
		return false
	end

	-- Mark slot as occupied
	_slots[slotKey].Occupied = true

	-- ⭐ Create visual spawner avec ROTATION DU SLOT
	local slotPart = _slots[slotKey].Part
	local spawnerPart = PlacementService.CreateSpawnerPart(rarity, slotPart)  -- ⭐ Passer le slot

	-- Store references
	_slots[slotKey].SpawnerPart = spawnerPart

	-- Update slot visual
	_slots[slotKey].Part.Color = Color3.fromRGB(255, 0, 0)
	_slots[slotKey].Part.ProximityPrompt.Enabled = false

	-- Remove from inventory
	playerData:RemoveFromInventory(rarity)

	-- ⭐ Start spawner avec le spawnerPart
	task.spawn(function()
		_SpawnerService.StartSpawner(userId, rarity, spawnerPart)
	end)

	-- Save placement to DataStore
	if playerData then
		table.insert(playerData.placedSpawners, {
			SlotName = slotName,
			Rarity = rarity,
		})

		_PlayerDataService.SavePlayer(userId)
		print("Spawner saved:", slotName, rarity)
	end

	return true
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
function PlacementService.CreateSpawnerPart(rarity, slotPart)  -- ⭐ Passer le slot, pas la position
	local part = Instance.new("Part")
	part.Name = "Spawner_" .. rarity
	part.Size = Vector3.new(7, 1, 7)
	part.Anchored = true

	-- ⭐ Hériter EXACTEMENT du CFrame du slot (position + rotation)
	part.CFrame = slotPart.CFrame * CFrame.new(0, 2, 0)  -- 2 studs au-dessus du slot

	-- Color by rarity
	if rarity == "Common" then
		part.Color = Color3.fromRGB(135, 135, 135)
	elseif rarity == "Rare" then
		part.Color = Color3.fromRGB(0, 0, 255)
	elseif rarity == "Epic" then
		part.Color = Color3.fromRGB(128, 0, 128)
	elseif rarity == "Legendary" then
		part.Color = Color3.fromRGB(255, 215, 0)
	end

	part.Parent = workspace
	return part
end

-- Gets first available spawner from player inventory
-- @param playerData: PlayerData - Player data instance
-- @return string|nil - Rarity of first available spawner or nil if none
function PlacementService.GetFirstAvailableSpawner(playerData)
	local rarityOrder = {"Common", "Rare", "Epic", "Legendary"}

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

	print("Spawners to restore:", #playerData.placedSpawners)

	-- Restore each saved spawner
	for i, placedData in ipairs(playerData.placedSpawners) do
		print("Restoring spawner", i, ":", placedData.SlotName, placedData.Rarity)

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

		-- Update slot visual
		slotData.Part.Color = Color3.fromRGB(255, 0, 0)
		slotData.Part.ProximityPrompt.Enabled = false

		-- ⭐ Restart spawner avec spawnerPart
		task.spawn(function()
			_SpawnerService.StartSpawner(userId, rarity, spawnerPart)
		end)

		print("Spawner restored:", slotName, rarity)
	end
end

return PlacementService
