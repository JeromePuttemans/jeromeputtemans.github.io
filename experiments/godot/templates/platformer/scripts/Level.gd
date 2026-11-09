# =============================================================================
# Level.gd — Builds a level from LevelData and runs it
# =============================================================================
# One physics tick, in a fixed order (deterministic):
#   moving platforms -> carry the player -> player -> enemies -> projectiles
#   -> crumbling blocks -> overlaps (hazards, enemies, pickups, springs,
#   lanterns, exit) -> camera.
#
# COLLISION: the player box moves one axis at a time. sweep_x / sweep_y scan
# the tile columns (or rows) the leading edge crosses and stop the box at
# the first solid tile, so a fast box can never tunnel through a wall.
# Planks and moving platforms only stop a box moving down whose bottom was
# above their top. A cell is solid when it is ground, a crumbling block that
# has not fallen, or a coloured block of the active colour.
#
# COLOURED BLOCKS: every jump (ground, wall or air) swaps the active colour.
# A block that becomes solid while overlapping the player stays a ghost
# (passable) until the player has left it, so a swap never traps anyone.
#
# STOMP: touching a stompable enemy while falling with the feet above its
# top (plus STOMP_TOLERANCE) kills it and bounces the player; any other
# contact kills the player, who reappears at the last lantern.
# =============================================================================

class_name Level
extends Node2D

signal finished()

const T: float = LevelData.TILE
const EPS: float = 0.001
const CHUNK: int = 16
const STOMP_TOLERANCE: float = 12.0

var data: LevelData = null
var player: Player = null
var camera: GameCamera = null
var effects: Effects = null
var active: bool = false

var toggle_phase: int = 0
var _ghosts: Dictionary = {}
var _crumbles: Dictionary = {}
var _toggle_layer: ToggleLayer = null
var _movers: Array[MovingPlatform] = []
var _enemies: Array[Enemy] = []
var _projectiles: Array[Seed] = []
var _fireflies: Array[Firefly] = []
var _acorns: Array[Acorn] = []
var _springs: Array[Spring] = []
var _checkpoints: Array[Checkpoint] = []
var _signs: Array[HintSign] = []
var _exit: LevelExit = null
var _entities: Node2D = null
var _projectile_layer: Node2D = null
var _freeze: int = 0
var _respawn_timer: float = -1.0
var _finish_timer: float = -1.0
var _firefly_streak: int = 0
var _firefly_streak_timer: float = 0.0
var _kill_y: float = 0.0

# =============================================================================
# BUILD
# =============================================================================

func build(level_data: LevelData) -> void:
	data = level_data
	_kill_y = data.height * T + 60.0
	for cy in range(0, data.height, CHUNK):
		for cx in range(0, data.width, CHUNK):
			var chunk := TileChunk.new()
			chunk.setup(data, Rect2i(cx, cy, CHUNK, CHUNK))
			add_child(chunk)
	_build_dynamic_tiles()
	for m in data.movers:
		var mover := MovingPlatform.new()
		mover.setup(m, data)
		add_child(mover)
		_movers.append(mover)
	_entities = Node2D.new()
	add_child(_entities)
	for spawn in data.spawns:
		_spawn_entity(spawn)
	player = Player.new()
	player.level = self
	add_child(player)
	player.position = LevelData.cell_feet(data.start_cell)
	player.jumped.connect(_on_player_jumped)
	player.landed.connect(_on_player_landed)
	_projectile_layer = Node2D.new()
	add_child(_projectile_layer)
	effects = Effects.new()
	add_child(effects)
	camera = GameCamera.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	camera.setup(data.pixel_size())
	camera.snap_to(player)
	GameState.checkpoint = player.position
	active = true

func _build_dynamic_tiles() -> void:
	var toggles: Array[Vector2i] = []
	for y in data.height:
		for x in data.width:
			var t: int = data.tile(x, y)
			if t == LevelData.Tile.CRUMBLE:
				var block := CrumbleBlock.new()
				block.cell = Vector2i(x, y)
				block.theme_data = data
				add_child(block)
				_crumbles[y * data.width + x] = block
			elif t == LevelData.Tile.TOGGLE_A or t == LevelData.Tile.TOGGLE_B:
				toggles.append(Vector2i(x, y))
	if not toggles.is_empty():
		_toggle_layer = ToggleLayer.new()
		_toggle_layer.setup(self, toggles)
		add_child(_toggle_layer)

func _spawn_entity(spawn: Dictionary) -> void:
	var cell: Vector2i = spawn["cell"] as Vector2i
	var kind: String = str(spawn["kind"])
	match kind:
		"firefly":
			var f := Firefly.new()
			f.index = int(spawn["index"])
			f.position = LevelData.cell_center(cell)
			f.collected = GameState.fireflies.has(f.index)
			_add_entity(f)
			_fireflies.append(f)
		"acorn":
			var a := Acorn.new()
			a.index = int(spawn["index"])
			a.position = LevelData.cell_center(cell)
			a.collected = GameState.acorns.has(a.index)
			a.found_before = SaveManager.acorn_found(data.id, a.index)
			_add_entity(a)
			_acorns.append(a)
		"spring":
			var s := Spring.new()
			s.position = LevelData.cell_feet(cell)
			_add_entity(s)
			_springs.append(s)
		"checkpoint":
			var k := Checkpoint.new()
			k.position = LevelData.cell_feet(cell)
			_add_entity(k)
			_checkpoints.append(k)
		"exit":
			_exit = LevelExit.new()
			_exit.position = LevelData.cell_feet(cell)
			_add_entity(_exit)
		"sign":
			var h := HintSign.new()
			h.text_key = str(spawn["text"])
			h.position = LevelData.cell_feet(cell)
			_add_entity(h)
			_signs.append(h)
		"walker", "hedgehog":
			var w := Walker.new()
			w.spiky = kind == "hedgehog"
			w.position = LevelData.cell_feet(cell)
			_add_enemy(w)
		"flyer", "flyer_v":
			var fl := Flyer.new()
			fl.vertical = kind == "flyer_v"
			fl.origin = LevelData.cell_center(cell)
			fl.position = fl.origin
			fl.phase = float(cell.x) * 0.7
			_add_enemy(fl)
		"spitter_left", "spitter_right":
			var sp := Spitter.new()
			sp.dir = -1 if kind == "spitter_left" else 1
			sp.position = LevelData.cell_feet(cell)
			sp.timer = 0.6 + fmod(float(cell.x) * 0.37, 1.6)
			_add_enemy(sp)

func _add_entity(node: Node2D) -> void:
	_entities.add_child(node)

func _add_enemy(enemy: Enemy) -> void:
	enemy.level = self
	_entities.add_child(enemy)
	_enemies.append(enemy)

func spawn_seed(at: Vector2, dir: int) -> void:
	var s := Seed.new()
	s.level = self
	s.position = at
	s.velocity = Vector2(dir * ConfigManager.get_float("seed_speed", 230.0), 0.0)
	_projectile_layer.add_child(s)
	_projectiles.append(s)

# =============================================================================
# TICK
# =============================================================================

func _physics_process(delta: float) -> void:
	if not active:
		return
	if _freeze > 0:
		_freeze -= 1
		return
	GameState.add_time(delta)
	for m in _movers:
		m.step(delta)
	_carry_player()
	player.step(delta)
	for i in range(_enemies.size() - 1, -1, -1):
		var e: Enemy = _enemies[i]
		e.step(delta)
		if e.removed:
			_enemies.remove_at(i)
			e.queue_free()
	_step_projectiles(delta)
	_step_crumbles()
	_update_ghosts()
	_interactions()
	_step_timers(delta)
	camera.follow(player, delta)

func _carry_player() -> void:
	var m: MovingPlatform = player.platform
	if m == null or player.dead:
		return
	var b: Rect2 = player.box()
	player.position.x += sweep_x(b, m.delta.x)
	b = player.box()
	if m.delta.y < 0.0:
		player.position.y += float(sweep_y(b, m.delta.y, true)["dy"])
	else:
		player.position.y += m.delta.y

func _step_projectiles(delta: float) -> void:
	for i in range(_projectiles.size() - 1, -1, -1):
		var s: Seed = _projectiles[i]
		s.step(delta)
		if s.gone:
			_projectiles.remove_at(i)
			s.queue_free()

func _step_crumbles() -> void:
	if player.grounded and not player.dead:
		var b: Rect2 = player.box()
		var row: int = floori((b.end.y + 1.0) / T)
		for col in range(floori(b.position.x / T), floori((b.end.x - EPS) / T) + 1):
			var key: int = row * data.width + col
			if _crumbles.has(key):
				(_crumbles[key] as CrumbleBlock).trigger()
	for key in _crumbles:
		var block: CrumbleBlock = _crumbles[key] as CrumbleBlock
		if block.wants_respawn() and not player.box().intersects(block.rect()):
			block.respawn()

func _step_timers(delta: float) -> void:
	_firefly_streak_timer -= delta
	if _firefly_streak_timer <= 0.0:
		_firefly_streak = 0
	if _respawn_timer >= 0.0:
		_respawn_timer -= delta
		if _respawn_timer < 0.0:
			_respawn()
	if _finish_timer >= 0.0:
		_finish_timer -= delta
		if _finish_timer < 0.0:
			active = false
			finished.emit()

func freeze(frames: int) -> void:
	_freeze = maxi(_freeze, frames)

# =============================================================================
# INTERACTIONS
# =============================================================================

func _interactions() -> void:
	if player.dead or player.frozen:
		return
	var hurt: Rect2 = player.hurt_box()
	if player.position.y > _kill_y or touches_spikes(hurt):
		kill_player()
		return
	for e in _enemies:
		if not e.alive:
			continue
		var hit: Rect2 = e.hit_box()
		if not hit.intersects(player.box()):
			continue
		var from_above: bool = player.velocity.y > 0.0 and player.prev_bottom <= hit.position.y + STOMP_TOLERANCE
		if from_above and e.stompable:
			_stomp(e)
		elif hit.intersects(hurt):
			kill_player()
			return
	for s in _projectiles:
		if not s.gone and s.hit_box().intersects(hurt):
			kill_player()
			return
	_pickups()
	for spring in _springs:
		if player.velocity.y >= 0.0 and spring.top_box().intersects(player.box()):
			player.bounce(ConfigManager.get_float("spring_velocity", 1250.0), false)
			spring.use()
			Sfx.play("spring")
			effects.dust(spring.position + Vector2(0.0, -6.0), 6, Vector2(0.0, -40.0))
	for k in _checkpoints:
		if not k.lit and k.box().intersects(player.box()):
			_light(k)
	for h in _signs:
		h.set_near(h.position.distance_to(player.position) < 70.0)
	if _exit != null and _exit.box().intersects(player.box()):
		_reach_exit()

func _pickups() -> void:
	var c: Vector2 = player.center()
	for f in _fireflies:
		if not f.collected and f.position.distance_to(c) < 30.0:
			f.collect()
			GameState.collect_firefly(f.index)
			_firefly_streak += 1
			_firefly_streak_timer = 0.9
			Sfx.play("firefly", pow(1.06, mini(_firefly_streak - 1, 10)), 0.0)
			effects.sparkle(f.position, Color("f7ef7a"), 8)
	for a in _acorns:
		if not a.collected and a.position.distance_to(c) < 32.0:
			a.collect()
			GameState.collect_acorn(a.index)
			Sfx.play("acorn", 1.0, 0.0)
			effects.sparkle(a.position, Color("ffd34d"), 18)
			effects.ring(a.position, Color("ffe08a"), 60.0, 0.45, 4.0)
			effects.float_text(a.position + Vector2(0.0, -28.0), StringManager.t("acorn_found", {n = GameState.acorns.size(), total = data.acorn_total}), Color("ffe08a"), 18)
			freeze(4)

func _stomp(e: Enemy) -> void:
	e.die()
	var speed: float = ConfigManager.get_float("stomp_bounce_held", 820.0) if player.is_jump_held() else ConfigManager.get_float("stomp_bounce", 560.0)
	player.bounce(speed, true)
	Sfx.play("stomp")
	effects.burst(e.position + Vector2(0.0, -14.0), e.color(), 12, 220.0)
	effects.ring(e.position + Vector2(0.0, -10.0), Color(1.0, 1.0, 1.0, 0.8), 34.0, 0.25, 3.0)
	camera.add_trauma(0.25)
	freeze(3)

func _light(k: Checkpoint) -> void:
	for other in _checkpoints:
		other.lit = other == k
	k.light()
	GameState.checkpoint = k.position
	Sfx.play("checkpoint")
	effects.sparkle(k.position + Vector2(0.0, -58.0), Color("ffc46b"), 14)
	effects.float_text(k.position + Vector2(0.0, -86.0), StringManager.t("checkpoint"), Color("ffd89a"), 16)

func _reach_exit() -> void:
	player.enter_exit(_exit.position + Vector2(0.0, -30.0))
	_exit.open()
	Sfx.play("exit")
	effects.sparkle(_exit.position + Vector2(0.0, -40.0), Color("fff2b0"), 30)
	effects.ring(_exit.position + Vector2(0.0, -40.0), Color("fff2b0"), 90.0, 0.6, 5.0)
	_finish_timer = ConfigManager.get_float("finish_delay", 1.1)
	GameState.stop_clock()

func kill_player() -> void:
	if player.dead:
		return
	var at: Vector2 = player.center()
	player.die()
	GameState.add_death()
	Sfx.play("death")
	effects.leaves(at, 18)
	effects.ring(at, Color(1.0, 1.0, 1.0, 0.9), 46.0, 0.3, 4.0)
	camera.add_trauma(0.55)
	freeze(5)
	_respawn_timer = ConfigManager.get_float("respawn_delay", 0.6)

## R key: back to the last lantern (counts as a fall).
func restart_from_checkpoint() -> void:
	if player.dead or player.frozen:
		return
	kill_player()

func _respawn() -> void:
	player.respawn(GameState.checkpoint)
	player.facing = 1
	camera.snap_to(player)
	Sfx.play("respawn")
	effects.ring(player.center(), Color("c9f59a"), 40.0, 0.35, 3.0)
	effects.sparkle(player.center(), Color("c9f59a"), 8)

func _on_player_jumped(kind: String) -> void:
	match kind:
		"ground":
			Sfx.play("jump")
			effects.dust(player.position, 4, Vector2(0.0, -30.0))
		"wall":
			Sfx.play("wall_jump")
			effects.dust(player.position + Vector2(-player.facing * 12.0, -16.0), 5, Vector2(player.facing * 60.0, -10.0))
		"air":
			Sfx.play("air_jump")
			effects.ring(player.center() + Vector2(0.0, 10.0), Color("d8f7b0"), 26.0, 0.25, 3.0)
			effects.leaves(player.position, 3)
	if _toggle_layer != null:
		_swap_toggles()

func _on_player_landed(impact: float) -> void:
	if impact > 300.0:
		effects.dust(player.position, int(2 + impact / 200.0), Vector2(0.0, -20.0))
		Sfx.play("land", 1.0, 0.08, linear_to_db(clampf(impact / 900.0, 0.25, 1.0)))
	if impact > 1000.0:
		camera.add_trauma(0.12)

func _swap_toggles() -> void:
	toggle_phase = 1 - toggle_phase
	var b: Rect2 = player.box()
	_ghosts.clear()
	for cell in _toggle_layer.cells:
		var t: int = data.tile(cell.x, cell.y)
		var now_solid: bool = (t == LevelData.Tile.TOGGLE_A) == (toggle_phase == 0)
		if now_solid and b.intersects(cell_rect(cell)):
			_ghosts[cell.y * data.width + cell.x] = true
	_toggle_layer.swapped()
	Sfx.play("toggle")

func _update_ghosts() -> void:
	if _ghosts.is_empty():
		return
	var b: Rect2 = player.box()
	for key in _ghosts.keys():
		var cell := Vector2i(int(key) % data.width, int(key) / data.width)
		if not b.intersects(cell_rect(cell)):
			_ghosts.erase(key)

func is_ghost(cell: Vector2i) -> bool:
	return _ghosts.has(cell.y * data.width + cell.x)

# =============================================================================
# TILE QUERIES AND BOX SWEEPS
# =============================================================================

func is_solid(cx: int, cy: int) -> bool:
	if cx < 0 or cx >= data.width:
		return true
	if cy < 0 or cy >= data.height:
		return false
	var key: int = cy * data.width + cx
	match data.tiles[key]:
		LevelData.Tile.SOLID:
			return true
		LevelData.Tile.CRUMBLE:
			return (_crumbles[key] as CrumbleBlock).is_solid()
		LevelData.Tile.TOGGLE_A:
			return toggle_phase == 0 and not _ghosts.has(key)
		LevelData.Tile.TOGGLE_B:
			return toggle_phase == 1 and not _ghosts.has(key)
	return false

## Solid or plank: something a walker can stand on.
func is_floor(cx: int, cy: int) -> bool:
	return is_solid(cx, cy) or data.tile(cx, cy) == LevelData.Tile.ONEWAY

func is_solid_px(p: Vector2) -> bool:
	return is_solid(floori(p.x / T), floori(p.y / T))

func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell.x * T, cell.y * T, T, T)

## Horizontal sweep: returns how far the box can really move.
func sweep_x(b: Rect2, dx: float) -> float:
	if dx == 0.0:
		return 0.0
	var r0: int = floori(b.position.y / T)
	var r1: int = floori((b.end.y - EPS) / T)
	if dx > 0.0:
		var c0: int = floori((b.end.x - EPS) / T) + 1
		var c1: int = floori((b.end.x + dx - EPS) / T)
		for c in range(c0, c1 + 1):
			for r in range(r0, r1 + 1):
				if is_solid(c, r):
					return maxf(c * T - b.end.x, 0.0)
	else:
		var c0: int = floori((b.position.x + EPS) / T) - 1
		var c1: int = floori((b.position.x + dx) / T)
		for c in range(c0, c1 - 1, -1):
			for r in range(r0, r1 + 1):
				if is_solid(c, r):
					return minf((c + 1) * T - b.position.x, 0.0)
	return dx

## Vertical sweep: {dy, hit, platform}. Moving down also lands on planks and
## moving platforms unless ignore_oneway is set.
func sweep_y(b: Rect2, dy: float, ignore_oneway: bool) -> Dictionary:
	var result: Dictionary = {dy = dy, hit = false, platform = null}
	if dy == 0.0:
		return result
	var c0: int = floori(b.position.x / T)
	var c1: int = floori((b.end.x - EPS) / T)
	if dy > 0.0:
		var r0: int = floori((b.end.y - EPS) / T) + 1
		var r1: int = floori((b.end.y + dy - EPS) / T)
		var found: bool = false
		for r in range(r0, r1 + 1):
			for c in range(c0, c1 + 1):
				if is_solid(c, r) or (not ignore_oneway and data.tile(c, r) == LevelData.Tile.ONEWAY):
					result["dy"] = maxf(r * T - b.end.y, 0.0)
					result["hit"] = true
					found = true
					break
			if found:
				break
		if not ignore_oneway:
			for m in _movers:
				var top: float = m.rect.position.y
				if b.end.y > top + m.carry_tolerance or b.end.y + dy < top:
					continue
				if b.end.x <= m.rect.position.x or b.position.x >= m.rect.end.x:
					continue
				var to_top: float = maxf(top - b.end.y, 0.0)
				if not bool(result["hit"]) or to_top < float(result["dy"]):
					result["dy"] = to_top
					result["hit"] = true
					result["platform"] = m
	else:
		var r0: int = floori((b.position.y + EPS) / T) - 1
		var r1: int = floori((b.position.y + dy) / T)
		for r in range(r0, r1 - 1, -1):
			for c in range(c0, c1 + 1):
				if is_solid(c, r):
					result["dy"] = minf((r + 1) * T - b.position.y, 0.0)
					result["hit"] = true
					return result
	return result

func box_hits_solid(b: Rect2) -> bool:
	for r in range(floori(b.position.y / T), floori((b.end.y - EPS) / T) + 1):
		for c in range(floori(b.position.x / T), floori((b.end.x - EPS) / T) + 1):
			if is_solid(c, r):
				return true
	return false

## A wall within 2 px on side dir, over the middle of the box.
func touches_wall(b: Rect2, dir: int) -> bool:
	var probe := Rect2(b.end.x if dir > 0 else b.position.x - 2.0, b.position.y + 6.0, 2.0, b.size.y - 12.0)
	return box_hits_solid(probe)

## Feet on a plank only (no ground under the box).
func standing_on_oneway(b: Rect2) -> bool:
	var row: int = floori((b.end.y + 1.0) / T)
	var plank: bool = false
	for c in range(floori(b.position.x / T), floori((b.end.x - EPS) / T) + 1):
		if is_solid(c, row):
			return false
		plank = plank or data.tile(c, row) == LevelData.Tile.ONEWAY
	return plank

func touches_spikes(b: Rect2) -> bool:
	for r in range(floori(b.position.y / T), floori((b.end.y - EPS) / T) + 1):
		for c in range(floori(b.position.x / T), floori((b.end.x - EPS) / T) + 1):
			var t: int = data.tile(c, r)
			var rect := Rect2()
			match t:
				LevelData.Tile.SPIKE_UP:
					rect = Rect2(c * T + 4.0, r * T + T * 0.55, T - 8.0, T * 0.45)
				LevelData.Tile.SPIKE_DOWN:
					rect = Rect2(c * T + 4.0, r * T, T - 8.0, T * 0.45)
				LevelData.Tile.SPIKE_LEFT:
					rect = Rect2(c * T + T * 0.55, r * T + 4.0, T * 0.45, T - 8.0)
				LevelData.Tile.SPIKE_RIGHT:
					rect = Rect2(c * T, r * T + 4.0, T * 0.45, T - 8.0)
				_:
					continue
			if rect.intersects(b):
				return true
	return false
