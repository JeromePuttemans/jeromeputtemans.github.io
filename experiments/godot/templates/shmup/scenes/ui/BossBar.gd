# =============================================================================
# BossBar.gd — Boss name, health of the current phase, phases left, timer
# =============================================================================
# Drawn at the top of the field while a boss is present. One pip per phase
# still to break; the timer turns red under 10 s (the phase is then lost
# without its bonus).
# =============================================================================

class_name BossBar
extends Control

var game: Game = null
var _font: Font = null
var _shown: float = 0.0
var _hp_shown: float = 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

func _process(delta: float) -> void:
	var boss: Enemy = game.boss if game != null else null
	var target: float = 1.0 if boss != null and boss.entered else 0.0
	_shown = move_toward(_shown, target, delta * 4.0)
	if boss != null:
		_hp_shown = lerpf(_hp_shown, clampf(boss.hp / boss.max_hp, 0.0, 1.0), minf(delta * 10.0, 1.0))
	queue_redraw()

func _draw() -> void:
	if _shown <= 0.0 or game.boss == null:
		return
	var boss: Enemy = game.boss
	var a: float = _shown
	var w: float = size.x - 24.0
	var y: float = 14.0 - (1.0 - a) * 30.0
	var title: String = StringManager.t(str(boss.data.get("name", "")))
	draw_string_outline(_font, Vector2(12.0, y + 12.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.8 * a))
	draw_string(_font, Vector2(12.0, y + 12.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.75, 0.85, a))
	var left: int = boss.phase_count() - boss.phase_index - 1
	for i in left:
		draw_circle(Vector2(20.0 + _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + i * 14.0, y + 7.0), 4.5, Color(1.0, 0.4, 0.6, a))
	var seconds: int = int(ceil(maxf(boss.phase_time, 0.0)))
	var timer: String = StringManager.t("boss_time", {s = seconds})
	var tw: float = _font.get_string_size(timer, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var timer_color: Color = Color(1.0, 0.35, 0.35, a) if seconds <= 10 else Color(0.85, 0.9, 1.0, a)
	draw_string_outline(_font, Vector2(12.0 + w - tw, y + 12.0), timer, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.8 * a))
	draw_string(_font, Vector2(12.0 + w - tw, y + 12.0), timer, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, timer_color)
	draw_rect(Rect2(12.0, y + 20.0, w, 8.0), Color(0.1, 0.05, 0.12, 0.8 * a))
	var color: Color = Color(1.0, 0.3, 0.5).lerp(Color(1.0, 0.85, 0.3), 1.0 - _hp_shown)
	draw_rect(Rect2(12.0, y + 20.0, w * _hp_shown, 8.0), Color(color, a))
	draw_rect(Rect2(12.0, y + 20.0, w * _hp_shown, 2.0), Color(1.0, 1.0, 1.0, 0.5 * a))
	if boss.invulnerable > 0.0:
		draw_rect(Rect2(12.0, y + 20.0, w, 8.0), Color(1.0, 1.0, 1.0, 0.2 * a), false, 1.0)
