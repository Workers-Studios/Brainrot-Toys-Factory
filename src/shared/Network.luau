--[[
	Constantes réseau partagées client/serveur
	Centralise tous les noms de RemoteEvents et RemoteFunctions

	Avantage : une seule source de vérité — renommer une remote ne nécessite
	qu'une modification ici, jamais dans les services individuels.

	Usage (serveur) : require(game:GetService("ReplicatedStorage").Shared.Network)
	Usage (client)  : require(game:GetService("ReplicatedStorage").Shared.Network)
]]

local Network = {}

-- RemoteEvents (serveur → client)
Network.Events = {
	OnMoneyChanged            = "OnMoneyChanged",
	OnQuotaUpdated            = "OnQuotaUpdated",
	OnNotification            = "OnNotification",
	OnEggsUpdated             = "OnEggsUpdated",
	OnRevenuePerSecondChanged = "OnRevenuePerSecondChanged",
}

-- RemoteFunctions (client → serveur, réponse attendue)
Network.Functions = {
	PurchaseSpawner   = "PurchaseSpawner",
	PlaceSpawner      = "PlaceSpawner",
	RequestPlayerData = "RequestPlayerData",
}

-- Dossier admin séparé dans RemoteInterface
Network.Admin = {
	IsAdmin        = "IsAdmin",       -- RemoteFunction
	ExecuteCommand = "ExecuteCommand", -- RemoteEvent
}

return Network
