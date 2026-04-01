--[[
	Gestion des spawners de toys
	Chaque spawner roll une rareté via ses DropRates, puis pioche un modèle
	aléatoire dans ServerStorage/BrainrotModels/{ToyRarity}/{NomBrainrot}/{Variante}

	Fallback : Part colorée si le dossier est vide ou absent
]]

local SpawnerService = {}

local PhysicsService    = game:GetService("PhysicsService")
local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotService       = require(script.Parent.Parent.Core.PlotService)
local LevelService      = require(script.Parent.Parent.Progression.LevelService)
local LevelConfig       = require(ReplicatedStorage.Shared.LevelConfig)

-- Les toys sont des miniatures : 30% de la taille originale du modèle
local TOY_SCALE = 0.3

-- Les toys ne se collisionnent pas entre eux
pcall(function() PhysicsService:RegisterCollisionGroup("Toys") end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("Toys", "Toys", false) end)

local RARITY_COLORS = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(30,  180, 30),
	Rare      = Color3.fromRGB(0,   100, 255),
	Epic      = Color3.fromRGB(128, 0,   128),
	Legendary = Color3.fromRGB(255, 215, 0),
}

local _SpawnerConfig    = nil
local _PlayerDataService = nil
local _activeSpawners   = {}  -- [userId_slotName] = true
local _serverStartTime  = tick()  -- horloge globale de référence

function SpawnerService.Init(SpawnerConfig, ToyConfig, PlayerDataService)
	_SpawnerConfig     = SpawnerConfig
	_PlayerDataService = PlayerDataService
end

-- Démarre la boucle de génération d'un spawner
-- slotName sert de clé unique → plusieurs spawners de même rareté coexistent
function SpawnerService.StartSpawner(userId, rarity, spawnerPart, slotName)
	if not _SpawnerConfig[rarity] then
		warn("SpawnerConfig manquant pour:", rarity)
		return
	end

	local spawnRate = _SpawnerConfig[rarity].SpawnRate
	local spawnerId = userId .. "_" .. (slotName or rarity)
	_activeSpawners[spawnerId] = true

	task.spawn(function()
		while _activeSpawners[spawnerId] do
			-- Synchronisation globale : attendre le prochain tick commun
			local elapsed  = tick() - _serverStartTime
			local nextTick = (math.floor(elapsed / spawnRate) + 1) * spawnRate
			task.wait(nextTick - elapsed)

			if not _activeSpawners[spawnerId] then break end
			SpawnerService.SpawnToy(userId, rarity, spawnerPart)
		end
	end)
end

-- Arrête la boucle d'un spawner via sa clé unique (slotName)
function SpawnerService.StopSpawner(userId, slotName)
	_activeSpawners[userId .. "_" .. slotName] = nil
end

-- Calcule l'angle Y (snappé à 90°) vers la zone de collection du plot
local function getCollectorAngle(fromPos, plot)
	if not plot then return 0 end
	local col  = plot:FindFirstChild("Collection", true)
	local zone = col and col:FindFirstChild("StructureCollectionZone")
	local ref  = zone and (zone.PrimaryPart or zone:FindFirstChildWhichIsA("BasePart"))
	if not ref then return 0 end
	local toRef    = ref.Position - fromPos
	local rawAngle = math.atan2(toRef.X, toRef.Z) + math.pi
	return math.rad(math.round(math.deg(rawAngle) / 90) * 90)
end

-- Pioche un modèle aléatoire dans :
--   ServerStorage/GeneratorModels/{rarity}/
local function pickRandomModel(rarity)
	local generatorModels = ServerStorage:FindFirstChild("GeneratorModels")
	if not generatorModels then
		warn("[SpawnerService] ❌ Dossier 'GeneratorModels' introuvable dans ServerStorage")
		return nil
	end

	local tierFolder = generatorModels:FindFirstChild(rarity)
	if not tierFolder then
		warn("[SpawnerService] ❌ Dossier rareté introuvable :", rarity)
		return nil
	end

	local children = tierFolder:GetChildren()
	if #children == 0 then
		warn("[SpawnerService] ❌ Aucun modèle dans GeneratorModels/" .. rarity)
		return nil
	end

	return children[math.random(1, #children)]
end

-- Spawne un toy au niveau du spawner
function SpawnerService.SpawnToy(userId, spawnerRarity, spawnerPart)
	if not userId or not spawnerRarity or not spawnerPart then return end

	local spawnerConfig = _SpawnerConfig[spawnerRarity]
	if not spawnerConfig then return end

	local plot     = PlotService.GetPlot(userId)
	local template = pickRandomModel(spawnerRarity)

	-- ── Préparer le visuel ───────────────────────────────────────────────────
	local visual = nil
	if template and template:IsA("Model") then
		visual = template:Clone()
		pcall(function() visual:ScaleTo(TOY_SCALE) end)
	end

	-- ── Position de spawn ─────────────────────────────────────────────────────
	local spawnPos = spawnerPart.Position + Vector3.new(0, 1.5, 0)
	local spawnCF  = CFrame.new(spawnPos)

	-- ── Corps physique : petite sphère invisible ─────────────────────────────
	local root = Instance.new("Part")
	root.Name           = "PhysicsRoot"
	root.Shape          = Enum.PartType.Ball
	root.Size           = Vector3.new(0.9, 0.9, 0.9)
	root.Transparency   = 1
	root.CanCollide     = true
	root.CollisionGroup = "Toys"
	root.Anchored       = false
	root.CFrame         = spawnCF
	root:SetAttribute("ToyRarity", spawnerRarity)
	root:SetAttribute("OwnerId",   userId)

	-- Bloquer toute rotation (le toy glisse sans tourner sur lui-même)
	local bav = Instance.new("BodyAngularVelocity")
	bav.AngularVelocity = Vector3.zero
	bav.MaxTorque       = Vector3.new(1e6, 1e6, 1e6)
	bav.P               = 1e5
	bav.Parent          = root

	-- ── Conteneur Model ───────────────────────────────────────────────────────
	local toyModel        = Instance.new("Model")
	toyModel.Name         = "Toy_" .. spawnerRarity .. "_" .. userId
	toyModel.PrimaryPart  = root
	root.Parent           = toyModel

	-- ── Modèle visuel soudé au root ───────────────────────────────────────────
	if visual then
		-- Le visuel ne participe pas à la physique
		for _, part in ipairs(visual:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.Massless   = true
				part.Anchored   = false
			end
		end

		local primaryVisual = visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart")
		if primaryVisual then
			local originalRotation = template:GetPivot().Rotation
			local visualOffset = Vector3.new(0, 1.0, 0)
			local yAngle = getCollectorAngle(spawnPos, plot)
			visual:PivotTo(CFrame.new(spawnCF.Position + visualOffset) * CFrame.Angles(0, yAngle, 0) * originalRotation)
			visual.Parent = toyModel
			local weld   = Instance.new("WeldConstraint")
			weld.Part0   = root
			weld.Part1   = primaryVisual
			weld.Parent  = root
		else
			visual.Parent = toyModel
		end
	end

	toyModel.Parent = plot or workspace
end

return SpawnerService
