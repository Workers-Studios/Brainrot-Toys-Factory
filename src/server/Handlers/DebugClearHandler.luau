--[[
	DebugClearHandler — PNJ de vidage d'inventaire (tests uniquement)

	BrainrotPNJ → E : supprime les brainrots nommés de l'inventaire
	              (brainrotInventory + tools Brainrot_*)
	              NE TOUCHE PAS : oeufs (Oeuf_*), generatorInventory,
	                              placedGenerators (brainrots sur socles)

	SpawnerPNJ  → E : supprime les spawners de l'inventaire
	              (inventory counts + tools spawner)
	              NE TOUCHE PAS : oeufs, generatorInventory,
	                              placedSpawners (spawners sur slots)
]]

local DebugClearHandler = {}

local workspace = game:GetService("Workspace")

local _PlayerDataService = nil

-- ── Utilitaires ───────────────────────────────────────────────────────────────

local function getPrimaryPart(model)
	if model:IsA("Model") then
		return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	end
	return model:IsA("BasePart") and model or nil
end

local function addPrompt(part, actionText, objectText)
	local existing = part:FindFirstChildOfClass("ProximityPrompt")
	if existing then existing:Destroy() end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = actionText
	prompt.ObjectText            = objectText
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight   = false
	prompt.HoldDuration          = 0
	prompt.Parent                = part
	return prompt
end

-- ── Vente des brainrots nommés ────────────────────────────────────────────────
-- Supprime brainrotInventory + tools Brainrot_*
-- Conserve : oeufs (Oeuf_*), generatorInventory, placedGenerators

local function sellBrainrots(player)
	local userId     = player.UserId
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return end

	playerData.brainrotInventory = {}

	local function removeFromContainer(container)
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") and tool.Name:match("^Brainrot_") then
				tool:Destroy()
			end
		end
	end
	removeFromContainer(player.Backpack)
	if player.Character then removeFromContainer(player.Character) end

	_PlayerDataService.SavePlayer(userId)
	print(string.format("[Debug] Brainrots vendus pour %s", player.Name))
end

-- ── Vente des spawners en inventaire ─────────────────────────────────────────
-- Supprime inventory (counts) + tools spawner
-- Conserve : oeufs (Oeuf_*), generatorInventory, placedSpawners

local SPAWNER_RARITIES = { Common=true, Uncommon=true, Rare=true, Epic=true, Legendary=true }

local function sellSpawners(player)
	local userId     = player.UserId
	local playerData = _PlayerDataService.GetPlayerData(userId)
	if not playerData then return end

	for rarity in pairs(playerData.inventory) do
		playerData.inventory[rarity] = 0
	end

	local function removeFromContainer(container)
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") and (SPAWNER_RARITIES[tool.Name] or tool:GetAttribute("SpawnerRarity")) then
				tool:Destroy()
			end
		end
	end
	removeFromContainer(player.Backpack)
	if player.Character then removeFromContainer(player.Character) end

	_PlayerDataService.SavePlayer(userId)
	print(string.format("[Debug] Spawners vendus pour %s", player.Name))
end

-- ── Initialisation ────────────────────────────────────────────────────────────

function DebugClearHandler.Init(PlayerDataService)
	_PlayerDataService = PlayerDataService

	local brainrotPNJ = workspace:FindFirstChild("BrainrotPNJ")
	if brainrotPNJ then
		local part = getPrimaryPart(brainrotPNJ)
		if part then
			local prompt = addPrompt(part, "Vendre brainrots", "Debug")
			prompt.Triggered:Connect(function(player) sellBrainrots(player) end)
			print("[Debug] BrainrotPNJ connecté")
		else
			warn("[Debug] BrainrotPNJ : aucune BasePart trouvée")
		end
	else
		warn("[Debug] BrainrotPNJ introuvable dans Workspace")
	end

	local spawnerPNJ = workspace:FindFirstChild("SpawnerPNJ")
	if spawnerPNJ then
		local part = getPrimaryPart(spawnerPNJ)
		if part then
			local prompt = addPrompt(part, "Vendre spawners", "Debug")
			prompt.Triggered:Connect(function(player) sellSpawners(player) end)
			print("[Debug] SpawnerPNJ connecté")
		else
			warn("[Debug] SpawnerPNJ : aucune BasePart trouvée")
		end
	else
		warn("[Debug] SpawnerPNJ introuvable dans Workspace")
	end

	print("[Debug] DebugClearHandler initialisé")
end

return DebugClearHandler
