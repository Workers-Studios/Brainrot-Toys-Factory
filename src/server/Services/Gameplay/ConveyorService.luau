local ConveyorService = {}

local TweenService = game:GetService("TweenService")
local PlotService = require(script.Parent.Parent.Core.PlotService)

local _segments = {}
local _CollectionService = nil

function ConveyorService.Init()
	_CollectionService = require(script.Parent.CollectionService)
	print("ConveyorService initialized")
end

function ConveyorService.InitializePlotConveyors(userId)
	local plot = PlotService.GetPlot(userId)
	if not plot then
		warn("No plot found for userId:", userId)
		return
	end

	local conveyorsFolder = plot:FindFirstChild("Conveyors")
	if not conveyorsFolder then
		warn("Conveyors not found in plot for userId:", userId)
		return
	end

	_segments[userId] = {}
	local count = 0

	for _, segment in ipairs(conveyorsFolder:GetDescendants()) do
		if not segment:IsA("BasePart") or not segment.Name:match("Segment") then
			continue
		end

		_segments[userId][segment.Name] = segment
		count += 1

		-- Configure segment
		segment.CanCollide = true
		segment.Material = Enum.Material.Metal
		segment.Color = Color3.fromRGB(70, 70, 70)

		-- Texture animée
		local texture = Instance.new("Texture")
		texture.Name = "ConveyorTexture"
		texture.Texture = "rbxasset://textures/SpawnLocation.png"
		texture.Face = Enum.NormalId.Top
		texture.StudsPerTileU = 2
		texture.StudsPerTileV = 2
		texture.Parent = segment

		task.spawn(function()
			local offset = 0
			while segment.Parent do
				offset += 0.15
				if texture and texture.Parent then
					texture.OffsetStudsV = offset
				else
					break
				end
				task.wait(0.05)
			end
		end)

		-- ⭐ Physique: Pousser les toys
		segment.Touched:Connect(function(hit)
			if hit:IsA("BasePart") and (hit.Name:match("^TralaleroTralala") or hit.Name:match("^BrrBrrPatapim")) then
				local ownerId = hit:GetAttribute("OwnerId")
				if ownerId ~= userId then
					return
				end

				if not hit:FindFirstChild("ConveyorVelocity") then
					local attachment = Instance.new("Attachment")
					attachment.Name = "ConveyorAttachment"
					attachment.Parent = hit

					local linearVelocity = Instance.new("LinearVelocity")
					linearVelocity.Name = "ConveyorVelocity"
					linearVelocity.Attachment0 = attachment
					linearVelocity.VectorVelocity = segment.CFrame.LookVector * 8
					linearVelocity.MaxForce = 4000
					linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
					linearVelocity.Parent = hit
				end
			end
		end)

		-- Retirer vélocité quand quitte segment
		segment.TouchEnded:Connect(function(hit)
			if hit:IsA("BasePart") then
				local velocity = hit:FindFirstChild("ConveyorVelocity")
				if velocity then
					velocity:Destroy()
				end
				local attachment = hit:FindFirstChild("ConveyorAttachment")
				if attachment then
					attachment:Destroy()
				end
			end
		end)
	end

	-- ⭐ Setup CollectionZone
	local collection = plot:FindFirstChild("Collection")
	if collection then
		local collectionZone = collection:FindFirstChild("CollectionZone")
		if collectionZone then
			collectionZone.Touched:Connect(function(hit)
				if hit:IsA("BasePart") and (hit.Name:match("^TralaleroTralala") or hit.Name:match("^BrrBrrPatapim")) then
					local ownerId = hit:GetAttribute("OwnerId")
					if ownerId == userId then
						local velocity = hit:FindFirstChild("ConveyorVelocity")
						if velocity then
							velocity:Destroy()
						end
						_CollectionService.OnToyCollected(hit)
					end
				end
			end)
		end
	end

	print("Initialized", count, "conveyor segments for plot", userId)
end

return ConveyorService
