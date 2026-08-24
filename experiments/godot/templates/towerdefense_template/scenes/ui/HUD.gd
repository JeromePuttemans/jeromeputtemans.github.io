# =============================================================================
# HUD.gd — CanvasLayer UI: shop, wave button, stats bar, sell panel.
# =============================================================================
# Layout (all via Container nodes, no hardcoded positions):
#   TopBar    — gold, lives, score, wave, lang button
#   RightPanel — shop cards + sell panel + feedback label
#   BottomBar — controls hint + start wave / wave timer
#
# The HUD communicates with Main.gd only through method calls:
#   Main.select_tower_type(id), Main.sell_tower(tower, cell)
# =============================================================================

extends MarginContainer

# Top bar
@onready var gold_label:  Label  = $VBoxOuter/TopBar/GoldLabel
@onready var lives_label: Label  = $VBoxOuter/TopBar/LivesLabel
@onready var score_label: Label  = $VBoxOuter/TopBar/ScoreLabel
@onready var wave_label:  Label  = $VBoxOuter/TopBar/WaveLabel
@onready var lang_btn:    Button = $VBoxOuter/TopBar/LangButton

# Right panel
@onready var shop_vbox:     VBoxContainer = $VBoxOuter/ContentRow/RightPanel/ShopVBox
@onready var sell_panel:    VBoxContainer = $VBoxOuter/ContentRow/RightPanel/SellPanel
@onready var sell_name_lbl: Label         = $VBoxOuter/ContentRow/RightPanel/SellPanel/NameLabel
@onready var sell_btn:      Button        = $VBoxOuter/ContentRow/RightPanel/SellPanel/SellButton
@onready var feedback_lbl:  Label         = $VBoxOuter/ContentRow/RightPanel/FeedbackLabel

# Bottom bar
@onready var controls_lbl:  Label  = $VBoxOuter/BottomBar/ControlsLabel
@onready var wave_btn:      Button = $VBoxOuter/BottomBar/WaveButton
@onready var wave_timer_lbl: Label = $VBoxOuter/BottomBar/WaveTimerLabel

var _feedback_timer:  float = 0.0
const FEEDBACK_DUR    = 2.5

# Sell context
var _sell_tower: Tower    = null
var _sell_cell:  Vector2i = Vector2i(-1, -1)

# Shop button references to manage selection highlight
var _shop_buttons: Dictionary = {}   # type_id -> Button

# Wave auto-start countdown
var _between_timer: float = 0.0
var _counting_down: bool  = false

func _ready() -> void:
	GameState.gold_changed.connect(_on_gold)
	GameState.lives_changed.connect(_on_lives)
	GameState.score_changed.connect(_on_score)
	GameState.phase_changed.connect(_on_phase)
	StringManager.language_changed.connect(_on_language)
	lang_btn.pressed.connect(_on_lang_pressed)
	wave_btn.pressed.connect(_on_wave_btn_pressed)
	sell_panel.visible = false
	_build_shop()
	_refresh()

func _process(delta: float) -> void:
	# Feedback label auto-hide
	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0:
			feedback_lbl.visible = false

	# Auto-start countdown between waves
	if _counting_down:
		_between_timer -= delta
		if _between_timer <= 0.0:
			_counting_down = false
			wave_timer_lbl.visible = false
			GameState.begin_wave()
		else:
			wave_timer_lbl.text = StringManager.t("waiting_label",
				{sec = int(ceil(_between_timer))})

# ---------------------------------------------------------------------------
# Shop
# ---------------------------------------------------------------------------

func _build_shop() -> void:
	# free() not queue_free() — immediate removal before add_child
	for c in shop_vbox.get_children():
		c.free()
	_shop_buttons.clear()

	for data in TowerDatabase.get_all():
		var id      = data.get("id", "")
		var cost    = data.get("cost", 0)
		var dmg     = data.get("damage", 0)
		var rng     = int(data.get("range", 0))
		var rate    = data.get("fire_rate", 0.0)
		var splash  = data.get("splash", false)
		var color   = Color("#" + data.get("color", "ffffff"))

		# Card container
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", _make_card_style(color))
		shop_vbox.add_child(card)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		card.add_child(vbox)

		# Name + cost button (top row)
		var btn = Button.new()
		btn.text = "%s  —  $%d" % [data.get("display_name", id), cost]
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(func(): _on_shop_btn(id))
		vbox.add_child(btn)
		_shop_buttons[id] = btn

		# Stats row
		var stats_lbl = Label.new()
		var splash_tag = "  💥" if splash else ""
		stats_lbl.text = "⚔ %d   🎯 %d px   ⚡ %.1f/s%s" % [dmg, rng, rate, splash_tag]
		stats_lbl.add_theme_font_size_override("font_size", 11)
		stats_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stats_lbl)

func _make_card_style(tint: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color            = tint.darkened(0.6)
	s.border_color        = tint.lightened(0.1)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(4)
	return s

func _on_shop_btn(type_id: String) -> void:
	if GameState.phase != GameState.Phase.BUILD:
		return
	for id in _shop_buttons:
		_shop_buttons[id].button_pressed = (id == type_id)
	var main = get_node_or_null("/root/Main")
	if main:
		main.select_tower_type(type_id)

func clear_shop_selection() -> void:
	for id in _shop_buttons:
		_shop_buttons[id].button_pressed = false

# ---------------------------------------------------------------------------
# Sell panel
# ---------------------------------------------------------------------------

func show_sell_panel(tower: Tower, cell: Vector2i) -> void:
	_sell_tower = tower
	_sell_cell  = cell
	var data    = TowerDatabase.get_type(tower.tower_id)

	# Name
	sell_name_lbl.text = data.get("display_name", tower.tower_id)

	# Stats label (reuse or create)
	var stats_lbl = sell_panel.get_node_or_null("StatsLabel")
	if stats_lbl == null:
		stats_lbl      = Label.new()
		stats_lbl.name = "StatsLabel"
		stats_lbl.add_theme_font_size_override("font_size", 11)
		stats_lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
		stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Insert before sell button
		sell_panel.add_child(stats_lbl)
		sell_panel.move_child(stats_lbl, sell_panel.get_child_count() - 2)

	var splash = data.get("splash", false)
	var type_tag = " (splash)" if splash else ""
	stats_lbl.text = (
		"⚔  DMG  %d%s
" % [data.get("damage", 0), type_tag] +
		"🎯  Range  %d px
" % int(data.get("range", 0)) +
		"⚡  Rate  %.1f/s
" % float(data.get("fire_rate", 0)) +
		"💰  Cost  $%d" % data.get("cost", 0)
	)

	sell_btn.text = StringManager.t("sell_button", {value = tower.sell_value})
	sell_panel.visible = true
	if sell_btn.pressed.is_connected(_on_sell_pressed):
		sell_btn.pressed.disconnect(_on_sell_pressed)
	sell_btn.pressed.connect(_on_sell_pressed)

func hide_sell_panel() -> void:
	sell_panel.visible = false
	_sell_tower = null
	_sell_cell  = Vector2i(-1, -1)

func _on_sell_pressed() -> void:
	if _sell_tower == null:
		return
	var main = get_node_or_null("/root/Main")
	if main:
		main.sell_tower(_sell_tower, _sell_cell)

# ---------------------------------------------------------------------------
# Feedback
# ---------------------------------------------------------------------------

func show_feedback(msg: String) -> void:
	feedback_lbl.text    = msg
	feedback_lbl.visible = true
	_feedback_timer      = FEEDBACK_DUR

# ---------------------------------------------------------------------------
# Signals from GameState
# ---------------------------------------------------------------------------

func _on_gold(v: int) -> void:
	gold_label.text = StringManager.t("gold_label", {value = v})

func _on_lives(v: int) -> void:
	lives_label.text = StringManager.t("lives_label", {value = v})

func _on_score(v: int) -> void:
	score_label.text = StringManager.t("score_label", {value = v})

func _on_phase(p: GameState.Phase) -> void:
	var is_build = (p == GameState.Phase.BUILD)
	wave_btn.visible = is_build
	for id in _shop_buttons:
		_shop_buttons[id].disabled = not is_build

	if p == GameState.Phase.BUILD and GameState.wave_index > 0:
		# Start countdown to next wave
		_between_timer         = ConfigManager.get_float("wave_between_delay", 0.0)
		_counting_down         = true
		wave_timer_lbl.visible = true
	else:
		wave_timer_lbl.visible = false

	_update_wave_label()

func _update_wave_label() -> void:
	wave_label.text = StringManager.t("wave_label", {
		current = GameState.wave_index + 1,
		total   = GameState.total_waves
	})

# ---------------------------------------------------------------------------
# Wave button
# ---------------------------------------------------------------------------

func _on_wave_btn_pressed() -> void:
	_counting_down         = false
	wave_timer_lbl.visible = false
	GameState.begin_wave()

# ---------------------------------------------------------------------------
# Language
# ---------------------------------------------------------------------------

func _on_lang_pressed() -> void:
	var langs = ["en", "fr"]
	var idx   = langs.find(StringManager.get_language())
	StringManager.set_language(langs[(idx + 1) % langs.size()])

func _on_language(_lang: String) -> void:
	_refresh()
	_build_shop()

func _refresh() -> void:
	lang_btn.text      = StringManager.t("lang_button")
	controls_lbl.text  = StringManager.t("controls")
	wave_btn.text      = StringManager.t("start_wave_button")
	_on_gold(GameState.gold)
	_on_lives(GameState.lives)
	_on_score(GameState.score)
	_update_wave_label()

# ---------------------------------------------------------------------------
# Called by Main to communicate grid dimensions (for layout awareness)
# ---------------------------------------------------------------------------

func set_grid_size(_gw: int, _gh: int) -> void:
	pass   # Could adjust right panel width in future
