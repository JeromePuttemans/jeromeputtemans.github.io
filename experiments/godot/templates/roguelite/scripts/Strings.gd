extends Node

# Strings (Autoload): English / French UI texts with {placeholder} substitution.
# The language starts from the OS locale (French if "fr", English otherwise)
# and can be switched at runtime; every UI refreshes on language_changed.

signal language_changed(lang: String)

var lang: String = "en"

const TEXTS: Dictionary = {
	"en": {
		"title": "Roguelite Puzzle 3D",
		"intro": "Explore the cube maze, take the energy core, bring it back to the teleporter.\nEach move costs 1 energy. Unknown rooms appear as you enter them.",
		"start": "Start  (Enter)",
		"level": "Level {value}",
		"energy": "Energy",
		"fragments": "Fragments: {value}",
		"bomb": "Bomb: {value} energy",
		"best": "Best level: {value}",
		"goal_core": "Goal: take the energy core ({dist} rooms away)",
		"goal_back": "Goal: back to the teleporter ({dist} rooms away)",
		"msg_resource": "Energy crystal: +{energy} energy, +{frag} fragment",
		"msg_trap": "Trap: -{value} energy",
		"msg_core": "Energy core taken. Back to the teleporter.",
		"msg_bomb": "Boom: the walls around you are gone (-{value} energy)",
		"msg_no_bomb": "Not enough energy for a bomb ({value} needed)",
		"msg_wall": "A wall blocks this way",
		"msg_level": "Level {value} cleared: +{frag} fragments, energy refilled",
		"over_energy": "Out of energy",
		"over_trapped": "Walled in, without energy for a bomb",
		"over_stats": "Level {level}   ·   Rooms explored {rooms}   ·   Fragments this run {frag}",
		"shop_title": "UPGRADES (fragments kept between runs)",
		"up_energy": "Reserve: max energy +{value}",
		"up_bomb": "Detonator: bomb cost -1",
		"up_prospect": "Prospector: crystals +3%",
		"up_level": "level {value}/{max}",
		"up_buy": "Buy  {cost}",
		"up_maxed": "Maxed",
		"restart": "New run  (Enter)",
		"controls": "Move: {front}/{back}/{left}/{right} or arrows   Up/down: {up}/{down} or PgUp/PgDn   Bomb: Space",
		"lang_button": "EN"
	},
	"fr": {
		"title": "Roguelite Puzzle 3D",
		"intro": "Explorez le dédale de cubes, prenez le noyau d'énergie, rapportez-le au téléporteur.\nChaque déplacement coûte 1 énergie. Les salles inconnues apparaissent quand vous y entrez.",
		"start": "Commencer  (Entrée)",
		"level": "Niveau {value}",
		"energy": "Énergie",
		"fragments": "Fragments : {value}",
		"bomb": "Bombe : {value} énergie",
		"best": "Meilleur niveau : {value}",
		"goal_core": "Objectif : prendre le noyau d'énergie (à {dist} salles)",
		"goal_back": "Objectif : revenir au téléporteur (à {dist} salles)",
		"msg_resource": "Cristal d'énergie : +{energy} énergie, +{frag} fragment",
		"msg_trap": "Piège : -{value} énergie",
		"msg_core": "Noyau d'énergie récupéré. Retour au téléporteur.",
		"msg_bomb": "Boum : les murs autour de vous ont disparu (-{value} énergie)",
		"msg_no_bomb": "Pas assez d'énergie pour une bombe (il en faut {value})",
		"msg_wall": "Un mur bloque ce passage",
		"msg_level": "Niveau {value} terminé : +{frag} fragments, énergie rechargée",
		"over_energy": "Plus d'énergie",
		"over_trapped": "Emmuré, sans assez d'énergie pour une bombe",
		"over_stats": "Niveau {level}   ·   Salles explorées {rooms}   ·   Fragments de la partie {frag}",
		"shop_title": "AMÉLIORATIONS (les fragments sont conservés d'une partie à l'autre)",
		"up_energy": "Réserve : énergie max +{value}",
		"up_bomb": "Détonateur : coût de la bombe -1",
		"up_prospect": "Prospecteur : cristaux +3 %",
		"up_level": "niveau {value}/{max}",
		"up_buy": "Acheter  {cost}",
		"up_maxed": "Maximum",
		"restart": "Nouvelle partie  (Entrée)",
		"controls": "Déplacer : {front}/{back}/{left}/{right} ou flèches   Monter/descendre : {up}/{down} ou PgPréc/PgSuiv   Bombe : Espace",
		"lang_button": "FR"
	}
}

func _ready() -> void:
	lang = "fr" if OS.get_locale_language() == "fr" else "en"

func t(key: String, params: Dictionary = {}) -> String:
	var table: Dictionary = TEXTS.get(lang, TEXTS["en"]) as Dictionary
	var s: String = str(table.get(key, (TEXTS["en"] as Dictionary).get(key, "[%s]" % key)))
	for k in params:
		s = s.replace("{%s}" % k, str(params[k]))
	return s

func toggle() -> void:
	lang = "en" if lang == "fr" else "fr"
	language_changed.emit(lang)
