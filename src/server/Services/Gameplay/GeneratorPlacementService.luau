--[[
	Gestion du placement des générateurs (oeufs) sur les socles

	Workflow :
	  Joueur approche un socle → appuie sur E → pose un oeuf de sa rareté
	  → le système tire aléatoirement un brainrot dans la pool de cette rareté
	  → ce brainrot génère X$/s selon sa config (RevenuePerSecond)
	  → le brainrot tiré est sauvegardé pour restauration à la reconnexion
]]

local GeneratorPlacementService = {}

local ServerStorage    = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotService      = require(script.Parent.Parent.Core.PlotService)
local PlacementService = require(script.Parent.PlacementService)

local _PlayerDataService = nil
local _GeneratorService  = nil
local _generatorSlots    = {}  -- [userId_slotName] = slotData

-- RemoteEvent pour notifier le client du total de revenus/s de ses brainrots
local _eventsFolder = ReplicatedStorage:WaitForChild("RemoteInterface"):WaitForChild("Events")
local _OnRevenuePerSecondChanged = _eventsFolder:FindFirstChild("OnRevenuePerSecondChanged")
if not _OnRevenuePerSecondChanged then
	_OnRevenuePerSecondChanged = Instance.new("RemoteEvent")
	_OnRevenuePerSecondChanged.Name = "OnRevenuePerSecondChanged"
	_OnRevenuePerSecondChanged.Parent = _eventsFolder
end

-- Calcule le total des RevenuePerSecond de tous les brainrots posés d'un joueur
local function getTotalRevenue(userId)
	local playerData = _PlayerDataService and _PlayerDataService.GetPlayerData(userId)
	if not playerData then return 0 end
	local total = 0
	for _, placed in ipairs(playerData.placedGenerators) do
		total += (placed.RevenuePerSecond or 0)
	end
	return total
end

-- Notifie le client de la nouvelle somme de revenus/s
local function fireRevenueUpdate(userId)
	local player = game:GetService("Players"):GetPlayerByUserId(userId)
	if player then
		_OnRevenuePerSecondChanged:FireClient(player, getTotalRevenue(userId))
	end
end

local RARITY_COLORS = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(30,  180, 30),
	Rare      = Color3.fromRGB(0,   100, 255),
	Epic      = Color3.fromRGB(128, 0,   128),
	Legendary = Color3.fromRGB(255, 215, 0),
}

function GeneratorPlacementService.Init(PlayerDataService, GeneratorService)
	_PlayerDataService = PlayerDataService
	_GeneratorService  = GeneratorService
	print("GeneratorPlacementService initialized")
end

-- ── Tire aléatoirement un brainrot dans la pool selon les poids ───────────────
local function rollBrainrot(pool)
	local total = 0
	for _, entry in ipairs(pool) do
		total += entry.Weight
	end
	local roll = math.random() * total
	local cumulative = 0
	for _, entry in ipairs(pool) do
		cumulative += entry.Weight
		if roll <= cumulative then
			return entry
		end
	end
	return pool[#pool]
end

-- ── Crée le visuel du brainrot sur le socle ──────────────────────────────────
local function createGeneratorVisual(slotData, rarity, modelName)
	local slotCF = slotData.Model.PrimaryPart.CFrame
	-- Rotation identité : le modèle garde exactement son orientation de Studio (debout)
	local targetCF = CFrame.new(slotCF.Position + Vector3.new(0, 2, 0))

	-- Tenter de cloner le modèle depuis ServerStorage/GeneratorModels/{rarity}/{modelName}
	if modelName then
		local generatorModels = ServerStorage:FindFirstChild("GeneratorModels")
		local folder = generatorModels and generatorModels:FindFirstChild(rarity)
		local template = folder and folder:FindFirstChild(modelName)

		if template and template:IsA("Model") then
			-- Mesurer l'offset pivot→bas sur le template dans ServerStorage
			-- On ne considère que les parts visibles et non-minuscules pour éviter les parts fantômes
			local templatePivotY = template:GetPivot().Position.Y
			local minY = math.huge
			for _, part in ipairs(template:GetDescendants()) do
				if part:IsA("BasePart") and part.Transparency < 0.99 and part.Size.Magnitude > 0.3 then
					local cf, s = part.CFrame, part.Size / 2
					for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
						local corner = cf:PointToWorldSpace(Vector3.new(s.X*sx, s.Y*sy, s.Z*sz))
						minY = math.min(minY, corner.Y)
					end end end
				end
			end
			local templateBottomY = minY < math.huge and minY or templatePivotY
			local pivotToBottom   = templatePivotY - templateBottomY

			-- HeightOffset optionnel sur le modèle dans Studio pour fine-tuning
			local heightOffset = template:GetAttribute("HeightOffset") or 0

			-- Placer le clone : base exactement sur le dessus du socle
			local pedestalTopY = slotData.Model.PrimaryPart.Position.Y + slotData.Model.PrimaryPart.Size.Y / 2
			local finalPivotY  = pedestalTopY + pivotToBottom + heightOffset
			local originalRotation = template:GetPivot().Rotation

			local clone = template:Clone()
			for _, part in ipairs(clone:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored  = true
					part.CanCollide = true
				end
			end
				local slotYAngle
			local current = slotData.Model.Parent
			for _ = 1, 6 do
				if not current or current == workspace then break end
				local col  = current:FindFirstChild("Collection")
				local zone = col and col:FindFirstChild("StructureCollectionZone")
				local ref  = zone and (zone.PrimaryPart or zone:FindFirstChildWhichIsA("BasePart"))
				if ref then
					local toRef = ref.Position - slotCF.Position
					local rawAngle = math.atan2(toRef.X, toRef.Z) + math.pi
					local snap = 90
					slotYAngle = math.rad(math.round(math.deg(rawAngle) / snap) * snap)
					break
				end
				current = current.Parent
			end
			slotYAngle = slotYAngle or (math.atan2(-slotCF.ZVector.X, slotCF.ZVector.Z) + math.pi)

			clone:PivotTo(CFrame.new(slotCF.Position.X, finalPivotY, slotCF.Position.Z) * CFrame.Angles(0, slotYAngle, 0) * originalRotation)
			clone.Parent = slotData.Model
			slotData.GeneratorPart = clone
			return clone
		end
	end

	-- Fallback : Part colorée
	local part = Instance.new("Part")
	part.Name      = modelName or ("Generator_" .. rarity)
	part.Size      = Vector3.new(4, 3, 4)
	part.CFrame    = targetCF
	part.Anchored  = true
	part.CanCollide = true
	part.Color     = RARITY_COLORS[rarity] or Color3.fromRGB(200, 200, 200)
	part.Parent    = slotData.Model
	slotData.GeneratorPart = part
	return part
end

-- ── Initialise les socles générateurs du plot d'un joueur ────────────────────
function GeneratorPlacementService.InitializePlotSlots(userId)
	local plot = PlotService.GetPlot(userId)
	if not plot then
		warn("Plot not found for userId:", userId)
		return
	end

	local slotsFolder = plot:FindFirstChild("GeneratorSlots")
	if not slotsFolder then
		warn("GeneratorSlots not found in plot for userId:", userId)
		return
	end

	for _, slotModel in ipairs(slotsFolder:GetChildren()) do
		if not slotModel:IsA("Model") or not slotModel.PrimaryPart then continue end

		-- Supprimer les ProximityPrompts existants et en créer un propre
		for _, existing in ipairs(slotModel:GetDescendants()) do
			if existing:IsA("ProximityPrompt") then existing:Destroy() end
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText            = "Poser l'oeuf"
		prompt.ObjectText            = slotModel.Name
		prompt.MaxActivationDistance = 32
		prompt.RequiresLineOfSight   = false
		prompt.HoldDuration          = 0
		prompt.Enabled               = true
		prompt.Parent                = slotModel.PrimaryPart

		local slotKey = userId .. "_" .. slotModel.Name
		_generatorSlots[slotKey] = {
			Model               = slotModel,
			Prompt              = prompt,
			Occupied            = false,
			GeneratorPart       = nil,
			PlacementConnection = nil,
			PickupConnection    = nil,
			UserId              = userId,
		}

		_generatorSlots[slotKey].PlacementConnection = prompt.Triggered:Connect(function(player)
			if player.UserId == userId then
				GeneratorPlacementService.OnSlotTriggered(player, slotModel)
			end
		end)
	end

	print("Initialized", #slotsFolder:GetChildren(), "generator slots for plot", userId)
end

-- ── Pose de l'oeuf sur un socle ──────────────────────────────────────────────
function GeneratorPlacementService.OnSlotTriggered(player, slotModel)
	local userId = player.UserId
	local slotKey = userId .. "_" .. slotModel.Name

	local slotData = _generatorSlots[slotKey]
	if not slotData or slotData.Occupied then return end

	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return end

	-- Vérifier si un brainrot Tool est ACTIVEMENT ÉQUIPÉ en main (pas juste dans le backpack)
	local brainrotTool, brainrotName, modelName, brainrotRarity, revenue
	if player.Character then
		local equipped = player.Character:FindFirstChildOfClass("Tool")
		if equipped and equipped.Name:match("^Brainrot_") then
			brainrotTool = equipped
			brainrotName     = equipped:GetAttribute("BrainrotName")
			modelName        = equipped:GetAttribute("ModelName") or ""
			brainrotRarity   = equipped:GetAttribute("Rarity")
			revenue          = equipped:GetAttribute("RevenuePerSecond")
		end
	end

	local brainrot, rarity, isDirectBrainrot

	if brainrotTool then
		brainrot = { Name = brainrotName, ModelName = modelName ~= "" and modelName or nil, RevenuePerSecond = revenue }
		rarity   = brainrotRarity
		isDirectBrainrot = true
	else
		-- Sinon : oeuf → roll aléatoire dans la pool
		local _, eggRarity = PlacementService.GetEquippedEggInfo(player)
		if not eggRarity then return end
		rarity = eggRarity

		local GeneratorConfig = require(script.Parent.Parent.Parent.Config.GeneratorConfig)
		local rarityConfig = GeneratorConfig[rarity]
		if not rarityConfig or not rarityConfig.Pool or #rarityConfig.Pool == 0 then
			warn("Pas de Pool pour la rareté:", rarity)
			return
		end
		brainrot = rollBrainrot(rarityConfig.Pool)
	end

	-- Marquer le slot comme occupé
	slotData.Occupied = true

	-- Visuel
	createGeneratorVisual(slotData, rarity, brainrot.ModelName)

	-- Retirer l'item utilisé
	if isDirectBrainrot then
		PlacementService.RemoveBrainrotTool(player, brainrot.Name)
		_PlayerDataService.RemoveBrainrot(userId, brainrot.Name)
	else
		_PlayerDataService.RemoveGenerator(userId, rarity)
		PlacementService.RemoveEggTool(player, rarity)
	end

	-- Démarrer la génération d'argent (synchronisée)
	_GeneratorService.StartGeneratorLoop(userId, slotKey, brainrot.RevenuePerSecond, 1)

	-- Switch ProximityPrompt → mode "Récupérer"
	if slotData.PlacementConnection then
		slotData.PlacementConnection:Disconnect()
		slotData.PlacementConnection = nil
	end
	local prompt = slotData.Prompt
	prompt.ActionText          = "Récupérer"
	prompt.ObjectText          = brainrot.Name
	prompt.HoldDuration        = 0
	prompt.Enabled             = true

	local capturedSlotName = slotModel.Name
	slotData.PickupConnection = prompt.Triggered:Connect(function(trigPlayer)
		if trigPlayer.UserId ~= userId then return end
		GeneratorPlacementService.PickupGenerator(userId, capturedSlotName, trigPlayer)
	end)

	-- Sauvegarder le placement (avec le brainrot exact tiré)
	table.insert(playerData.placedGenerators, {
		SlotName         = slotModel.Name,
		Rarity           = rarity,
		BrainrotName     = brainrot.Name,
		ModelName        = brainrot.ModelName,
		RevenuePerSecond = brainrot.RevenuePerSecond,
	})

	_PlayerDataService.SavePlayer(userId)
	fireRevenueUpdate(userId)
end

-- ── Restauration des générateurs à la reconnexion ────────────────────────────
function GeneratorPlacementService.RestorePlacedGenerators(userId)
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return end

	for _, placedData in ipairs(playerData.placedGenerators) do
		local slotKey = userId .. "_" .. placedData.SlotName
		local slotData = _generatorSlots[slotKey]
		if not slotData then
			warn("Slot not found:", slotKey)
			continue
		end

		slotData.Occupied = true

		-- Recréer le visuel avec le brainrot sauvegardé
		createGeneratorVisual(slotData, placedData.Rarity, placedData.ModelName)

		-- Relancer la génération d'argent (revenue sauvegardé, pas de re-roll)
		_GeneratorService.StartGeneratorLoop(userId, slotKey, placedData.RevenuePerSecond, 1)

		-- Switch ProximityPrompt → mode "Récupérer"
		if slotData.PlacementConnection then
			slotData.PlacementConnection:Disconnect()
			slotData.PlacementConnection = nil
		end
		local prompt = slotData.Prompt
		prompt.ActionText = "Récupérer"
		prompt.ObjectText = placedData.BrainrotName or ""
		prompt.HoldDuration = 0
		prompt.Enabled = true

		local capturedSlotName = placedData.SlotName
		local capturedRarity   = placedData.Rarity
		slotData.PickupConnection = prompt.Triggered:Connect(function(trigPlayer)
			if trigPlayer.UserId ~= userId then return end
			GeneratorPlacementService.PickupGenerator(userId, capturedSlotName, trigPlayer)
		end)
	end

	-- Notifier le client du total restauré
	fireRevenueUpdate(userId)
end

-- ── Récupère un générateur posé et remet l'oeuf dans l'inventaire ────────────
function GeneratorPlacementService.PickupGenerator(userId, slotName, player)
	local slotKey  = userId .. "_" .. slotName
	local slotData = _generatorSlots[slotKey]
	if not slotData or not slotData.Occupied then return end

	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return end

	-- Trouver les données du générateur placé
	local rarity, placedIndex = nil, nil
	for i, placed in ipairs(playerData.placedGenerators) do
		if placed.SlotName == slotName then
			rarity      = placed.Rarity
			placedIndex = i
			break
		end
	end
	if not rarity then return end

	-- Stopper la génération d'argent
	_GeneratorService.StopGenerator(slotKey)

	-- Détruire le visuel
	if slotData.GeneratorPart then
		local model = slotData.GeneratorPart
		if model and model.Parent then model:Destroy() end
		slotData.GeneratorPart = nil
	end
	slotData.Occupied = false

	-- Récupérer les données du brainrot avant de retirer
	local placed = playerData.placedGenerators[placedIndex]
	local brainrotName     = placed.BrainrotName
	local brainrotModel    = placed.ModelName
	local brainrotRarity   = placed.Rarity
	local brainrotRevenue  = placed.RevenuePerSecond

	-- Retirer de placedGenerators
	table.remove(playerData.placedGenerators, placedIndex)

	-- Déconnecter pickup, reconnecter placement
	if slotData.PickupConnection then
		slotData.PickupConnection:Disconnect()
		slotData.PickupConnection = nil
	end

	local prompt = slotData.Prompt
	prompt.ActionText = "Poser l'oeuf"
	prompt.ObjectText = slotData.Model.Name
	prompt.HoldDuration = 0
	prompt.Enabled = true

	slotData.PlacementConnection = prompt.Triggered:Connect(function(trigPlayer)
		if trigPlayer.UserId ~= userId then return end
		GeneratorPlacementService.OnSlotTriggered(trigPlayer, slotData.Model)
	end)

	-- Redonner le brainrot spécifique comme Tool (pas un oeuf générique)
	if player then
		PlacementService.GiveBrainrotTool(player, brainrotName, brainrotModel, brainrotRarity, brainrotRevenue)
	end
	_PlayerDataService.AddBrainrot(userId, brainrotName, brainrotModel, brainrotRarity, brainrotRevenue)

	_PlayerDataService.SavePlayer(userId)
	fireRevenueUpdate(userId)
end

return GeneratorPlacementService
