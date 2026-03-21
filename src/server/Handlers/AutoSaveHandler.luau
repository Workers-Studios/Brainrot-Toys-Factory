--[[
	Automatic save handler
	Periodically saves all connected players data
	
	Complements event-based saves with a safety net backup system
	Interval configured in GameConfig.AutoSaveInterval (default: 300s = 5min)
]]

local AutoSaveHandler = {}

local GameConfig = require(game.ServerScriptService.Config.GameConfig)

local _PlayerDataService = nil
local _autoSaveInterval = GameConfig.AutoSaveInterval

-- Initializes auto-save handler
-- @param PlayerDataService: service - Player data management service
-- @param GameConfig: table - Game configuration (for AutoSaveInterval)
function AutoSaveHandler.Init(PlayerDataService, gameConfig)
	_PlayerDataService = PlayerDataService
	_autoSaveInterval = gameConfig.AutoSaveInterval
	print("AutoSaveHandler initialized (interval:", _autoSaveInterval, "seconds)")
end

-- Starts automatic save loop
function AutoSaveHandler.StartAutoSave()
	task.spawn(function()
		while true do
			task.wait(_autoSaveInterval)

			local playersSaved = 0

			-- Save all connected players
			for _, player in ipairs(game.Players:GetPlayers()) do
				local userId = player.UserId

				local success, err = pcall(function()
					_PlayerDataService.SavePlayer(userId)
				end)

				if success then
					playersSaved += 1
				else
					warn("AutoSave failed for", player.Name, ":", err)
				end
			end

			if playersSaved > 0 then
				print("AutoSave:", playersSaved, "players saved")
			end
		end
	end)
end

return AutoSaveHandler