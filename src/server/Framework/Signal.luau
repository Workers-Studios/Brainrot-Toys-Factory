--[[
	Bus d'événements serveur — communication découplée entre services
	Permet à un service de réagir aux événements d'un autre sans référence directe.

	Avantage scalabilité : ajouter un nouveau système qui réagit à un événement
	existant = 1 ligne Signal.Connect(), zéro modification du service émetteur.

	Usage :
	  -- Émettre (dans CollectionService par ex.)
	  Signal.Fire("QuotaComplete", player, rarity)

	  -- Écouter (dans PlacementService par ex.)
	  Signal.Connect("QuotaComplete", function(player, rarity)
	      PlacementService.GiveEggTool(player, rarity)
	  end)

	Chaque callback est exécuté dans un task.spawn() séparé :
	  - Les erreurs d'un listener n'affectent pas les autres
	  - Pas de blocage sur les listeners lents
]]

local Signal = {}

local _listeners: {[string]: {(...any) -> ()}} = {}

-- Abonne un callback à un événement nommé
-- Retourne une fonction de désabonnement
function Signal.Connect(event: string, callback: (...any) -> ()): () -> ()
	if not _listeners[event] then
		_listeners[event] = {}
	end
	table.insert(_listeners[event], callback)

	-- Retourne un disconnect()
	return function()
		local handlers = _listeners[event]
		if not handlers then return end
		for i, cb in ipairs(handlers) do
			if cb == callback then
				table.remove(handlers, i)
				break
			end
		end
	end
end

-- Émet un événement — tous les listeners sont appelés en parallèle
function Signal.Fire(event: string, ...: any)
	local handlers = _listeners[event]
	if not handlers or #handlers == 0 then return end

	local args = { ... }
	for _, callback in ipairs(handlers) do
		task.spawn(callback, table.unpack(args))
	end
end

-- Abonne un callback qui ne se déclenche qu'une seule fois
function Signal.Once(event: string, callback: (...any) -> ())
	local disconnect
	disconnect = Signal.Connect(event, function(...)
		disconnect()
		callback(...)
	end)
end

return Signal
