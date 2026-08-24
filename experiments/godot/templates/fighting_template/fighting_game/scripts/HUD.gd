# HUD.gd
# Heads-Up Display: health bars, timer, round counter, combo, announcements.
#
# PATTERN: Pure View — receives data via signal callbacks, never reads game state directly.
# WHY: Decouples rendering from logic. HUD can be redesigned without touching game systems.

class_name HUD
extends CanvasLayer

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var health_bar_p1: ProgressBar  = $MarginContainer/HBoxContainer/HealthBarP1
@onready var health_bar_p2: ProgressBar  = $MarginContainer/HBoxContainer/HealthBarP2
@onready var timer_label: Label          = $TimerLabel
@onready var round_label: Label          = $RoundLabel
@onready var announcement_label: Label   = $AnnouncementLabel
@onready var combo_label_p1: Label       = $ComboLabelP1
@onready var combo_label_p2: Label       = $ComboLabelP2
@onready var win_icons_p1: HBoxContainer = $WinIconsP1
@onready var win_icons_p2: HBoxContainer = $WinIconsP2

# Health bar lerp targets — avoids jitter from instant updates
var _health_target_p1: float = 1.0
var _health_target_p2: float = 1.0
var _lerp_speed: float = 0.0

# Announce display timer
var _announce_timer: float = 0.0
const ANNOUNCE_DURATION := 1.5

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_lerp_speed = SettingsManager.get_value("ui.health_bar_lerp_speed", 4.0)
	announcement_label.visible = false
	combo_label_p1.visible = false
	combo_label_p2.visible = false

func _process(delta: float) -> void:
	# Smooth health bars
	health_bar_p1.value = lerpf(health_bar_p1.value, _health_target_p1 * 100.0, _lerp_speed * delta)
	health_bar_p2.value = lerpf(health_bar_p2.value, _health_target_p2 * 100.0, _lerp_speed * delta)

	# Auto-hide announcement
	if _announce_timer > 0.0:
		_announce_timer -= delta
		if _announce_timer <= 0.0:
			announcement_label.visible = false

# ── Signal handlers (called by Arena) ────────────────────────────────────────

func _on_p1_health_changed(new_health: float, max_health: float) -> void:
	if max_health > 0.0:
		_health_target_p1 = new_health / max_health

func _on_p2_health_changed(new_health: float, max_health: float) -> void:
	if max_health > 0.0:
		_health_target_p2 = new_health / max_health

func _on_round_started(round_number: int) -> void:
	round_label.text = tr("ROUND") + " " + str(round_number)

func _on_timer_updated(seconds_left: int) -> void:
	timer_label.text = str(seconds_left)
	# Flash timer when low
	if seconds_left <= 10:
		timer_label.modulate = Color.RED
	else:
		timer_label.modulate = Color.WHITE

func _on_countdown_tick(value: int) -> void:
	if value <= 0:
		_show_announcement(tr("FIGHT"), Color.YELLOW, 1.2)
	else:
		_show_announcement(str(value), Color.WHITE, 0.8)

func _on_round_ended(winner_index: int) -> void:
	if winner_index < 0:
		_show_announcement(tr("DRAW"), Color.WHITE, 2.0)
	else:
		_show_announcement(tr("KO"), Color.RED, 2.0)
		_add_win_icon(winner_index)

func _on_match_ended(winner_index: int) -> void:
	var txt := ""
	if winner_index < 0:
		txt = tr("DRAW")
	else:
		var name_key := "PLAYER_1" if winner_index == 0 else "PLAYER_2"
		txt = tr(name_key) + "\n" + tr("WIN")
	_show_announcement(txt, Color.GOLD, 99.0)

func _on_combo_updated(player_index: int, count: int) -> void:
	var combo_label := combo_label_p1 if player_index == 0 else combo_label_p2
	if count >= 2:
		combo_label.visible = true
		combo_label.text = str(count) + "x " + tr("COMBO")
		# Scale punch — game feel
		combo_label.scale = Vector2(1.3, 1.3)
		var tween := create_tween()
		tween.tween_property(combo_label, "scale", Vector2.ONE, 0.15)
	else:
		combo_label.visible = false

# ── Helpers ───────────────────────────────────────────────────────────────────

func _show_announcement(text: String, color: Color, duration: float) -> void:
	announcement_label.text = text
	announcement_label.modulate = color
	announcement_label.visible = true
	_announce_timer = duration

	# Squash/stretch entrance animation
	announcement_label.scale = Vector2(0.5, 0.5)
	var tween := create_tween()
	tween.tween_property(announcement_label, "scale", Vector2(1.1, 1.1), 0.12)
	tween.tween_property(announcement_label, "scale", Vector2.ONE, 0.08)

func _add_win_icon(player_index: int) -> void:
	var container := win_icons_p1 if player_index == 0 else win_icons_p2
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.color = Color.GOLD
	container.add_child(icon)
