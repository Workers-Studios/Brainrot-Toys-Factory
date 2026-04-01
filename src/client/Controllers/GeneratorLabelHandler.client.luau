--[[
	Affiche au-dessus de chaque brainrot posé un label taille fixe (pixels)
	montrant sa rareté et son taux $/s.

	Le serveur pose les attributs BrainrotRarity et BrainrotRevenue sur le modèle.
	Ce script surveille workspace et crée/détruit les labels en conséquence.
	Utilise Camera:WorldToViewportPoint pour une taille d'écran constante.
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function isOccluded(anchorPart, worldPos)
	-- Exclure le brainrot lui-même et le personnage du joueur
	local char = Players.LocalPlayer.Character
	local exclude = { anchorPart }
	if char then table.insert(exclude, char) end
	raycastParams.FilterDescendantsInstances = exclude

	local origin    = Camera.CFrame.Position
	local direction = worldPos - origin
	local result    = workspace:Raycast(origin, direction, raycastParams)

	-- Si le rayon touche quelque chose, le label est occulté
	return result ~= nil
end

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LABEL_W      = 120
local LABEL_H      = 44
local OFFSET_Y     = 4   -- studs au-dessus du pivot du modèle
local MAX_DISTANCE = 60  -- studs : au-delà, le label est masqué

local RARITY_COLORS = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(30,  200, 30),
	Rare      = Color3.fromRGB(0,   120, 255),
	Epic      = Color3.fromRGB(160, 0,   200),
	Legendary = Color3.fromRGB(255, 200, 0),
}

-- ScreenGui dédiée (ne se réinitialise pas au respawn)
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "GeneratorLabels"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder   = 5
screenGui.Parent         = playerGui

-- Table : instance → { frame, anchorPart }
local _labels = {}

local function getAnchorPart(instance)
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

local function createLabel(instance)
	if _labels[instance] then return end

	local rarity  = instance:GetAttribute("BrainrotRarity")
	local revenue = instance:GetAttribute("BrainrotRevenue")
	if not rarity or not revenue then return end

	local anchor = getAnchorPart(instance)
	if not anchor then return end

	local frame = Instance.new("Frame")
	frame.Size                   = UDim2.new(0, LABEL_W, 0, LABEL_H)
	frame.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel        = 0
	frame.Visible                = false
	frame.Parent                 = screenGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

	local rarityLbl = Instance.new("TextLabel")
	rarityLbl.Size                   = UDim2.new(1, -8, 0.5, 0)
	rarityLbl.Position               = UDim2.new(0, 4, 0, 2)
	rarityLbl.BackgroundTransparency = 1
	rarityLbl.Text                   = rarity
	rarityLbl.TextColor3             = RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
	rarityLbl.Font                   = Enum.Font.GothamBold
	rarityLbl.TextScaled             = true
	rarityLbl.Parent                 = frame

	local revenueLbl = Instance.new("TextLabel")
	revenueLbl.Size                   = UDim2.new(1, -8, 0.5, -4)
	revenueLbl.Position               = UDim2.new(0, 4, 0.5, 0)
	revenueLbl.BackgroundTransparency = 1
	revenueLbl.Text                   = "$" .. tostring(revenue) .. "/s"
	revenueLbl.TextColor3             = Color3.fromRGB(220, 220, 220)
	revenueLbl.Font                   = Enum.Font.Gotham
	revenueLbl.TextScaled             = true
	revenueLbl.Parent                 = frame

	_labels[instance] = { frame = frame, anchor = anchor }
end

local function removeLabel(instance)
	local data = _labels[instance]
	if data then
		data.frame:Destroy()
		_labels[instance] = nil
	end
end

-- Surveille récursivement un conteneur pour détecter les modèles tagués
local function watchDescendants(root)
	for _, desc in ipairs(root:GetDescendants()) do
		if desc:GetAttribute("BrainrotRarity") then
			createLabel(desc)
		end
	end

	root.DescendantAdded:Connect(function(desc)
		task.defer(function()  -- laisser les attributs se propager
			if desc:GetAttribute("BrainrotRarity") then
				createLabel(desc)
			end
		end)
	end)

	root.DescendantRemoving:Connect(function(desc)
		removeLabel(desc)
	end)
end

watchDescendants(workspace)

-- Mise à jour de la position chaque frame
RunService.RenderStepped:Connect(function()
	local char = player.Character
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")

	for instance, data in pairs(_labels) do
		local anchor = data.anchor
		local frame  = data.frame

		-- Vérifier que l'anchor existe encore
		if not anchor or not anchor.Parent then
			removeLabel(instance)
			continue
		end

		local worldPos = anchor.Position + Vector3.new(0, OFFSET_Y, 0)

		-- Masquer si trop loin
		if rootPart then
			local dist = (rootPart.Position - anchor.Position).Magnitude
			if dist > MAX_DISTANCE then
				frame.Visible = false
				continue
			end
		end

		local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
		if not onScreen or isOccluded(anchor, worldPos) then
			frame.Visible = false
			continue
		end

		frame.Position = UDim2.new(0, screenPos.X - LABEL_W / 2, 0, screenPos.Y - LABEL_H)
		frame.Visible  = true
	end
end)
