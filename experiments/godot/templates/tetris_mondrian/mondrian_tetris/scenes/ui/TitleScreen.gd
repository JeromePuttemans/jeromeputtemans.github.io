# =============================================================================
# TitleScreen.gd — A composition that paints itself, and the menu
# =============================================================================
# The background is a new Mondrian-like composition every ten seconds: the
# screen is cut in two again and again (longer side first, at a random
# point between 30 and 70 %), and the rectangles appear one after the other,
# a few of them in red, yellow, blue or black. The menu sits in a white
# panel in front of it.
# =============================================================================

class_name TitleScreen
extends Control

signal play_requested()
signal gallery_requested()

var _leaves: Array[Dictionary] = []   # rect, color, delay
var _time: float = 0.0
var _period: float = 10.0
var _buttons: Array[Button] = []
var _title: Label = null
var _subtitle: Label = null
var _tagline: Label = null
var _best: Label = null
var _rules: Label = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	var style := UiTheme.box(Pieces.PALETTE[Pieces.Col.WHITE])
	style.set_border_width_all(12)
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", style)
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	_title = UiTheme.label("", 74)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_subtitle = UiTheme.label("", 26, Pieces.PALETTE[Pieces.Col.RED])
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)
	_tagline = UiTheme.label("", 17, Color(Pieces.LINE, 0.7))
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)
	var actions: Array[Callable] = [
		func() -> void: play_requested.emit(),
		func() -> void: gallery_requested.emit(),
		func() -> void:
			StringManager.cycle_language()
			refresh(),
		func() -> void:
			Sfx.set_muted(not Sfx.muted)
			refresh(),
		func() -> void:
			Sfx.set_music(not Sfx.music_on)
			refresh(),
	]
	for a in actions:
		var b := UiTheme.button("", a, 340.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(b)
		_buttons.append(b)
	_best = UiTheme.label("", 19)
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_best)
	_rules = UiTheme.label("", 16, Color(Pieces.LINE, 0.75))
	_rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules.custom_minimum_size = Vector2(460, 0)
	column.add_child(_rules)
	StringManager.language_changed.connect(func(_l: String) -> void: refresh())
	_compose()
	refresh()

func open() -> void:
	visible = true
	refresh()
	_buttons[0].grab_focus()

func refresh() -> void:
	_title.text = StringManager.t("title")
	_subtitle.text = StringManager.t("subtitle")
	_tagline.text = StringManager.t("tagline")
	_buttons[0].text = StringManager.t("menu_play")
	_buttons[1].text = StringManager.t("menu_gallery")
	_buttons[2].text = StringManager.t("menu_language")
	_buttons[3].text = StringManager.t("menu_sound", {v = StringManager.t("off" if Sfx.muted else "on")})
	_buttons[4].text = StringManager.t("menu_music", {v = StringManager.t("on" if Sfx.music_on else "off")})
	_best.text = StringManager.t("title_best", {n = Frame.group(SaveManager.best_score())})
	_best.visible = SaveManager.best_score() > 0
	_rules.text = StringManager.t("title_rules")

## Cuts the screen into rectangles and gives each a colour and a delay.
func _compose() -> void:
	_leaves.clear()
	var stack: Array = [[Rect2(0, 0, 1280, 720), 0]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var r: Rect2 = item[0]
		var depth: int = item[1]
		var can_split: bool = (r.size.x > 230.0 or r.size.y > 230.0) and depth < 6
		if can_split and (depth < 2 or randf() > 0.22):
			var horizontal_cut: bool = r.size.y > r.size.x if absf(r.size.x - r.size.y) > 80.0 else randf() < 0.5
			var k: float = randf_range(0.3, 0.7)
			if horizontal_cut:
				var h: float = round(r.size.y * k)
				stack.append([Rect2(r.position, Vector2(r.size.x, h)), depth + 1])
				stack.append([Rect2(r.position + Vector2(0, h), Vector2(r.size.x, r.size.y - h)), depth + 1])
			else:
				var w: float = round(r.size.x * k)
				stack.append([Rect2(r.position, Vector2(w, r.size.y)), depth + 1])
				stack.append([Rect2(r.position + Vector2(w, 0), Vector2(r.size.x - w, r.size.y)), depth + 1])
		else:
			var roll: float = randf()
			var c: int = Pieces.Col.WHITE
			if roll < 0.13:
				c = Pieces.Col.RED
			elif roll < 0.25:
				c = Pieces.Col.YELLOW
			elif roll < 0.36:
				c = Pieces.Col.BLUE
			elif roll < 0.41:
				c = Pieces.Col.BLACK
			_leaves.append({rect = r, color = c, delay = randf_range(0.0, 1.6)})
	_time = 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _time > _period:
		_compose()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Pieces.LINE)
	for leaf in _leaves:
		var k: float = clampf((_time - float(leaf["delay"])) / 0.35, 0.0, 1.0)
		var out: float = clampf((_period - _time) / 0.5, 0.0, 1.0)
		k = minf(ease(k, 0.4), out)
		if k <= 0.0:
			continue
		var r: Rect2 = (leaf["rect"] as Rect2).grow(-6.0)
		var c: Vector2 = r.get_center()
		var shown := Rect2(c - r.size * 0.5 * k, r.size * k)
		draw_rect(shown, Pieces.PALETTE[int(leaf["color"])] if int(leaf["color"]) != Pieces.Col.WHITE else Pieces.CANVAS)
