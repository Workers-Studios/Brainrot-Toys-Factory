--[[
	Client-side UI handler for quota progression display
	Updates quota progress bars and counters in real-time
	
	Main responsibilities:
	- Listen for quota updates from server via RemoteEvent
	- Update progress bar visuals based on current quota
	- Update counter labels showing progress (e.g., "45/100")
	
	UI structure expected:
	- QuotaUI/QuotaFrame/QuotaLines/
	  - CommonLine (ProgressBar, CounterLabel)
	  - RareLine (ProgressBar, CounterLabel)
	  - EpicLine (ProgressBar, CounterLabel)
	  - LegendaryLine (ProgressBar, CounterLabel)
]]

local QuotaUIHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- Get UI elements
local playerGui = player:WaitForChild("PlayerGui")
local quotaUI = playerGui:WaitForChild("QuotaUI")
local quotaFrame = quotaUI:WaitForChild("QuotaFrame")
local quotaLines = quotaFrame:WaitForChild("QuotaLines")

-- Get RemoteEvent for server updates
local OnQuotaUpdated = ReplicatedStorage:WaitForChild("RemoteInterface"):WaitForChild("Events"):WaitForChild("OnQuotaUpdated")

-- Updates quota display UI elements
-- @param toyType: string - Type of toy (e.g., "TralaleroTralala")
-- @param rarity: string - Toy rarity (Common, Rare, Epic, Legendary)
-- @param currentQuota: number - Current collection count
-- @param maxQuota: number - Required count to complete quota
function QuotaUIHandler.UpdateQuotaDisplay(toyType, rarity, currentQuota, maxQuota)
	-- Build line name from rarity (e.g., "Common" → "CommonLine")
	local lineName = rarity .. "Line"

	-- Find the UI line for this rarity
	local line = quotaLines:FindFirstChild(lineName)
	if not line then
		--warn("Line not found for", rarity)
		return
	end

	-- Update counter label (e.g., "45/100")
	local counterLabel = line:FindFirstChild("CounterLabel")
	if counterLabel then
		counterLabel.Text = currentQuota .. "/" .. maxQuota
	end

	-- Update progress bar width
	local progressBar = line:FindFirstChild("ProgressBar")
	if progressBar then
		-- Calculate percentage (e.g., 45/100 = 0.45)
		local percentage = currentQuota / maxQuota

		-- Update bar size (percentage of width)
		progressBar.Size = UDim2.new(percentage, 0, 1, 0)
	end
end

-- Listen for quota updates from server
OnQuotaUpdated.OnClientEvent:Connect(function(toyType, rarity, currentQuota, maxQuota)
	QuotaUIHandler.UpdateQuotaDisplay(toyType, rarity, currentQuota, maxQuota)
end)