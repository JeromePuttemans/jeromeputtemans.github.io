# =============================================================================
# PrestigePanel.gd — Prisms owned and the crystallize button
# =============================================================================
# Shows the prisms owned and their bonus. The button tells how many prisms a
# crystallization would give now; with none to gain, it is disabled and says
# at which lifetime total the next prism comes. Pressing it emits
# prestige_requested: Main opens the confirmation window.
# =============================================================================

extends PanelContainer

signal prestige_requested()

class PrismIcon extends Control:
	var _time: float = 0.0
	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()
	func _draw() -> void:
		UiTheme.draw_gem(self, size * 0.5, 13.0, 3, UiTheme.PRISM, sin(_time) * 0.4)

var _count_label: Label
var _bonus_label: Label
var _button: Button
var _refresh_left: float = 0.0

func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, UiTheme.PRISM.darkened(0.5), 10, 12))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var icon := PrismIcon.new()
	icon.custom_minimum_size = Vector2(30.0, 30.0)
	head.add_child(icon)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	head.add_child(texts)
	_count_label = UiTheme.label("", 17, UiTheme.PRISM)
	_bonus_label = UiTheme.label("", 12, UiTheme.MUTED)
	texts.add_child(_count_label)
	texts.add_child(_bonus_label)
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size = Vector2(0.0, 34.0)
	_button.add_theme_stylebox_override("normal", UiTheme.box(Color(0.25, 0.16, 0.42), UiTheme.PRISM, 8, 8))
	_button.add_theme_stylebox_override("hover", UiTheme.box(Color(0.33, 0.21, 0.55), UiTheme.PRISM.lightened(0.3), 8, 8))
	_button.add_theme_font_size_override("font_size", 14)
	_button.pressed.connect(func() -> void: prestige_requested.emit())
	box.add_child(_button)
	refresh()

func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.25
		refresh()

func refresh() -> void:
	_count_label.text = StringManager.t("prisms_label", {value = PrestigeManager.prisms})
	_bonus_label.text = StringManager.t("prisms_bonus", {value = Utils.format_percent(PrestigeManager.multiplier() - 1.0)})
	var gain: int = PrestigeManager.pending_gain()
	_button.disabled = gain < 1
	if gain >= 1:
		_button.text = StringManager.t("prestige_button", {value = prism_text(gain)})
	else:
		_button.text = StringManager.t("prestige_locked", {value = Utils.format_number(PrestigeManager.next_prism_at())})

func prism_text(count: int) -> String:
	return StringManager.t("prism_one" if count == 1 else "prism_many", {value = count})
