extends Node

# Strings (Autoload): English / French UI texts with {placeholder} substitution.
# The language starts from the OS locale (French if "fr", English otherwise)
# and can be switched at runtime; every UI refreshes on language_changed.

signal language_changed(lang: String)

var lang: String = "en"

const TEXTS: Dictionary = {
	"en": {
		"title": "Roguelite Puzzle 3D",
		"intro": "Explore the cube maze, take the energy core, bring it back to the teleporter.\nEach move costs 1 energy. Unknown rooms appear as you enter them.\nEvery core brought back lets you choose a permanent upgrade.",
		"start": "Start  (Enter)",
		"level": "Level {value}",
		"energy": "Energy",
		"crystals": "Crystals: {value}% of new rooms",
		"bomb": "Bomb: {value} energy",
		"best": "Best level: {value}",
		"goal_core": "Goal: take the energy core ({dist} rooms away)",
		"goal_back": "Goal: back to the teleporter ({dist} rooms away)",
		"msg_resource": "Energy crystal: +{energy} energy",
		"msg_trap": "Trap: -{value} energy",
		"msg_core": "Energy core taken. Back to the teleporter.",
		"msg_bomb": "Boom: the walls around you are gone (-{value} energy)",
		"msg_no_bomb": "Not enough energy for a bomb ({value} needed)",
		"msg_wall": "A wall blocks this way",
		"msg_level": "Level {value} cleared, energy refilled",
		"msg_upgrade": "{name}: level {value}/{max}",
		"msg_all_maxed": "Every upgrade is maxed: on to the next level",
		"over_energy": "Out of energy",
		"over_trapped": "Walled in, without energy for a bomb",
		"over_stats": "Level {level}   ·   Rooms explored {rooms}",
		"over_kept": "Your upgrades are kept: {list}",
		"choice_title": "LEVEL {value} CLEARED",
		"choice_text": "Choose one upgrade. It works by itself, with nothing to activate, and you keep it in every next run.",
		"up_energy_name": "Reserve",
		"up_energy_desc": "More energy at the start of each level.",
		"up_energy_effect": "Max energy: {now} → {next}",
		"up_bomb_name": "Detonator",
		"up_bomb_desc": "The bomb costs less energy.",
		"up_bomb_effect": "Bomb cost: {now} → {next} energy",
		"up_prospect_name": "Prospector",
		"up_prospect_desc": "New rooms hold an energy crystal (+5 energy) more often.",
		"up_prospect_effect": "Rooms with a crystal: {now}% → {next}%",
		"up_level": "Level {value}/{max}",
		"up_choose": "Choose  ({key})",
		"up_maxed": "Maxed",
		"restart": "New run  (Enter)",
		"controls": "Move: {front}/{back}/{left}/{right} or arrows   Up/down: {up}/{down} or PgUp/PgDn   Bomb: Space",
		"opt_radius": "Near radius",
		"radius_value": "{value} rooms",
		"radius_value_one": "1 room",
		"opt_far": "Distant rooms",
		"opt_keyboard": "Keyboard",
		"kb_auto": "Automatic ({value})",
		"kb_auto_other": "Automatic",
		"camera_hint": "Camera: drag the mouse to orbit, wheel to zoom, R to reset",
		"lang_button": "EN"
	},
	"fr": {
		"title": "Roguelite Puzzle 3D",
		"intro": "Explorez le dédale de cubes, prenez le noyau d'énergie, rapportez-le au téléporteur.\nChaque déplacement coûte 1 énergie. Les salles inconnues apparaissent quand vous y entrez.\nChaque noyau rapporté vous fait choisir une amélioration permanente.",
		"start": "Commencer  (Entrée)",
		"level": "Niveau {value}",
		"energy": "Énergie",
		"crystals": "Cristaux : {value} % des nouvelles salles",
		"bomb": "Bombe : {value} énergie",
		"best": "Meilleur niveau : {value}",
		"goal_core": "Objectif : prendre le noyau d'énergie (à {dist} salles)",
		"goal_back": "Objectif : revenir au téléporteur (à {dist} salles)",
		"msg_resource": "Cristal d'énergie : +{energy} énergie",
		"msg_trap": "Piège : -{value} énergie",
		"msg_core": "Noyau d'énergie récupéré. Retour au téléporteur.",
		"msg_bomb": "Boum : les murs autour de vous ont disparu (-{value} énergie)",
		"msg_no_bomb": "Pas assez d'énergie pour une bombe (il en faut {value})",
		"msg_wall": "Un mur bloque ce passage",
		"msg_level": "Niveau {value} terminé, énergie rechargée",
		"msg_upgrade": "{name} : niveau {value}/{max}",
		"msg_all_maxed": "Toutes les améliorations sont au maximum : niveau suivant",
		"over_energy": "Plus d'énergie",
		"over_trapped": "Emmuré, sans assez d'énergie pour une bombe",
		"over_stats": "Niveau {level}   ·   Salles explorées {rooms}",
		"over_kept": "Vos améliorations sont conservées : {list}",
		"choice_title": "NIVEAU {value} TERMINÉ",
		"choice_text": "Choisissez une amélioration. Elle agit toute seule, sans rien à activer, et reste acquise pour toutes les parties suivantes.",
		"up_energy_name": "Réserve",
		"up_energy_desc": "Plus d'énergie au début de chaque niveau.",
		"up_energy_effect": "Énergie maximale : {now} → {next}",
		"up_bomb_name": "Détonateur",
		"up_bomb_desc": "La bombe coûte moins d'énergie.",
		"up_bomb_effect": "Coût de la bombe : {now} → {next} énergie",
		"up_prospect_name": "Prospecteur",
		"up_prospect_desc": "Les nouvelles salles contiennent plus souvent un cristal d'énergie (+5 énergie).",
		"up_prospect_effect": "Salles avec cristal : {now} % → {next} %",
		"up_level": "Niveau {value}/{max}",
		"up_choose": "Choisir  ({key})",
		"up_maxed": "Maximum atteint",
		"restart": "Nouvelle partie  (Entrée)",
		"controls": "Déplacer : {front}/{back}/{left}/{right} ou flèches   Monter/descendre : {up}/{down} ou PgPréc/PgSuiv   Bombe : Espace",
		"opt_radius": "Rayon de proximité",
		"radius_value": "{value} salles",
		"radius_value_one": "1 salle",
		"opt_far": "Salles éloignées",
		"opt_keyboard": "Clavier",
		"kb_auto": "Automatique ({value})",
		"kb_auto_other": "Automatique",
		"camera_hint": "Caméra : faites glisser la souris pour tourner, molette pour zoomer, R pour recentrer",
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
