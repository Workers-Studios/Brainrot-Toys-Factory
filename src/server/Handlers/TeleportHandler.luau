--[[
	TeleportHandler - Intra-map teleportation

	Destinations:
	  MyBase    → player's own plot SpawnLocation (via PlotService)
	  Sell      → nearest Sell_1 / Sell_2 Part in Workspace/TeleportPoints
	  PvE       → Workspace/TeleportPoints/PvE
	  SocialHub → Workspace/TeleportPoints/SocialHub
	  Fishing   → Workspace/TeleportPoints/Fishing
	  Sacrifice → Workspace/TeleportPoints/Sacrifice

	The character is PivotTo'd 5 studs above the destination CFrame.
	VFX is handled client-side — this script only moves the character.
]]

local TeleportHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotService       = require(script.Parent.Parent.Services.Core.PlotService)

local VALID = { MyBase=true, Sell=true, PvE=true, SocialHub=true, Fishing=true, Sacrifice=true }
local OFFSET = Vector3.new(0, 5, 0)

-- Returns the target CFrame for a given player + destination, or nil if not found
local function resolveDestination(player, destination)
	-- ── My Base : SpawnLocation inside the player's own plot ──────────────────
	if destination == "MyBase" then
		local plot = PlotService.GetPlot(player.UserId)
		if not plot then
			warn("[TeleportHandler] Plot not found for", player.Name)
			return nil
		end
		local spawn = plot:FindFirstChild("SpawnLocation", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame * CFrame.new(OFFSET)
		end
		-- Fallback: plot pivot
		return plot:GetPivot() * CFrame.new(OFFSET)

	-- ── Sell : nearest Sell_* Part ────────────────────────────────────────────
	elseif destination == "Sell" then
		local character = player.Character
		if not character or not character.PrimaryPart then return nil end
		local playerPos = character.PrimaryPart.Position

		local teleportPoints = workspace:FindFirstChild("TeleportPoints")
		if not teleportPoints then
			warn("[TeleportHandler] TeleportPoints folder not found in Workspace")
			return nil
		end

		local closest, closestDist = nil, math.huge
		for _, part in ipairs(teleportPoints:GetChildren()) do
			if part:IsA("BasePart") and part.Name:sub(1, 4) == "Sell" then
				local dist = (part.Position - playerPos).Magnitude
				if dist < closestDist then
					closest    = part
					closestDist = dist
				end
			end
		end

		if closest then
			return closest.CFrame * CFrame.new(OFFSET)
		end
		warn("[TeleportHandler] No Sell point found in TeleportPoints")
		return nil

	-- ── Fixed points ──────────────────────────────────────────────────────────
	else
		local teleportPoints = workspace:FindFirstChild("TeleportPoints")
		if not teleportPoints then
			warn("[TeleportHandler] TeleportPoints folder not found in Workspace")
			return nil
		end
		local point = teleportPoints:FindFirstChild(destination)
		if point and point:IsA("BasePart") then
			return point.CFrame * CFrame.new(OFFSET)
		end
		warn("[TeleportHandler] Destination Part not found:", destination)
		return nil
	end
end

function TeleportHandler.Init()
	local teleportEvent = ReplicatedStorage
		:WaitForChild("RemoteInterface")
		:WaitForChild("Events")
		:WaitForChild("TeleportRequest")

	teleportEvent.OnServerEvent:Connect(function(player, destination)
		-- Validate
		if type(destination) ~= "string" or not VALID[destination] then
			warn("[TeleportHandler] Invalid destination from", player.Name, ":", tostring(destination))
			return
		end

		local character = player.Character
		if not character or not character.PrimaryPart then return end

		local targetCFrame = resolveDestination(player, destination)
		if not targetCFrame then return end

		character:PivotTo(targetCFrame)
		print(string.format("[TeleportHandler] %s → %s", player.Name, destination))
	end)

	print("TeleportHandler initialized")
end

return TeleportHandler
