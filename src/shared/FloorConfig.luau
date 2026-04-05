--[[
	FloorConfig - Configuration des étages débloquables

	Chaque étage est un clone complet du PlayerPlotTemplate positionné
	au-dessus du plot de base. Le déblocage est automatique lors du
	passage de prestige — aucune condition d'argent ou de brainrot.

	Lecture de l'état débloqué : dérivée du prestigeLevel du joueur.
	Aucune donnée supplémentaire n'est sauvegardée.
]]

return {
	-- Nombre maximum d'étages (hors plot de base)
	MaxFloors = 2,

	-- Conditions de déblocage par numéro d'étage
	Floors = {
		[1] = { RequiredPrestige = 1 },
		[2] = { RequiredPrestige = 2 },
	},

	-- Hauteur totale disponible (Size.Y du PlayerPlotTemplate = espace sol → toit).
	TotalHeight = 76.167,

	-- Pas vertical entre deux pivots consécutifs = TotalHeight / 3 niveaux.
	-- Base pivot Y+0  →  F1 pivot Y+25.389  →  F2 pivot Y+50.778
	-- Les 3 niveaux rentrent exactement dans les 76.167 studs disponibles.
	FloorHeight = 76.167 / 3,  -- ≈ 25.389
}
