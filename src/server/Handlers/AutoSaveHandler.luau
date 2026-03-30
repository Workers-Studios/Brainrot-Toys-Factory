--[[
	Handler de sauvegarde automatique
	Sauvegarde périodiquement les données de tous les joueurs connectés

	Complète les saves event-driven avec un filet de sécurité backup.
	Intervalle configuré dans GameConfig.AutoSaveInterval (défaut : 300s = 5min)
]]

local AutoSaveHandler = {}

local _PlayerDataService = nil
local _autoSaveInterval  = 300  -- valeur par défaut, écrasée par Init()

-- Initialise le handler
-- @param PlayerDataService : service - gestion des données joueur
-- @param gameConfig        : table   - GameConfig (contient AutoSaveInterval)
function AutoSaveHandler.Init(PlayerDataService, gameConfig)
	_PlayerDataService  = PlayerDataService
	_autoSaveInterval   = gameConfig.AutoSaveInterval
	print("AutoSaveHandler initialized (intervalle :", _autoSaveInterval, "secondes)")
end

-- Démarre la boucle de sauvegarde automatique
function AutoSaveHandler.StartAutoSave()
	task.spawn(function()
		while true do
			task.wait(_autoSaveInterval)

			local playersSaved = 0

			for _, player in ipairs(game.Players:GetPlayers()) do
				local userId = player.UserId
				local ok, err = pcall(function()
					_PlayerDataService.SavePlayer(userId)
				end)
				if ok then
					playersSaved += 1
				else
					warn("AutoSave échoué pour", player.Name, ":", err)
				end
			end

			if playersSaved > 0 then
				print("AutoSave :", playersSaved, "joueur(s) sauvegardé(s)")
			end
		end
	end)
end

return AutoSaveHandler
