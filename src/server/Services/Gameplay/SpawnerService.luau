--[[
	Gestion des spawners de toys
	Chaque spawner roll une rareté via ses DropRates, puis pioche un modèle
	aléatoire dans ServerStorage/ToyModels/{ToyRarity}/

	Fallback : Part colorée si le dossier est vide ou absent
]]

local SpawnerService = {}

local PhysicsService    = game:GetService("PhysicsService")
local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotService       = require(script.Parent.Parent.Core.PlotService)
local LevelService      = require(script.Parent.Parent.Progression.LevelService)
local LevelConfig       = require(ReplicatedStorage.Shared.LevelConfig)

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

-- Ordre fixe pour le roll cumulatif
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

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

-- Roll la rareté du toy selon les DropRates du spawner
local function rollToyRarity(dropRates)
	local roll = math.random()
	local cumulative = 0
	for _, rarity in ipairs(RARITY_ORDER) do
		local rate = dropRates[rarity]
		if rate then
			cumulative += rate
			if roll <= cumulative then
				return rarity
			end
		end
	end
	return "Common"  -- fallback
end

-- Pioche un modèle aléatoire dans ServerStorage/ToyModels/{rarity}
local function pickRandomModel(rarity)
	local toyModels = ServerStorage:FindFirstChild("ToyModels")
	if not toyModels then return nil end
	local folder = toyModels:FindFirstChild(rarity)
	if not folder then return nil end
	local models = folder:GetChildren()
	if #models == 0 then return nil end
	return models[math.random(1, #models)]
end

-- Spawne un toy au niveau du spawner
function SpawnerService.SpawnToy(userId, spawnerRarity, spawnerPart)
	if not userId or not spawnerRarity or not spawnerPart then return end

	local spawnerConfig = _SpawnerConfig[spawnerRarity]
	if not spawnerConfig then return end

	-- Roll la rareté du toy
	local toyRarity = rollToyRarity(spawnerConfig.DropRates)

	local plot    = PlotService.GetPlot(userId)
	local template = pickRandomModel(toyRarity)
	local toy

	if template then
		if template:IsA("Model") then
			toy = template:Clone()
			for _, part in ipairs(toy:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored       = false
					part.CanCollide     = true
					part.CollisionGroup = "Toys"
				end
			end
			local _, size = toy:GetBoundingBox()
			toy:PivotTo(CFrame.new(spawnerPart.Position + Vector3.new(0, size.Y / 2 + 1, 0)))

			local primary = toy.PrimaryPart or toy:FindFirstChildWhichIsA("BasePart")
			if primary then
				primary:SetAttribute("ToyRarity", toyRarity)
				primary:SetAttribute("OwnerId",   userId)
			end

		elseif template:IsA("BasePart") then
			toy = template:Clone()
			toy.Anchored       = false
			toy.CanCollide     = true
			toy.CollisionGroup = "Toys"
			toy.Position       = spawnerPart.Position + Vector3.new(0, toy.Size.Y / 2 + 1, 0)
			toy:SetAttribute("ToyRarity", toyRarity)
			toy:SetAttribute("OwnerId",   userId)
		end
	end

	-- Fallback : Part colorée
	if not toy then
		toy = Instance.new("Part")
		toy.Size           = Vector3.new(1, 1, 1)
		toy.Color          = RARITY_COLORS[toyRarity] or Color3.fromRGB(200, 200, 200)
		toy.Anchored       = false
		toy.CanCollide     = true
		toy.CollisionGroup = "Toys"
		toy.Position       = spawnerPart.Position + Vector3.new(0, 1.5, 0)
		toy:SetAttribute("ToyRarity", toyRarity)
		toy:SetAttribute("OwnerId",   userId)
	end

	toy.Name   = "Toy_" .. toyRarity .. "_" .. userId
	toy.Parent = plot or workspace

end

return SpawnerService
