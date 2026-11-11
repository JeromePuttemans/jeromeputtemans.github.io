# =============================================================================
# Announcer.gd — ROUND 1, FIGHT, K.O., PERFECT, winner name
# =============================================================================
# The text slams in from 180 % (K.O. and FIGHT) or slides in (round),
# holds, then fades. K.O. shakes for its first frames.
# =============================================================================

class_name Announcer
extends Control

const STYLES: Dictionary = {
	"round": {color = Color(0.96, 0.92, 0.84), size = 64, time = 1.3},
	"fight": {color = Color(1.0, 0.62, 0.25), size = 96, time = 0.9},
	"ko": {color = Color(1.0, 0.3, 0.25), size = 130, time = 1.8},
	"perfect": {color = Color(1.0, 0.85, 0.35), size = 72, time = 1.6},
	"winner": {color = Color(1.0, 0.82, 0.35), size = 64, time = 2.2},
}

var _text: String = ""
var _style: String = "round"
var _life: float = 0.0
var _max_life: float = 1.0
var _font: Font = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

func show_text(key: String, style: String) -> void:
	if key.begins_with("winner_"):
		var idx: int = int(key.substr(7))
		_text = StringManager.t("wins", {name = GameState.fighter_name(GameState.p1 if idx == 0 else GameState.p2)})
	else:
		_text = StringManager.t(key)
	_style = style if STYLES.has(style) else "round"
	_max_life = float((STYLES[_style] as Dictionary)["time"])
	_life = _max_life

func clear() -> void:
	_life = 0.0

func _process(delta: float) -> void:
	_life = maxf(_life - delta, 0.0)
	queue_redraw()

func _draw() -> void:
	if _life <= 0.0:
		return
	var st: Dictionary = STYLES[_style] as Dictionary
	var t: float = 1.0 - _life / _max_life
	var alpha: float = minf(t / 0.08, 1.0) * minf(_life / 0.3, 1.0)
	var zoom: float = 1.0
	var offset := Vector2.ZERO
	if _style in ["fight", "ko"]:
		zoom = 1.0 + 0.8 * maxf(1.0 - t / 0.12, 0.0)
	if _style == "ko" and t < 0.25:
		offset = Vector2(randf_range(-8.0, 8.0), randf_range(-6.0, 6.0))
	if _style == "round":
		offset.x = (1.0 - minf(t / 0.15, 1.0)) * -200.0
	var fs: int = int(float(st["size"]) * zoom)
	var w: float = _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2((size.x - w) * 0.5, size.y * 0.42 + fs * 0.3) + offset
	draw_rect(Rect2(0.0, size.y * 0.42 - fs * 0.55, size.x, fs * 1.1), Color(0.0, 0.0, 0.0, 0.3 * alpha))
	draw_string_outline(_font, p, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(0.08, 0.04, 0.02, alpha))
	draw_string(_font, p, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(st["color"] as Color, alpha))
