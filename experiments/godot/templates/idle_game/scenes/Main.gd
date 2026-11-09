# =============================================================================
# Main.gd — Builds the interface and turns game events into feedback
# =============================================================================
# Layout (1280 x 720, stretched):
#   left column   shard counter, the crystal and its orbits, prisms panel
#   right column  language / sound / save / reset buttons, upgrade shop,
#                 producer list
#   overlays      floating numbers and sparkles, meteor, notices, tooltip,
#                 modal window
# Main holds no game rule: it listens to the managers' signals and answers
# with sound, particles, notices and windows. Space strikes the crystal.
# =============================================================================

extends Node

const LEFT_WIDTH: float = 440.0
const HINT_CLICKS: int = 12
const BUY_STREAK_TIME: float = 0.6

var _root: Control
var _crystal: Control
var _resource: VBoxContainer
var _producers: VBoxContainer
var _shop: VBoxContainer
var _tooltip: PanelContainer
var _fx: Control
var _toasts: VBoxContainer
var _popup: Control
var _prestige: PanelContainer
var _hint: Label
var _title: Label
var _top_buttons: Dictionary = {}
var _meteor: Control = null
var _buy_streak: int = 0
var _buy_streak_left: float = 0.0

func _ready() -> void:
	_build()
	_connect_game_signals()
	_refresh_texts()
	StringManager.language_changed.connect(func(_l: String) -> void: _refresh_texts())
	_show_offline_report.call_deferred()

# =============================================================================
# BUILDING
# =============================================================================

func _build() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.theme = UiTheme.build()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_full(_make(Control.new(), "res://scenes/ui/Background.gd"))
	_build_left_column()
	_build_right_column()
	_fx = _add_full(_make(Control.new(), "res://scenes/ui/FxLayer.gd"))
	_toasts = _make(VBoxContainer.new(), "res://scenes/ui/Toasts.gd") as VBoxContainer
	_root.add_child(_toasts)
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toasts.offset_left = LEFT_WIDTH + 16.0   # centred on the right column
	_toasts.offset_right = -16.0
	_toasts.offset_top = -170.0
	_toasts.offset_bottom = -18.0
	_tooltip = _make(PanelContainer.new(), "res://scenes/ui/Tooltip.gd") as PanelContainer
	_root.add_child(_tooltip)
	_shop.set("tooltip", _tooltip)
	_popup = _add_full(_make(Control.new(), "res://scenes/ui/Popup.gd"))

func _build_left_column() -> void:
	_title = UiTheme.label("", 13, UiTheme.MUTED)
	_title.position = Vector2(0.0, 12.0)
	_title.size = Vector2(LEFT_WIDTH, 20.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_title)
	_resource = _make(VBoxContainer.new(), "res://scenes/ui/ResourceDisplay.gd") as VBoxContainer
	_root.add_child(_resource)
	_resource.position = Vector2(0.0, 34.0)
	_resource.size = Vector2(LEFT_WIDTH, 130.0)
	_crystal = _make(Control.new(), "res://scenes/ui/CrystalView.gd")
	_root.add_child(_crystal)
	_crystal.position = Vector2(0.0, 165.0)
	_crystal.size = Vector2(LEFT_WIDTH, 430.0)
	_hint = UiTheme.label("", 14, UiTheme.CRYSTAL)
	_hint.position = Vector2(0.0, 572.0)
	_hint.size = Vector2(LEFT_WIDTH, 20.0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)
	_prestige = _make(PanelContainer.new(), "res://scenes/ui/PrestigePanel.gd") as PanelContainer
	_root.add_child(_prestige)
	_prestige.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_prestige.offset_left = 18.0
	_prestige.offset_right = LEFT_WIDTH - 18.0
	_prestige.offset_top = -112.0
	_prestige.offset_bottom = -14.0

func _build_right_column() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_root.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = LEFT_WIDTH + 16.0
	column.offset_right = -16.0
	column.offset_top = 12.0
	column.offset_bottom = -12.0
	column.add_child(_build_top_bar())
	_shop = _make(VBoxContainer.new(), "res://scenes/ui/UpgradeShop.gd") as VBoxContainer
	column.add_child(_shop)
	_producers = _make(VBoxContainer.new(), "res://scenes/ui/ProducerList.gd") as VBoxContainer
	_producers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_producers)

func _build_top_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.alignment = BoxContainer.ALIGNMENT_END
	for key in ["language", "sound", "save", "reset"]:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0.0, 32.0)
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_on_top_button.bind(key))
		bar.add_child(button)
		_top_buttons[key] = button
	return bar

func _make(node: Node, script_path: String) -> Node:
	node.set_script(load(script_path))
	return node

func _add_full(control: Control) -> Control:
	_root.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control

# =============================================================================
# SIGNALS
# =============================================================================

func _connect_game_signals() -> void:
	_crystal.connect("struck", _on_struck)
	_producers.connect("producer_bought", _on_producer_bought)
	_shop.connect("upgrade_bought", _on_upgrade_bought)
	_prestige.connect("prestige_requested", _on_prestige_requested)
	ProducerManager.milestone_reached.connect(_on_milestone_reached)
	BoostManager.frenzy_started.connect(_on_frenzy_started)
	BoostManager.frenzy_ended.connect(func() -> void: Sfx.play("frenzy_end"))
	BoostManager.meteor_spawned.connect(_on_meteor_spawned)
	BoostManager.meteor_expired.connect(_on_meteor_expired)
	PrestigeManager.prestige_done.connect(_on_prestige_done)

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE and not _popup.call("is_open"):
		_crystal.call("strike", _crystal.call("center"))
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_buy_streak_left -= delta
	if _buy_streak_left <= 0.0:
		_buy_streak = 0
	var clicks: int = int(GameManager.stats.get("clicks", 0))
	_hint.modulate.a = clampf(1.0 - float(clicks) / HINT_CLICKS, 0.0, 1.0) * (0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.004))

func _on_struck(at: Vector2, amount: float, critical: bool) -> void:
	var text: String = "+" + Utils.format_number(amount)
	if critical:
		_fx.call("float_text", at, text, UiTheme.GOLD, 30)
		_fx.call("burst", at, UiTheme.GOLD, 18, 260.0)
		_resource.call("pulse")
	else:
		_fx.call("float_text", at, text, UiTheme.TEXT, 20)

func _on_producer_bought(producer: Producer, amount: int, at: Vector2) -> void:
	_buy_streak = mini(_buy_streak + 1, 12)
	_buy_streak_left = BUY_STREAK_TIME
	Sfx.play("buy", pow(1.06, _buy_streak), 0.0, 0.0)
	_crystal.call("spawn_orbiter", producer)
	_fx.call("burst", at, producer.color, 10 + mini(amount, 20), 180.0)
	_fx.call("float_text", at + Vector2(0.0, -30.0), "+%d" % amount, producer.color, 18)

func _on_upgrade_bought(upgrade: Upgrade, at: Vector2) -> void:
	Sfx.play("upgrade")
	_fx.call("burst", at, UiTheme.GOLD, 24, 220.0)
	_toasts.call("push", StringManager.t("toast_upgrade", {name = _tooltip.call("upgrade_name", upgrade)}), UiTheme.GOLD)

func _on_milestone_reached(producer: Producer, milestone: int) -> void:
	Sfx.play("milestone")
	var card: Control = _producers.call("card_for", producer.id) as Control
	if is_instance_valid(card):
		card.call("flash")
		_fx.call("burst", card.get_global_rect().get_center(), producer.color, 30, 280.0)
	_toasts.call("push", StringManager.t("toast_milestone", {value = milestone, producer = StringManager.producer_name(producer.id),
		mult = int(ConfigManager.get_float("milestone_multiplier", 2.0))}), producer.color.lightened(0.2))

func _on_frenzy_started(duration: float) -> void:
	Sfx.play("frenzy_start")
	_fx.call("flash", UiTheme.HEAT, 0.6)
	_toasts.call("push", StringManager.t("toast_frenzy", {value = int(ConfigManager.get_float("frenzy_multiplier", 2.0)), seconds = int(duration)}), UiTheme.HEAT)

func _on_meteor_spawned(kind: String, lifetime: float) -> void:
	if is_instance_valid(_meteor):
		_meteor.queue_free()
	_meteor = _make(Control.new(), "res://scenes/ui/Meteor.gd") as Control
	_root.add_child(_meteor)
	_root.move_child(_meteor, _toasts.get_index())
	_meteor.call("setup", kind, lifetime, _root.size)
	_meteor.connect("caught", _on_meteor_caught)
	Sfx.play("meteor")

func _on_meteor_expired() -> void:
	if is_instance_valid(_meteor):
		_meteor.call("fade_out")
	_meteor = null

func _on_meteor_caught(at: Vector2, kind: String, amount: float) -> void:
	_meteor = null
	Sfx.play("meteor_catch")
	var color: Color = UiTheme.CRYSTAL if kind == "rain" else UiTheme.HEAT
	_fx.call("burst", at, color, 40, 320.0)
	if kind == "rain":
		_fx.call("float_text", at, "+" + Utils.format_number(amount), color, 34)
		_resource.call("pulse")
		_toasts.call("push", StringManager.t("toast_rain", {value = Utils.format_number(amount)}), color)
	else:
		_toasts.call("push", StringManager.t("toast_eruption", {value = int(ConfigManager.get_float("meteor_eruption_multiplier", 5.0)),
			seconds = int(ConfigManager.get_float("meteor_eruption_duration", 15.0))}), color)

# =============================================================================
# CRYSTALLIZATION, TOP BAR, WINDOWS
# =============================================================================

func _on_prestige_requested() -> void:
	var gain: int = PrestigeManager.pending_gain()
	if gain < 1:
		return
	var body: String = StringManager.t("prestige_body", {gain = _prestige.call("prism_text", gain),
		total = _prestige.call("prism_text", PrestigeManager.prisms + gain),
		bonus = Utils.format_percent((PrestigeManager.prisms + gain) * ConfigManager.get_float("prestige_bonus_per_prism", 0.1))})
	var buttons: Array[Dictionary] = [
		{text = StringManager.t("cancel")},
		{text = StringManager.t("prestige_confirm"), accent = true, action = func() -> void: PrestigeManager.prestige()}]
	_popup.call("open", StringManager.t("prestige_title"), body, buttons)

func _on_prestige_done(gained: int, _total: int) -> void:
	Sfx.play("prestige")
	_fx.call("flash", UiTheme.PRISM, 1.0)
	_fx.call("burst", _crystal.get_global_rect().get_center(), UiTheme.PRISM, 60, 380.0)
	_toasts.call("push", StringManager.t("toast_prestige", {value = _prestige.call("prism_text", gained)}), UiTheme.PRISM)
	_prestige.call("refresh")

func _on_top_button(key: String) -> void:
	Sfx.play("ui")
	match key:
		"language":
			StringManager.cycle_language()
		"sound":
			Sfx.toggle_mute()
			_refresh_texts()
		"save":
			SaveManager.save_game()
			_toasts.call("push", StringManager.t("toast_saved"), UiTheme.TEXT)
		"reset":
			var buttons: Array[Dictionary] = [
				{text = StringManager.t("cancel")},
				{text = StringManager.t("reset_confirm"), accent = true, action = _hard_reset}]
			_popup.call("open", StringManager.t("reset_title"), StringManager.t("reset_body"), buttons)

func _hard_reset() -> void:
	GameManager.hard_reset()
	_producers.call("refresh_all")
	_shop.call("rebuild")
	_prestige.call("refresh")

func _show_offline_report() -> void:
	var report: Dictionary = GameManager.offline_report
	if report.is_empty():
		return
	var body: String = StringManager.t("offline_body", {time = Utils.format_duration(float(report["seconds"])),
		value = Utils.format_number(float(report["amount"])),
		factor = Utils.format_percent(ConfigManager.get_float("offline_factor", 0.5))})
	if bool(report.get("capped", false)):
		body += "\n" + StringManager.t("offline_capped", {hours = int(ConfigManager.get_float("offline_cap_hours", 8.0))})
	var collect := func() -> void:
		Sfx.play("collect")
		_resource.call("pulse")
		_fx.call("burst", _resource.get_global_rect().get_center(), UiTheme.CRYSTAL, 40, 300.0)
	var buttons: Array[Dictionary] = [{text = StringManager.t("collect"), accent = true, action = collect}]
	_popup.call("open", StringManager.t("offline_title"), body, buttons)

func _refresh_texts() -> void:
	_title.text = StringManager.t("title")
	_hint.text = StringManager.t("hint_strike")
	(_top_buttons["language"] as Button).text = StringManager.t("lang_button")
	(_top_buttons["sound"] as Button).text = StringManager.t("sound_off" if Sfx.muted else "sound_on")
	(_top_buttons["save"] as Button).text = StringManager.t("button_save")
	(_top_buttons["reset"] as Button).text = StringManager.t("button_reset")
	_prestige.call("refresh")
