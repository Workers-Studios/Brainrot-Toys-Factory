local ConveyorService = {}

local RunService = game:GetService("RunService")
local PlotService = require(script.Parent.Parent.Core.PlotService)

local _segments = {}
local _heartbeats = {}
local _CollectionService = nil

local CONVEYOR_SPEED = 10
local EXPAND_BONUS = 4.5

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

		local direction = (segment.CFrame * CFrame.Angles(0, math.rad(270), 0)).LookVector
		local segNum = tonumber(segment.Name:match("%d+")) or 0
		local expand = (segNum == 8) and 0 or EXPAND_BONUS

		table.insert(_segments[userId], {
			Part = segment,
			Direction = direction,
			Expand = expand,
			Num = segNum,
		})
		count += 1

		segment.CanCollide = true
	end

	-- Trier en ordre DESCENDANT : les segments bas écrasent les hauts
	-- Un toy sur le 7 ET dans la zone du 8 → le 7 gagne (priorité)
	table.sort(_segments[userId], function(a, b)
		return a.Num > b.Num
	end)

	-- CollectionZone
	local collection = plot:FindFirstChild("Collection")
	if collection then
		local collectionZone = collection:FindFirstChild("CollectionZone")
		if collectionZone then
			collectionZone.Touched:Connect(function(hit)
				if hit:IsA("BasePart") and (hit.Name:match("^TralaleroTralala") or hit.Name:match("^BrrBrrPatapim")) then
					if hit:GetAttribute("OwnerId") == userId then
						hit.AssemblyLinearVelocity = Vector3.zero
						_CollectionService.OnToyCollected(hit)
					end
				end
			end)
		end
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	_heartbeats[userId] = RunService.Heartbeat:Connect(function()
		local segs = _segments[userId]
		if not segs then return end

		for _, waypoint in ipairs(segs) do
			if not waypoint.Part.Parent then continue end

			local seg = waypoint.Part
			local expand = waypoint.Expand
			local expandedSize = Vector3.new(
				seg.Size.X + expand,
				seg.Size.Y + 1,
				seg.Size.Z + expand
			)

			overlapParams.FilterDescendantsInstances = {seg}
			local parts = workspace:GetPartBoundsInBox(seg.CFrame, expandedSize, overlapParams)

			for _, part in ipairs(parts) do
				if not part:IsA("BasePart") then continue end
				if not (part.Name:match("^TralaleroTralala") or part.Name:match("^BrrBrrPatapim")) then continue end
				if part:GetAttribute("OwnerId") ~= userId then continue end

				local dir = waypoint.Direction
				part.AssemblyLinearVelocity = Vector3.new(
					dir.X * CONVEYOR_SPEED,
					part.AssemblyLinearVelocity.Y,
					dir.Z * CONVEYOR_SPEED
				)
			end
		end
	end)

	print("Initialized", count, "conveyor segments for plot", userId)
end

function ConveyorService.StopConveyors(userId)
	if _heartbeats[userId] then
		_heartbeats[userId]:Disconnect()
		_heartbeats[userId] = nil
	end
	_segments[userId] = nil
end

return ConveyorService
