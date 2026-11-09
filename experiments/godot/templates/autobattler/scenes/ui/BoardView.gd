# =============================================================================
# BoardView.gd — The arena, the bench, drag and drop and battle animations
# =============================================================================
# LAYOUT: the arena (cols x 2 rows of CELL pixels: enemy half on top, player
#   half below) and, under it, the bench. Pure view: it reads RoundManager
#   and the battle simulator, and sends player actions back to RoundManager.
# PREP: drag a unit from the bench or the board onto a cell of your half or a
#   bench slot (swap when taken); drop it on the shop to sell it, or
#   right-click it. The enemy lineup of the round is shown, faded, on the top
#   half. Hovering a unit emits unit_hovered for the info panel.
# BATTLE: units are drawn at their simulated position, sliding between cells
#   while they move. Events become feedback: melee lunge, projectiles,
#   floating numbers (white hit, gold critical, violet ability, green heal,
#   light blue shield), hit flash, area rings, stun stars, shield bubble,
#   death burst and fading ghost, screen shake on heavy blows.
# =============================================================================

extends Control

signal unit_hovered(unit: Unit)
signal unit_dropped_outside(unit: Unit, global_point: Vector2)
signal drag_changed(unit: Unit)

const CELL: float = 58.0
const BENCH_GAP: float = 16.0
const LUNGE_TIME: float = 0.18
const FLASH_TIME: float = 0.12

var _cols: int = 7
var _rows: int = 4
var _arena_origin: Vector2 = Vector2.ZERO
var _drag_unit: Unit = null
var _drag_point: Vector2 = Vector2.ZERO
var _hover_unit: Unit = null
var _mouse: Vector2 = Vector2(-1000.0, -1000.0)
var _time: float = 0.0
var _flash: Dictionary = {}     # instance id -> seconds left
var _lunge: Dictionary = {}     # instance id -> {dir, left}
var _texts: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _ghosts: Array[Dictionary] = []
var _trauma: float = 0.0
var _shake: Vector2 = Vector2.ZERO
var _font: Font = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	_cols = ConfigManager.get_int("board_cols", 7)
	_rows = ConfigManager.get_int("board_rows", 4)
	var bench_width: float = ConfigManager.get_int("bench_size", 8) * CELL
	custom_minimum_size = Vector2(maxf(bench_width, _cols * CELL), _rows * 2 * CELL + BENCH_GAP + CELL)
	_arena_origin = Vector2((custom_minimum_size.x - _cols * CELL) * 0.5, 0.0)
	RoundManager.battle_event.connect(_on_battle_event)
	RoundManager.unit_merged.connect(_on_unit_merged)
	RoundManager.phase_changed.connect(func(_p: int) -> void:
		_drag_unit = null
		drag_changed.emit(null))

# =============================================================================
# GEOMETRY
# =============================================================================

func arena_cell_center(cell: Vector2i) -> Vector2:
	return _arena_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL

func bench_center(index: int) -> Vector2:
	return Vector2((index + 0.5) * CELL, _rows * 2 * CELL + BENCH_GAP + CELL * 0.5)

func location_center(location: Dictionary) -> Vector2:
	if location.get("zone", "") == "board":
		var c: Vector2i = location["cell"] as Vector2i
		return arena_cell_center(Vector2i(c.x, c.y + _rows))
	return bench_center(int(location.get("index", 0)))

## Location under a local point: a cell of the player half, a bench slot, or {}.
func location_at(point: Vector2) -> Dictionary:
	var local: Vector2 = (point - _arena_origin) / CELL
	var col: int = int(floor(local.x))
	var row: int = int(floor(local.y))
	if col >= 0 and col < _cols and row >= _rows and row < _rows * 2:
		return {"zone": "board", "cell": Vector2i(col, row - _rows)}
	var bench_top: float = _rows * 2 * CELL + BENCH_GAP
	if point.y >= bench_top and point.y < bench_top + CELL and point.x >= 0.0:
		var index: int = int(point.x / CELL)
		if index < ConfigManager.get_int("bench_size", 8):
			return {"zone": "bench", "index": index}
	return {}

func unit_screen_position(unit: Unit) -> Vector2:
	var from: Vector2 = arena_cell_center(unit.move_from)
	var to: Vector2 = arena_cell_center(unit.cell)
	var pos: Vector2 = from.lerp(to, ease(unit.move_progress(), -1.6))
	if _lunge.has(unit.instance_id):
		var lunge: Dictionary = _lunge[unit.instance_id]
		var t: float = 1.0 - float(lunge["left"]) / LUNGE_TIME
		pos += (lunge["dir"] as Vector2) * sin(t * PI) * CELL * 0.22
	return pos

func token_radius(data: Dictionary) -> float:
	return CELL * (0.46 if bool(data.get("boss", false)) else 0.33)

# =============================================================================
# INPUT: hover, drag and drop, right-click sell
# =============================================================================

func _gui_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_mouse = motion.position
		_drag_point = motion.position
		_update_hover()
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or RoundManager.phase != RoundManager.Phase.PREP:
		return
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		var unit: Unit = RoundManager.board.unit_at(location_at(button.position))
		if unit != null and RoundManager.sell(unit):
			_sell_feedback(button.position, unit)
	elif button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_drag_unit = RoundManager.board.unit_at(location_at(button.position))
			_drag_point = button.position
			if _drag_unit != null:
				drag_changed.emit(_drag_unit)
		elif _drag_unit != null:
			_drop(button.position)

func _drop(point: Vector2) -> void:
	var unit: Unit = _drag_unit
	_drag_unit = null
	drag_changed.emit(null)
	var target: Dictionary = location_at(point)
	if target.is_empty():
		unit_dropped_outside.emit(unit, get_global_transform() * point)
		return
	if RoundManager.board.location_of(unit) == target:
		return
	if RoundManager.move_unit(unit, target):
		Sfx.play("place")
		_burst(location_center(target), UiTheme.PLAYER, 8, 90.0)
	else:
		Sfx.play("deny")

func _sell_feedback(point: Vector2, unit: Unit) -> void:
	Sfx.play("sell")
	_float(point, "+%d" % unit.sell_value(), UiTheme.GOLD, 18)
	_burst(point, UiTheme.GOLD, 12, 140.0)

func sell_feedback_at_global(global_point: Vector2, unit: Unit) -> void:
	_sell_feedback(get_global_transform().affine_inverse() * global_point, unit)

func _update_hover() -> void:
	var unit: Unit = null
	if RoundManager.phase == RoundManager.Phase.BATTLE or RoundManager.phase == RoundManager.Phase.RESULT:
		unit = _battle_unit_at(_mouse)
	elif RoundManager.board != null:
		unit = RoundManager.board.unit_at(location_at(_mouse))
		if unit == null:
			unit = _enemy_preview_at(_mouse)
	if unit != _hover_unit:
		_hover_unit = unit
		unit_hovered.emit(unit)

func _battle_unit_at(point: Vector2) -> Unit:
	if RoundManager.sim == null:
		return null
	for unit in RoundManager.sim.units:
		if unit.alive and unit_screen_position(unit).distance_to(point) < token_radius(unit.data) * 1.2:
			return unit
	return null

func _enemy_preview_at(point: Vector2) -> Unit:
	for entry in RoundManager.enemy_lineup:
		if arena_cell_center(entry["cell"] as Vector2i).distance_to(point) < CELL * 0.45:
			return entry["unit"] as Unit
	return null

# =============================================================================
# BATTLE EVENTS -> FEEDBACK
# =============================================================================

func _on_battle_event(event: Dictionary) -> void:
	match str(event["type"]):
		"attack":
			var unit: Unit = event["unit"] as Unit
			var target: Unit = event["target"] as Unit
			_lunge[unit.instance_id] = {"dir": (arena_cell_center(target.cell) - arena_cell_center(unit.cell)).normalized(), "left": LUNGE_TIME}
		"projectile":
			_on_projectile(event)
		"damage":
			_on_damage(event)
		"heal":
			var healed: Unit = event["unit"] as Unit
			_float(unit_screen_position(healed), "+%d" % int(float(event["amount"])), UiTheme.GOOD, 16)
			_burst(unit_screen_position(healed), UiTheme.GOOD, 10, 60.0)
			Sfx.play("heal")
		"shield":
			var shielded: Unit = event["unit"] as Unit
			_float(unit_screen_position(shielded), "+%d" % int(float(event["amount"])), Color(0.75, 0.9, 1.0), 15)
			Sfx.play("shield")
		"ability":
			_on_ability(event)
		"death":
			var dead: Unit = event["unit"] as Unit
			var pos: Vector2 = unit_screen_position(dead)
			_ghosts.append({"data": dead.data, "pos": pos, "team": dead.team, "star": dead.star, "life": 0.45})
			_burst(pos, UnitPainter.origin_color(dead.data), 24 if not dead.is_boss else 60, 200.0)
			_trauma = minf(_trauma + (0.8 if dead.is_boss else 0.18), 1.0)
			Sfx.play("death")

func _on_projectile(event: Dictionary) -> void:
	var unit: Unit = event["unit"] as Unit
	var target: Unit = event["target"] as Unit
	_shots.append({"from": unit_screen_position(unit), "target": target, "to": unit_screen_position(target),
		"life": maxf(float(event["duration"]), 0.05), "duration": maxf(float(event["duration"]), 0.05),
		"arcane": unit.traits.has("arcane"), "color": UnitPainter.origin_color(unit.data)})
	Sfx.play("arrow", 1.0, 0.1, -6.0)

func _on_damage(event: Dictionary) -> void:
	var target: Unit = event["unit"] as Unit
	var amount: int = int(round(float(event["amount"])))
	var pos: Vector2 = unit_screen_position(target) + Vector2(randf_range(-10.0, 10.0), -8.0)
	_flash[target.instance_id] = FLASH_TIME
	if bool(event["crit"]):
		_float(pos, str(amount), UiTheme.GOLD, 22)
		_trauma = minf(_trauma + 0.12, 1.0)
		Sfx.play("crit")
	elif str(event["kind"]) == "ability":
		_float(pos, str(amount), Color(0.82, 0.62, 1.0), 18)
	else:
		_float(pos, str(amount), Color(1.0, 1.0, 1.0, 0.9), 14)
		Sfx.play("hit", randf_range(0.85, 1.15), 0.05, -3.0)

func _on_ability(event: Dictionary) -> void:
	var unit: Unit = event["unit"] as Unit
	var kind: String = str(event["ability"])
	var color: Color = UnitPainter.origin_color(unit.data)
	var cells: Array = event.get("cells", []) as Array
	if not cells.is_empty():
		var center: Vector2 = arena_cell_center(cells[0] as Vector2i)
		_rings.append({"pos": center, "radius": CELL * 1.6, "life": 0.45, "max": 0.45, "color": color})
		_burst(center, color, 26, 220.0)
		_trauma = minf(_trauma + (0.5 if kind == "slam" else 0.25), 1.0)
		Sfx.play("boom")
	elif kind == "strike" or kind == "dash" or kind == "stun":
		var target: Unit = event["target"] as Unit
		_rings.append({"pos": unit_screen_position(target), "radius": CELL * 0.8, "life": 0.3, "max": 0.3, "color": color})
		Sfx.play("spell")
	else:
		Sfx.play("spell", 1.2)
	_float(unit_screen_position(unit) + Vector2(0.0, -CELL * 0.75), StringManager.t("ability_name_" + kind), color.lightened(0.3), 13)

func _on_unit_merged(unit: Unit) -> void:
	var location: Dictionary = RoundManager.board.location_of(unit)
	if location.is_empty():
		return
	var pos: Vector2 = location_center(location)
	_rings.append({"pos": pos, "radius": CELL * 1.4, "life": 0.6, "max": 0.6, "color": UiTheme.GOLD})
	_burst(pos, UiTheme.GOLD, 40, 260.0)
	_float(pos + Vector2(0.0, -CELL * 0.6), StringManager.t("merge_text", {value = unit.star}), UiTheme.GOLD, 20)
	_flash[unit.instance_id] = 0.4
	Sfx.play("merge")

func _float(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	# Keep the whole text inside the view (the bench starts at x = 0)
	var half: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5 + 4.0
	pos.x = clampf(pos.x, half, maxf(size.x - half, half))
	_texts.append({"pos": pos, "text": text, "color": color, "size": font_size, "life": 0.9, "drift": randf_range(-15.0, 15.0)})

func _burst(pos: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		_sparks.append({"pos": pos, "vel": Vector2.RIGHT.rotated(randf() * TAU) * speed * randf_range(0.3, 1.0),
			"life": randf_range(0.3, 0.7), "color": color.lightened(randf() * 0.3), "size": randf_range(1.5, 3.5)})

# =============================================================================
# UPDATE
# =============================================================================

func _process(delta: float) -> void:
	_time += delta
	var speed: float = RoundManager.battle_speed if RoundManager.phase == RoundManager.Phase.BATTLE else 1.0
	var fx_delta: float = delta * speed
	for key in _flash.keys():
		_flash[key] = float(_flash[key]) - fx_delta
		if float(_flash[key]) <= 0.0:
			_flash.erase(key)
	for key in _lunge.keys():
		var lunge: Dictionary = _lunge[key]
		lunge["left"] = float(lunge["left"]) - fx_delta
		if float(lunge["left"]) <= 0.0:
			_lunge.erase(key)
	_tick_list(_texts, delta, func(t: Dictionary) -> void: t["pos"] = (t["pos"] as Vector2) + Vector2(float(t["drift"]) * delta, -55.0 * delta))
	_tick_list(_sparks, delta, func(s: Dictionary) -> void:
		s["vel"] = (s["vel"] as Vector2) * (1.0 - minf(4.0 * delta, 1.0))
		s["pos"] = (s["pos"] as Vector2) + (s["vel"] as Vector2) * delta)
	_tick_list(_rings, delta, func(_r: Dictionary) -> void: pass)
	_tick_list(_ghosts, delta, func(_g: Dictionary) -> void: pass)
	_tick_shots(fx_delta)
	_trauma = maxf(_trauma - delta * 1.6, 0.0)
	# The arena shakes with the trauma (squared: small hits stay subtle)
	_shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _trauma * _trauma * 7.0
	queue_redraw()

func _tick_list(list: Array[Dictionary], delta: float, update: Callable) -> void:
	for i in range(list.size() - 1, -1, -1):
		var entry: Dictionary = list[i]
		entry["life"] = float(entry["life"]) - delta
		if float(entry["life"]) <= 0.0:
			list.remove_at(i)
		else:
			update.call(entry)

func _tick_shots(delta: float) -> void:
	for i in range(_shots.size() - 1, -1, -1):
		var shot: Dictionary = _shots[i]
		shot["life"] = float(shot["life"]) - delta
		var target: Unit = shot["target"] as Unit
		if target.alive:
			shot["to"] = unit_screen_position(target)
		if float(shot["life"]) <= 0.0:
			_shots.remove_at(i)

# =============================================================================
# DRAWING
# =============================================================================

func _draw() -> void:
	draw_set_transform(_shake)
	_draw_arena()
	_draw_bench()
	match RoundManager.phase:
		RoundManager.Phase.BATTLE, RoundManager.Phase.RESULT:
			_draw_battle()
		_:
			_draw_prep()
	_draw_fx()
	draw_set_transform(Vector2.ZERO)
	_draw_drag()

func _draw_arena() -> void:
	for row in _rows * 2:
		for col in _cols:
			var rect := Rect2(_arena_origin + Vector2(col, row) * CELL, Vector2(CELL, CELL))
			var enemy_half: bool = row < _rows
			var base: Color = Color(0.2, 0.11, 0.13) if enemy_half else Color(0.11, 0.14, 0.22)
			if (row + col) % 2 == 0:
				base = base.lightened(0.05)
			draw_rect(rect.grow(-1.0), base)
	var mid_y: float = _rows * CELL
	draw_line(_arena_origin + Vector2(0.0, mid_y), _arena_origin + Vector2(_cols * CELL, mid_y), Color(1.0, 0.85, 0.5, 0.35 + 0.15 * sin(_time * 2.0)), 2.0)
	draw_rect(Rect2(_arena_origin, Vector2(_cols, _rows * 2) * CELL), Color(0.35, 0.35, 0.48), false, 2.0)
	if _drag_unit != null:
		_draw_drop_targets()

func _draw_drop_targets() -> void:
	var target: Dictionary = location_at(_drag_point)
	for row in _rows:
		for col in _cols:
			var rect := Rect2(_arena_origin + Vector2(col, row + _rows) * CELL, Vector2(CELL, CELL)).grow(-3.0)
			draw_rect(rect, Color(UiTheme.PLAYER, 0.08 + 0.04 * sin(_time * 5.0)))
	if not target.is_empty():
		var center: Vector2 = location_center(target)
		draw_rect(Rect2(center - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)).grow(-2.0), Color(UiTheme.GOLD, 0.6), false, 2.0)

func _draw_bench() -> void:
	for i in ConfigManager.get_int("bench_size", 8):
		var center: Vector2 = bench_center(i)
		var rect := Rect2(center - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)).grow(-3.0)
		draw_rect(rect, Color(0.13, 0.13, 0.19))
		draw_rect(rect, Color(0.3, 0.3, 0.42), false, 1.0)

func _draw_prep() -> void:
	for entry in RoundManager.enemy_lineup:
		var enemy: Unit = entry["unit"] as Unit
		var pos: Vector2 = arena_cell_center(entry["cell"] as Vector2i)
		UnitPainter.draw_token(self, pos, token_radius(enemy.data), enemy.data, {"alpha": 0.6, "team": 1, "star": enemy.star})
	if RoundManager.board == null:
		return
	for c in RoundManager.board.cells:
		_draw_owned(RoundManager.board.cells[c] as Unit, {"zone": "board", "cell": c})
	_draw_bench_units()

func _draw_bench_units() -> void:
	if RoundManager.board == null:
		return
	for i in RoundManager.board.bench.size():
		var unit: Unit = RoundManager.board.bench[i] as Unit
		if unit != null:
			_draw_owned(unit, {"zone": "bench", "index": i})

func _draw_owned(unit: Unit, location: Dictionary) -> void:
	if unit == _drag_unit:
		return
	var pos: Vector2 = location_center(location)
	var bob: float = sin(_time * 3.0 + unit.instance_id) * 1.5 if unit == _hover_unit else 0.0
	UnitPainter.draw_token(self, pos + Vector2(0.0, bob), token_radius(unit.data), unit.data,
		{"team": 0 if location["zone"] == "board" else -1, "star": unit.star, "flash": float(_flash.get(unit.instance_id, 0.0)) / 0.4})

func _draw_battle() -> void:
	_draw_bench_units()
	for ghost in _ghosts:
		UnitPainter.draw_token(self, ghost["pos"] as Vector2, token_radius(ghost["data"] as Dictionary), ghost["data"] as Dictionary,
			{"alpha": float(ghost["life"]) / 0.45, "team": int(ghost["team"]), "star": int(ghost["star"])})
	if RoundManager.sim == null:
		return
	for unit in RoundManager.sim.units:
		if not unit.alive:
			continue
		var pos: Vector2 = unit_screen_position(unit)
		var radius: float = token_radius(unit.data)
		UnitPainter.draw_token(self, pos, radius, unit.data, {"team": unit.team, "star": unit.star, "flash": float(_flash.get(unit.instance_id, 0.0)) / FLASH_TIME})
		if unit.shield > 0.0:
			draw_arc(pos, radius * 1.3, 0.0, TAU, 32, Color(0.8, 0.92, 1.0, 0.55 + 0.2 * sin(_time * 6.0)), 2.5, true)
		if unit.stun_left > 0.0:
			for i in 3:
				var angle: float = _time * 6.0 + TAU * i / 3.0
				draw_circle(pos + Vector2(cos(angle) * radius * 0.8, -radius * 1.15 + sin(angle) * radius * 0.25), 2.5, UiTheme.GOLD)
		UnitPainter.draw_bars(self, pos, radius, unit)

func _draw_fx() -> void:
	for shot in _shots:
		var t: float = 1.0 - float(shot["life"]) / float(shot["duration"])
		var from: Vector2 = shot["from"] as Vector2
		var to: Vector2 = shot["to"] as Vector2
		var pos: Vector2 = from.lerp(to, t)
		var color: Color = shot["color"] as Color
		if bool(shot["arcane"]):
			draw_circle(pos, 6.0, Color(color, 0.35))
			draw_circle(pos, 3.5, color.lightened(0.5))
		else:
			var dir: Vector2 = (to - from).normalized()
			draw_line(pos - dir * 12.0, pos, color.lightened(0.4), 2.5, true)
	for r in _rings:
		var t: float = float(r["life"]) / float(r["max"])
		draw_arc(r["pos"] as Vector2, float(r["radius"]) * (1.0 - t * 0.7), 0.0, TAU, 48, Color(r["color"] as Color, t), 4.0 * t + 1.0, true)
	for s in _sparks:
		draw_circle(s["pos"] as Vector2, float(s["size"]), Color(s["color"] as Color, clampf(float(s["life"]) * 2.0, 0.0, 1.0)))
	for t in _texts:
		var life: float = float(t["life"])
		var alpha: float = clampf(life * 2.5, 0.0, 1.0)
		var text: String = t["text"] as String
		var font_size: int = int(t["size"])
		var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var pos: Vector2 = (t["pos"] as Vector2) - Vector2(width * 0.5, 0.0)
		draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.0, 0.0, 0.0, 0.7 * alpha))
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(t["color"] as Color, alpha))

func _draw_drag() -> void:
	if _drag_unit == null:
		return
	UnitPainter.draw_token(self, _drag_point, token_radius(_drag_unit.data) * 1.15, _drag_unit.data, {"team": 0, "star": _drag_unit.star})
