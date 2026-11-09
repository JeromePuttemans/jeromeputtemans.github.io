# =============================================================================
# Hud.gd — Level name, clock, fireflies, golden acorns, falls
# =============================================================================
# Listens to GameState: counters bump when they change. The clock is read
# every frame (it is the only value that changes continuously). A short
# reminder of the keys fades out a few seconds after each level start.
# =============================================================================

class_name Hud
extends Control

var _level_label: Label
var _time_label: Label
var _firefly_label: Label
var _firefly_icon: Icon
var _death_label: Label
var _death_icon: Icon
var _acorn_icons: Array[Icon] = []
var _acorn_row: HBoxContainer
var _keys_label: Label
var _keys_timer: float = 0.0
var _last_fireflies: int = 0
var _last_acorns: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var top := HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(top)
	_level_label = UiTheme.label("", 22, UiTheme.TEXT, 6)
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_level_label)
	var clock_box := HBoxContainer.new()
	clock_box.add_theme_constant_override("separation", 6)
	clock_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_box.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(clock_box)
	clock_box.add_child(Icon.make("clock", 22.0))
	_time_label = UiTheme.label("0:00.00", 22, UiTheme.TEXT, 6)
	_time_label.custom_minimum_size = Vector2(96.0, 0.0)
	clock_box.add_child(_time_label)
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(right)
	_firefly_icon = Icon.make("firefly", 26.0)
	right.add_child(_firefly_icon)
	_firefly_label = UiTheme.label("", 22, UiTheme.TEXT, 6)
	right.add_child(_firefly_label)
	right.add_child(_spacer(14.0))
	_acorn_row = HBoxContainer.new()
	_acorn_row.add_theme_constant_override("separation", 2)
	_acorn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_acorn_row)
	right.add_child(_spacer(14.0))
	_death_icon = Icon.make("fall", 22.0)
	right.add_child(_death_icon)
	_death_label = UiTheme.label("0", 22, UiTheme.TEXT, 6)
	right.add_child(_death_label)
	_keys_label = UiTheme.label("", 15, UiTheme.TEXT, 5)
	_keys_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_keys_label.position = Vector2(18.0, -40.0)
	_keys_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_keys_label)
	GameState.level_started.connect(_on_level_started)
	GameState.pickups_changed.connect(_on_pickups_changed)
	GameState.deaths_changed.connect(_on_deaths_changed)
	StringManager.language_changed.connect(func(_l: String) -> void: _refresh_texts())

func _spacer(width: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 0.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _on_level_started(_index: int) -> void:
	for icon in _acorn_icons:
		icon.queue_free()
	_acorn_icons.clear()
	for i in GameState.current().acorn_total:
		var icon: Icon = Icon.make("acorn", 26.0, false)
		_acorn_row.add_child(icon)
		_acorn_icons.append(icon)
	_last_fireflies = 0
	_last_acorns = 0
	_keys_timer = 7.0
	_refresh_texts()

func _refresh_texts() -> void:
	if GameState.levels.is_empty():
		return
	var data: LevelData = GameState.current()
	_level_label.text = StringManager.t("hud_level", {n = GameState.level_index + 1, name = StringManager.t(data.name_key)})
	_keys_label.text = StringManager.t("hud_keys")
	_on_pickups_changed()

func _on_pickups_changed() -> void:
	var data: LevelData = GameState.current()
	var count: int = GameState.fireflies.size()
	_firefly_label.text = "%d / %d" % [count, data.firefly_total]
	_firefly_label.add_theme_color_override("font_color", UiTheme.GOLD if count == data.firefly_total and count > 0 else UiTheme.TEXT)
	if count > _last_fireflies:
		_firefly_icon.bump()
	_last_fireflies = count
	for i in _acorn_icons.size():
		var has: bool = GameState.acorns.has(i)
		if has and not _acorn_icons[i].filled:
			_acorn_icons[i].bump()
		_acorn_icons[i].filled = has
		_acorn_icons[i].queue_redraw()
	_last_acorns = GameState.acorns.size()

func _on_deaths_changed(count: int) -> void:
	_death_label.text = str(count)
	if count > 0:
		_death_icon.bump()

func _process(delta: float) -> void:
	_time_label.text = GameState.format_time(GameState.time)
	if _keys_timer > 0.0:
		_keys_timer -= delta
	_keys_label.modulate.a = clampf(_keys_timer, 0.0, 1.0)
