--[[
	Gestion du placement des générateurs (oeufs) sur les socles

	Workflow :
	  Joueur approche un socle → appuie sur E → pose un oeuf de sa rareté
	  → le système tire aléatoirement un brainrot dans la pool de cette rareté
	  → tire aussi une variante (Normal, Gold, Diamond, Galaxy, Lava, Rainbow)
	  → ce brainrot génère X$/s * multiplicateur de variante
	  → le brainrot tiré est sauvegardé pour restauration à la reconnexion

	Chemins des modèles :
	  ServerStorage/BrainrotModels/{Rarity}/{NomBrainrot}/{Variante}
]]

local GeneratorPlacementService = {}

local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotService       = require(script.Parent.Parent.Core.PlotService)
local PlacementService  = require(script.Parent.PlacementService)
local LevelService      = require(script.Parent.Parent.Progression.LevelService)
local LevelConfig       = require(ReplicatedStorage.Shared.LevelConfig)
local VariantConfig     = require(ReplicatedStorage.Shared.VariantConfig)

local _PlayerDataService      = nil
local _GeneratorService       = nil
local _generatorSlots         = {}  -- [userId_slotName] = slotData
local _onRevenuePerSecChanged = ReplicatedStorage
	:WaitForChild("RemoteInterface")
	:WaitForChild("Events")
	:WaitForChild("OnRevenuePerSecondChanged")

local function notifyTotalRevenue(userId)
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return end
	local total = 0
	for _, entry in ipairs(playerData.placedGenerators) do
		total += entry.RevenuePerSecond or 0
	end
	local player = game.Players:GetPlayerByUserId(userId)
	if player then
		_onRevenuePerSecChanged:FireClient(player, total)
	end
end

local RARITY_COLORS = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(30,  180, 30),
	Rare      = Color3.fromRGB(0,   100, 255),
	Epic      = Color3.fromRGB(128, 0,   128),
	Legendary = Color3.fromRGB(255, 215, 0),
}

local function formatMoney(n)
	local s = tostring(math.floor(n))
	return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- Pool dynamique : construit en scannant BrainrotModels/{rarity}/ au démarrage
local _dynamicPools = {}  -- [rarity] = { {Name, ModelName, Weight, RevenuePerSecond}, ... }

local function buildDynamicPools(GeneratorConfig)
	local BrainrotConfig = require(script.Parent.Parent.Parent.Config.BrainrotConfig)
	local brainrotModels = ServerStorage:FindFirstChild("BrainrotModels")
	if not brainrotModels then
		warn("[GPS] ❌ BrainrotModels introuvable — pools dynamiques vides")
		return
	end

	for rarity, rarityData in pairs(GeneratorConfig) do
		local tierFolder = brainrotModels:FindFirstChild(rarity)
		if not tierFolder then
			warn("[GPS] ⚠️ Dossier BrainrotModels/" .. rarity .. " introuvable")
			continue
		end

		local rarityBrainrots = BrainrotConfig[rarity] or {}
		local pool = {}
		for _, folder in ipairs(tierFolder:GetChildren()) do
			local cfg = rarityBrainrots[folder.Name]
			local revenue = cfg and cfg.RevenuePerSecond or rarityData.RevenuePerSecond or 0
			table.insert(pool, {
				Name             = folder.Name,
				ModelName        = folder.Name,
				Weight           = 1,
				RevenuePerSecond = revenue,
			})
		end

		_dynamicPools[rarity] = pool
		print(string.format("[GPS] Pool %s : %d brainrots chargés", rarity, #pool))
	end
end

function GeneratorPlacementService.Init(PlayerDataService, GeneratorService)
	_PlayerDataService = PlayerDataService
	_GeneratorService  = GeneratorService

	local GeneratorConfig = require(script.Parent.Parent.Parent.Config.GeneratorConfig)
	buildDynamicPools(GeneratorConfig)

	print("GeneratorPlacementService initialized")
end

-- ── Tire aléatoirement un brainrot dans la pool (poids égaux) ────────────────
local function rollBrainrot(pool)
	return pool[math.random(1, #pool)]
end

-- ── Tire une variante au hasard selon les poids de VariantConfig ─────────────
-- @return variantName (string), revenueMultiplier (number)
local function rollVariantName()
	local totalWeight = 0
	for _, v in ipairs(VariantConfig.Order) do
		totalWeight += VariantConfig.Weights[v] or 0
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, variant in ipairs(VariantConfig.Order) do
		cumulative += VariantConfig.Weights[variant] or 0
		if roll <= cumulative then
			return variant, VariantConfig.RevenueMultiplier[variant] or 1
		end
	end
	return "Normal", 1  -- fallback
end

-- ── Tags le visuel avec rareté, variante et revenus (pour GeneratorLabelHandler)
local function tagGeneratorVisual(instance, rarity, variant, revenuePerSecond)
	instance:SetAttribute("BrainrotRarity",  rarity)
	instance:SetAttribute("BrainrotVariant", variant or "Normal")
	instance:SetAttribute("BrainrotRevenue", revenuePerSecond)
end

-- ── Crée le visuel du brainrot sur le socle ──────────────────────────────────
-- Chemin modèle : BrainrotModels/{rarity}/{modelName}/{variant}
local function createGeneratorVisual(slotData, rarity, modelName, revenuePerSecond, variant)
	local slotCF   = slotData.Model.PrimaryPart.CFrame
	local variantToUse = variant or "Normal"

	if modelName then
		local brainrotModels = ServerStorage:FindFirstChild("BrainrotModels")
		local tierFolder     = brainrotModels and brainrotModels:FindFirstChild(rarity)
		local brainrotFolder = tierFolder and tierFolder:FindFirstChild(modelName)

		if not brainrotModels then
			warn("[GPS] ❌ BrainrotModels introuvable dans ServerStorage")
		elseif not tierFolder then
			warn("[GPS] ❌ Dossier rareté introuvable :", rarity)
		elseif not brainrotFolder then
			warn("[GPS] ❌ Dossier brainrot introuvable :", modelName, "dans", rarity)
			-- Lister ce qui existe pour aider au diagnostic
			local available = {}
			for _, c in ipairs(tierFolder:GetChildren()) do table.insert(available, c.Name) end
			warn("[GPS]    Dossiers disponibles :", table.concat(available, ", "))
		end

		-- Convention de nommage :
		--   Normal  → "Fluri Flura"       (juste le nom du brainrot)
		--   Gold    → "Gold Fluri Flura"  ({variant} {nomBrainrot})
		local modelInstanceName = (variantToUse == "Normal")
			and modelName
			or (variantToUse .. " " .. modelName)

		local template = brainrotFolder and brainrotFolder:FindFirstChild(modelInstanceName)
		if not template and brainrotFolder then
			warn("[GPS] ❌ Modèle introuvable :", modelInstanceName, "— fallback premier enfant")
			local children = brainrotFolder:GetChildren()
			if #children > 0 then
				template = children[1]
				warn("[GPS]    Fallback sur :", template.Name)
			end
		end

		if template and template:IsA("Model") then
			-- Mesurer l'offset pivot→bas sur le template dans ServerStorage
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
			for _, desc in ipairs(clone:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.Anchored   = true
					desc.CanCollide = true
				elseif desc:IsA("BillboardGui") then
					desc:Destroy()
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
			tagGeneratorVisual(clone, rarity, variantToUse, revenuePerSecond)

			-- ── Billboard monde (taille proportionnelle à la distance) ──────────
			local _, modelSize = clone:GetBoundingBox()
			local billboard = Instance.new("BillboardGui")
			billboard.Name        = "BrainrotLabel"
			billboard.Size        = UDim2.new(0, 200, 0, 72)
			billboard.StudsOffset = Vector3.new(0, modelSize.Y / 2 + 3, 0)
			billboard.AlwaysOnTop = false
			billboard.MaxDistance = 60
			billboard.Parent      = clone

			local bg = Instance.new("Frame")
			bg.Size                   = UDim2.new(1, 0, 1, 0)
			bg.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
			bg.BackgroundTransparency = 0.3
			bg.BorderSizePixel        = 0
			bg.Parent                 = billboard
			Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size                   = UDim2.new(1, -10, 0.38, 0)
			nameLbl.Position               = UDim2.new(0, 5, 0.04, 0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text                   = modelName or "?"
			nameLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
			nameLbl.Font                   = Enum.Font.GothamBold
			nameLbl.TextScaled             = true
			nameLbl.Parent                 = bg

			local variantColor = VariantConfig.Colors[variantToUse] or RARITY_COLORS[rarity]
			local variantLbl = Instance.new("TextLabel")
			variantLbl.Size                   = UDim2.new(1, -10, 0.30, 0)
			variantLbl.Position               = UDim2.new(0, 5, 0.38, 0)
			variantLbl.BackgroundTransparency = 1
			variantLbl.Text                   = variantToUse ~= "Normal" and variantToUse or rarity
			variantLbl.TextColor3             = variantColor
			variantLbl.Font                   = Enum.Font.GothamBold
			variantLbl.TextScaled             = true
			variantLbl.Parent                 = bg

			local revenueLbl = Instance.new("TextLabel")
			revenueLbl.Size                   = UDim2.new(1, -10, 0.28, 0)
			revenueLbl.Position               = UDim2.new(0, 5, 0.68, 0)
			revenueLbl.BackgroundTransparency = 1
			revenueLbl.Text                   = "$" .. formatMoney(revenuePerSecond) .. "/s"
			revenueLbl.TextColor3             = Color3.fromRGB(100, 255, 100)
			revenueLbl.Font                   = Enum.Font.GothamBold
			revenueLbl.TextScaled             = true
			revenueLbl.Parent                 = bg

			return clone
		end
	end

	-- Fallback : Part colorée
	local part = Instance.new("Part")
	part.Name       = modelName or ("Generator_" .. rarity)
	part.Size       = Vector3.new(4, 3, 4)
	part.CFrame     = CFrame.new(slotCF.Position + Vector3.new(0, 2, 0))
	part.Anchored   = true
	part.CanCollide = true
	part.Color      = RARITY_COLORS[rarity] or Color3.fromRGB(200, 200, 200)
	part.Parent     = slotData.Model
	slotData.GeneratorPart = part
	tagGeneratorVisual(part, rarity, variantToUse, revenuePerSecond)
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

		for _, existing in ipairs(slotModel:GetDescendants()) do
			if existing:IsA("ProximityPrompt") then existing:Destroy() end
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText            = "Poser l'oeuf"
		prompt.ObjectText            = slotModel.Name
		prompt.MaxActivationDistance = 10
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

	-- Vérifier si un brainrot Tool est ACTIVEMENT ÉQUIPÉ en main
	local brainrotTool, brainrotName, modelName, brainrotRarity, revenue, variantName
	if player.Character then
		local equipped = player.Character:FindFirstChildOfClass("Tool")
		if equipped and equipped.Name:match("^Brainrot_") then
			brainrotTool  = equipped
			brainrotName  = equipped:GetAttribute("BrainrotName")
			modelName     = equipped:GetAttribute("ModelName") or ""
			brainrotRarity = equipped:GetAttribute("Rarity")
			revenue       = equipped:GetAttribute("RevenuePerSecond")
			variantName   = equipped:GetAttribute("BrainrotVariant") or "Normal"
		end
	end

	local brainrot, rarity, isDirectBrainrot

	if brainrotTool then
		-- Brainrot déjà existant reposé → variante conservée, revenue conservé
		brainrot = {
			Name             = brainrotName,
			ModelName        = modelName ~= "" and modelName or nil,
			RevenuePerSecond = revenue,
		}
		rarity           = brainrotRarity
		isDirectBrainrot = true
	else
		-- Oeuf → roll aléatoire dans la pool + tirage de variante
		local _, eggRarity = PlacementService.GetEquippedEggInfo(player)
		if not eggRarity then return end
		rarity = eggRarity

		local pool = _dynamicPools[rarity]
		if not pool or #pool == 0 then
			warn("Pas de pool dynamique pour la rareté:", rarity)
			return
		end

		brainrot = rollBrainrot(pool)

		-- Tirage de variante
		local multiplier
		variantName, multiplier = rollVariantName()
		revenue = math.floor((brainrot.RevenuePerSecond or 0) * multiplier)
		brainrot = {
			Name             = brainrot.Name,
			ModelName        = brainrot.ModelName,
			RevenuePerSecond = revenue,
		}
	end

	-- Marquer le slot comme occupé
	slotData.Occupied = true

	-- Visuel
	createGeneratorVisual(slotData, rarity, brainrot.ModelName, brainrot.RevenuePerSecond, variantName)

	-- Retirer l'item utilisé
	if isDirectBrainrot then
		PlacementService.RemoveBrainrotTool(player, brainrotName)
		_PlayerDataService.RemoveBrainrot(userId, brainrotName)
	else
		_PlayerDataService.RemoveGenerator(userId, rarity)
		PlacementService.RemoveEggTool(player, rarity)
	end

	-- Démarrer la génération d'argent
	_GeneratorService.StartGeneratorLoop(userId, slotKey, brainrot.RevenuePerSecond, 1)

	-- EXP à la découverte du brainrot (oeuf seulement, pas si brainrot reposé)
	if not isDirectBrainrot then
		local tierExp     = LevelConfig.ExpRewards.BrainrotDiscovered.Tiers[rarity] or 0
		local variantMult = LevelConfig.ExpRewards.BrainrotDiscovered.VariantMultiplier[variantName] or 1
		LevelService.AddExp(userId, tierExp * variantMult)
	end

	-- Switch ProximityPrompt → mode "Récupérer"
	if slotData.PlacementConnection then
		slotData.PlacementConnection:Disconnect()
		slotData.PlacementConnection = nil
	end
	local prompt = slotData.Prompt
	prompt.ActionText   = "Récupérer"
	prompt.ObjectText   = brainrot.Name .. (variantName ~= "Normal" and (" · " .. variantName) or "")
	prompt.HoldDuration = 0
	prompt.Enabled      = true

	local capturedSlotName = slotModel.Name
	slotData.PickupConnection = prompt.Triggered:Connect(function(trigPlayer)
		if trigPlayer.UserId ~= userId then return end
		GeneratorPlacementService.PickupGenerator(userId, capturedSlotName, trigPlayer)
	end)

	-- Marquer comme découvert (Index)
	playerData:DiscoverBrainrot(brainrot.Name, variantName)

	-- Sauvegarder le placement
	table.insert(playerData.placedGenerators, {
		SlotName         = slotModel.Name,
		Rarity           = rarity,
		BrainrotName     = brainrot.Name,
		ModelName        = brainrot.ModelName,
		Variant          = variantName,
		RevenuePerSecond = brainrot.RevenuePerSecond,
	})

	notifyTotalRevenue(userId)
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

		-- Recréer le visuel avec le brainrot et la variante sauvegardés
		local variant = placedData.Variant or "Normal"
		createGeneratorVisual(slotData, placedData.Rarity, placedData.ModelName, placedData.RevenuePerSecond, variant)

		-- Relancer la génération d'argent
		_GeneratorService.StartGeneratorLoop(userId, slotKey, placedData.RevenuePerSecond, 1)

		-- Switch ProximityPrompt → mode "Récupérer"
		if slotData.PlacementConnection then
			slotData.PlacementConnection:Disconnect()
			slotData.PlacementConnection = nil
		end
		local prompt = slotData.Prompt
		prompt.ActionText   = "Récupérer"
		prompt.ObjectText   = (placedData.BrainrotName or "") .. (variant ~= "Normal" and (" · " .. variant) or "")
		prompt.HoldDuration = 0
		prompt.Enabled      = true

		local capturedSlotName = placedData.SlotName
		local capturedRarity   = placedData.Rarity
		slotData.PickupConnection = prompt.Triggered:Connect(function(trigPlayer)
			if trigPlayer.UserId ~= userId then return end
			GeneratorPlacementService.PickupGenerator(userId, capturedSlotName, trigPlayer)
		end)
	end
	notifyTotalRevenue(userId)
end

-- ── Récupère un générateur posé et remet le brainrot dans l'inventaire ───────
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
	local placed        = playerData.placedGenerators[placedIndex]
	local brainrotName  = placed.BrainrotName
	local brainrotModel = placed.ModelName
	local brainrotRarity = placed.Rarity
	local brainrotRevenue = placed.RevenuePerSecond
	local brainrotVariant = placed.Variant or "Normal"

	-- Retirer de placedGenerators
	table.remove(playerData.placedGenerators, placedIndex)

	-- Déconnecter pickup, reconnecter placement
	if slotData.PickupConnection then
		slotData.PickupConnection:Disconnect()
		slotData.PickupConnection = nil
	end

	local prompt = slotData.Prompt
	prompt.ActionText   = "Poser l'oeuf"
	prompt.ObjectText   = slotData.Model.Name
	prompt.HoldDuration = 0
	prompt.Enabled      = true

	slotData.PlacementConnection = prompt.Triggered:Connect(function(trigPlayer)
		if trigPlayer.UserId ~= userId then return end
		GeneratorPlacementService.OnSlotTriggered(trigPlayer, slotData.Model)
	end)

	-- Redonner le brainrot spécifique comme Tool (variante conservée)
	if player then
		PlacementService.GiveBrainrotTool(player, brainrotName, brainrotModel, brainrotRarity, brainrotRevenue, brainrotVariant)
	end
	_PlayerDataService.AddBrainrot(userId, brainrotName, brainrotModel, brainrotRarity, brainrotRevenue, brainrotVariant)

	notifyTotalRevenue(userId)
end

-- Appelé depuis PlayerLifecycleHandler avec un délai pour sync initial
function GeneratorPlacementService.SyncRevenueToClient(userId)
	notifyTotalRevenue(userId)
end

return GeneratorPlacementService
