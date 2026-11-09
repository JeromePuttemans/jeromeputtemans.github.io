extends Control

# Screens: title, pause and game over overlays, built by game_manager.gd
# under Transitions (processed even while the game is paused).
#
#   TITLE      name, one-line promise, the three rules (current and void,
#              drag from bullets in flight, purge), controls with the letters
#              of the player's keyboard, best score, language switch (L).
#   PAUSED     dimmed screen, how to resume.
#   GAME_OVER  cause (destroyed / swallowed by the void), score, best or new
#              best, run statistics, how to play again.
# The "press" lines blink. Texts come from datas/strings_*.json through
# game_manager.t() and tf().

const COLOR_TEXT: Color = Color(0.91, 0.91, 1.0)
const COLOR_MUTED: Color = Color(0.6, 0.62, 0.78)
const COLOR_GOLD: Color = Color(1.0, 0.8, 0.0)
const COLOR_DANGER: Color = Color(1.0, 0.267, 0.333)
const COLOR_CYAN: Color = Color(0.45, 0.9, 1.0)

var _manager: Node = null
var _title: Control
var _pause: Control
var _game_over: Control
var _labels: Dictionary = {}   # name -> Label
var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = _build_title()
	_pause = _build_pause()
	_game_over = _build_game_over()

## Called by game_manager.gd after add_child().
func bind(manager: Node) -> void:
	_manager = manager
	manager.game_state_changed.connect(_on_game_state_changed)
	manager.language_changed.connect(refresh_texts)
	refresh_texts()
	_on_game_state_changed(int(manager.get("current_state")))

func _process(delta: float) -> void:
	_time += delta
	var blink: float = 0.55 + 0.45 * sin(_time * 4.0)
	(_labels["press_start"] as Label).modulate.a = blink
	(_labels["restart"] as Label).modulate.a = blink

func _on_game_state_changed(state: int) -> void:
	_title.visible = state == 0
	_pause.visible = state == 2
	_game_over.visible = state == 3
	refresh_texts()

func refresh_texts() -> void:
	if not is_instance_valid(_manager):
		return
	_set_text("title", "PARALLAX")
	for key in ["tagline", "rule_current", "rule_drag", "rule_purge", "press_start", "language_hint", "restart", "resume"]:
		_set_text(key, _t(key))
	_set_text("pause", _t("pause"))
	_set_text("controls", str(_manager.call("tf", "controls", {move = InputManager.move_keys_label()})))
	var best: int = int(_manager.get("best_score"))
	_set_text("best", "%s  %s" % [_t("best"), _format_score(best)] if best > 0 else "")
	_refresh_result()

func _refresh_result() -> void:
	var result: Dictionary = _manager.get("last_result") as Dictionary
	if result.is_empty():
		return
	_set_text("over_title", _t("game_over_void") if result.get("cause", "") == "void" else _t("game_over"))
	_set_text("over_score", _format_score(int(result.get("score", 0))))
	var best_line: String = _t("new_best") if bool(result.get("new_best", false)) else "%s  %s" % [_t("best"), _format_score(int(result.get("best", 0)))]
	_set_text("over_best", best_line)
	(_labels["over_best"] as Label).add_theme_color_override("font_color", COLOR_GOLD if bool(result.get("new_best", false)) else COLOR_MUTED)
	_set_text("over_stats", str(_manager.call("tf", "stats", {
		time = _manager.call("format_time", float(result.get("time", 0.0))),
		sector = int(result.get("sector", 1)), kills = int(result.get("kills", 0)),
		accuracy = int(result.get("accuracy", 0)), chain = int(result.get("max_chain", 1))})))

# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

func _build_title() -> Control:
	var screen: Control = _overlay(Color(0.0, 0.0, 0.03, 0.45))
	var box: VBoxContainer = _column(screen, 10)
	_add_label(box, "title", 92, COLOR_TEXT)
	(_labels["title"] as Label).add_theme_color_override("font_outline_color", Color(COLOR_CYAN, 0.35))
	(_labels["title"] as Label).add_theme_constant_override("outline_size", 18)
	_add_label(box, "tagline", 24, COLOR_GOLD)
	box.add_child(_spacer(18.0))
	_add_label(box, "rule_current", 17, COLOR_TEXT)
	_add_label(box, "rule_drag", 17, COLOR_TEXT)
	_add_label(box, "rule_purge", 17, COLOR_TEXT)
	box.add_child(_spacer(14.0))
	_add_label(box, "controls", 14, COLOR_MUTED)
	box.add_child(_spacer(22.0))
	_add_label(box, "press_start", 26, COLOR_CYAN)
	_add_label(box, "best", 17, COLOR_GOLD)
	var language: Label = _make_label("language_hint", 14, COLOR_MUTED)
	language.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	language.offset_left = -220.0
	language.offset_top = -40.0
	language.offset_right = -20.0
	language.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	screen.add_child(language)
	return screen

func _build_pause() -> Control:
	var screen: Control = _overlay(Color(0.0, 0.0, 0.03, 0.65))
	var box: VBoxContainer = _column(screen, 14)
	_add_label(box, "pause", 60, COLOR_TEXT)
	_add_label(box, "resume", 20, COLOR_MUTED)
	return screen

func _build_game_over() -> Control:
	var screen: Control = _overlay(Color(0.0, 0.0, 0.03, 0.72))
	var box: VBoxContainer = _column(screen, 12)
	_add_label(box, "over_title", 56, COLOR_DANGER)
	_add_label(box, "over_score", 48, COLOR_TEXT)
	_add_label(box, "over_best", 22, COLOR_GOLD)
	box.add_child(_spacer(10.0))
	_add_label(box, "over_stats", 16, COLOR_TEXT)
	box.add_child(_spacer(20.0))
	_add_label(box, "restart", 20, COLOR_CYAN)
	return screen

func _overlay(color: Color) -> Control:
	var screen := ColorRect.new()
	screen.color = color
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.visible = false
	add_child(screen)
	return screen

func _column(parent: Control, separation: int) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	center.add_child(box)
	return box

func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

func _add_label(box: VBoxContainer, key: String, font_size: int, color: Color) -> void:
	var label: Label = _make_label(key, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

func _make_label(key: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("outline_size", 5)
	_labels[key] = label
	return label

func _set_text(key: String, text: String) -> void:
	if _labels.has(key):
		(_labels[key] as Label).text = text

func _t(key: String) -> String:
	return str(_manager.call("t", key))

func _format_score(score: int) -> String:
	return str(_manager.call("format_score", score))
