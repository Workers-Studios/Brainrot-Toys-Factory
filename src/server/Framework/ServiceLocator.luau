--[[
	Registre centralisé des services serveur
	Permet à n'importe quel service d'accéder à un autre sans que tout
	soit câblé manuellement via les paramètres d'Init().

	Usage :
	  -- Dans ServerInit (enregistrement)
	  ServiceLocator.Register("MoneyService", MoneyService)

	  -- Dans n'importe quel service (récupération)
	  local MoneyService = ServiceLocator.Get("MoneyService")

	Règle : Register() doit être appelé AVANT Get() pour un service donné.
	Tous les Register() ont lieu dans ServerInit avant que les joueurs rejoignent,
	donc il n'y a jamais de course.
]]

local ServiceLocator = {}

local _registry: {[string]: table} = {}

-- Enregistre un service sous un nom
-- Erreur si le nom est déjà pris (signale un doublon accidentel)
function ServiceLocator.Register(name: string, service: table)
	if _registry[name] then
		warn("[ServiceLocator] Service déjà enregistré :", name)
	end
	_registry[name] = service
end

-- Retourne un service enregistré — erreur hard si introuvable
-- (un Get() raté est un bug de programmation, pas un cas runtime)
function ServiceLocator.Get(name: string): table
	local service = _registry[name]
	if not service then
		error("[ServiceLocator] Service introuvable : " .. name, 2)
	end
	return service
end

-- Retourne un service ou nil — pour les cas où la présence est optionnelle
function ServiceLocator.TryGet(name: string): table?
	return _registry[name]
end

return ServiceLocator
