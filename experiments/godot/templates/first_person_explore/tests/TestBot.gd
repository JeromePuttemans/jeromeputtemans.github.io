# =============================================================================
# TestBot.gd: A bot that plays the whole game with the real controls
# =============================================================================
# Run: godot --headless --path . -- --bot   (add --fast to run 4x faster,
# --trace to print the position of the body four times a second)
# It presses the same actions as a player (move, jump, dash, sun keys) and
# aims by turning the camera, like the mouse would. The physics are the
# real ones. The route is the solution of the README, leg by leg; a leg
# starts on a platform and ends on the next one. On a fall (or a step that
# takes too long) the leg is played again from the last platform, up to
# three times. At the end it prints the time, the falls, the shards, the
# dashes and the launches, and quits with code 0 if the game was finished.
# =============================================================================

extends Node

var main: Node = null

var _sun: Sun = null
var _player: Player = null
var _rig: CameraRig = null
var _world: World = null
var _shadows: ShadowSystem = null
var _legs: Array = []
var _leg: int = 0
var _step: int = 0
var _tries: int = 0
var _t: float = 0.0
var _state: Dictionary = {}
var _total: float = 0.0
var _started: bool = false
var _done: bool = false
var _fell: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_cmdline_user_args().has("--fast"):
		Engine.time_scale = 4.0
		Engine.physics_ticks_per_second = 240
		Engine.max_physics_steps_per_frame = 16
	_sun = main.get("sun")
	_player = main.get("player")
	_rig = main.get("rig")
	_world = main.get("world")
	_shadows = main.get("shadows")
	_player.fell_out.connect(func() -> void: _fell = true)
	_legs = _route()

func _route() -> Array:
	return [
		{name = "Seuil > Cadran (7 h)", steps = [
			{op = "hour", h = 7.0},
			{op = "go", to = [30.6, 9.0]},
			{op = "go", to = [28.0, 8.6]},
			{op = "go", to = [27.4, 6.2]},
			{op = "go", to = [11.5, 3.8], sprint = true},
			{op = "go", to = [8.6, 1.0]},
			{op = "wait_on", island = "cadran"},
		]},
		{name = "Cadran > Dalle (7 h)", steps = [
			{op = "go", to = [-5.6, 0.0]},
			{op = "go", to = [-9.6, 0.3]},
			{op = "go", to = [-10.0, 1.6]},
			{op = "go", to = [-26.0, 0.2], sprint = true},
			{op = "wait_on", island = "w1"},
		]},
		{name = "Dalle > Repit (nuage)", steps = [
			{op = "go", to = [-29.0, 0.8]},
			{op = "go", to = [-32.4, 0.4]},
			{op = "go", to = [-33.0, -1.3]},
			{op = "wait_cloud", x = -43.0, z = -3.4, clear = 9.0},
			{op = "go", to = [-50.6, -3.8], sprint = true},
			{op = "go", to = [-52.0, -4.0]},
			{op = "wait_on", island = "rest"},
		]},
		{name = "Repit > Cap de l'aube (nuage)", steps = [
			{op = "go", to = [-53.6, -4.3]},
			{op = "wait_cloud", x = -62.5, z = -5.0, clear = 9.0},
			{op = "go", to = [-69.0, -5.6], sprint = true},
			{op = "wait_on", island = "w2"},
		]},
		{name = "Sceau de l'aube", steps = [
			{op = "go", to = [-74.15, -6.5], tol = 0.25},
			{op = "wait_seal", id = "dawn"},
			{op = "beam", to = [-71.0, -8.0]},
			{op = "wait_on", island = "cadran"},
			{op = "wait_free"},
		]},
		{name = "Cadran > Gue (elan)", steps = [
			{op = "go", to = [9.5, 6.2]},
			{op = "go", to = [7.0, -5.2], tol = 0.3},
			{op = "leap", to = [17.0, -15.0], from = "cadran", target = "gue"},
		]},
		{name = "Gue > Belvedere", steps = [
			{op = "go", to = [16.4, -14.4], tol = 0.3},
			{op = "leap", to = [24.0, -20.0], from = "gue", target = "belv"},
		]},
		{name = "Belvedere > Zenith (bac, 11 h)", steps = [
			{op = "hour", h = 11.0},
			{op = "go", to = [26.0, -21.6], tol = 0.3},
			{op = "wait_ferry", caster = "bac", point = [27.6, -22.2]},
			{op = "step", to = [27.7, -22.3], time = 0.25},
			{op = "ride", island = "n2", timeout = 20.0},
		]},
		{name = "Sceau du zenith", steps = [
			{op = "go", to = [53.65, -23.5], tol = 0.25},
			{op = "wait_seal", id = "noon"},
			{op = "beam", to = [50.0, -23.5]},
			{op = "wait_on", island = "cadran"},
			{op = "wait_free"},
		]},
		{name = "Cadran > Seuil (7 h)", steps = [
			{op = "hour", h = 7.0},
			{op = "go", to = [9.5, 6.2]},
			{op = "go", to = [11.5, 3.8]},
			{op = "go", to = [27.4, 6.0], sprint = true},
			{op = "wait_on", island = "seuil"},
		]},
		{name = "Seuil > Marche (17 h)", steps = [
			{op = "go", to = [27.2, 8.6]},
			{op = "go", to = [31.0, 8.6]},
			{op = "hour", h = 17.0},
			{op = "go", to = [31.0, 6.0]},
			{op = "go", to = [50.5, 3.6], sprint = true},
			{op = "go", to = [52.0, 2.4]},
			{op = "wait_on", island = "e1"},
		]},
		{name = "Marche > Tour (ombre suspendue, 7 h 25)", steps = [
			{op = "hour", h = 7.42},
			{op = "go", to = [52.8, 3.4], tol = 0.3},
			{op = "climb", to = [54.8, 3.4], top = 1.1},
			{op = "climb", to = [56.6, 3.4], top = 2.3},
			{op = "climb", to = [56.8, 5.8], top = 3.9},
			{op = "go", to = [57.6, 5.8], tol = 0.4},
			{op = "go", to = [71.5, 8.4]},
			{op = "wait_on", island = "e2"},
		]},
		{name = "Tour > Vigie (fleche, 15 h)", steps = [
			{op = "hour", h = 15.1},
			{op = "jib"},
			{op = "ride", island = "e3", timeout = 16.0},
		]},
		{name = "Sceau du crepuscule", steps = [
			{op = "go", to = [98.15, 5.0], tol = 0.25},
			{op = "wait_seal", id = "dusk"},
			{op = "beam", to = [96.8, 3.0]},
			{op = "wait_on", island = "cadran"},
			{op = "wait_free"},
			{op = "wait_gnomon"},
		]},
		{name = "Cadran > Oculus (midi)", steps = [
			{op = "hour", h = 12.0},
			{op = "go", to = [9.5, 6.2]},
			{op = "go", to = [9.3, 0.5]},
			{op = "go", to = [4.2, -3.2]},
			{op = "go", to = [3.0, -7.4]},
			{op = "go", to = [1.0, -9.6]},
			{op = "go", to = [0.6, -25.0], sprint = true},
			{op = "wait_end"},
		]},
	]

# --- main loop -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _done:
		return
	if not _started:
		if GameState.phase == GameState.Phase.MENU:
			main.call("_start", true)
			_started = true
			print("[bot] partie lancee")
		return
	_total += delta
	if OS.get_cmdline_user_args().has("--trace") and Engine.get_physics_frames() % 15 == 0:
		print("[trace] leg %d step %d pos %s floor %s surface %s caster %d hour %.2f" % [_leg, _step, str(_player.global_position.snapped(Vector3(0.01, 0.01, 0.01))), str(_player.is_on_floor()), _player.floor_surface, _player.floor_caster, _sun.hour])
	if _total > 900.0:
		_finish(false, "temps depasse")
		return
	if _fell:
		_fell = false
		_release_all()
		_retry("chute")
		return
	if GameState.phase == GameState.Phase.ENDING or GameState.phase == GameState.Phase.END:
		_release_all()
		if GameState.phase == GameState.Phase.END:
			print("[bot] %6.1f s  ok  %s" % [GameState.time, str(_legs[_leg]["name"])])
			_finish(true, "")
		return
	if bool(main.get("_busy")) and not _waits_busy():
		_release_all()
		return
	var leg: Dictionary = _legs[_leg]
	var steps: Array = leg["steps"] as Array
	var s: Dictionary = steps[_step]
	_t += delta
	if _t > float(s.get("timeout", 25.0)):
		_release_all()
		_retry("etape %d trop longue (%s)" % [_step, str(s["op"])])
		return
	if _run(s, delta):
		_release_all()
		_step += 1
		_t = 0.0
		_state = {}
		if _step >= steps.size():
			print("[bot] %6.1f s  ok  %s" % [GameState.time, str(leg["name"])])
			_leg += 1
			_step = 0
			_tries = 0
			if _leg >= _legs.size():
				_finish(true, "")

func _waits_busy() -> bool:
	var s: Dictionary = (_legs[_leg]["steps"] as Array)[_step]
	return str(s["op"]) in ["wait_on", "wait_free", "wait_end", "wait_gnomon", "beam"]

func _retry(reason: String) -> void:
	_tries += 1
	print("[bot] %6.1f s  ECHEC (%s) dans %s, essai %d" % [GameState.time, reason, str(_legs[_leg]["name"]), _tries + 1])
	if _tries >= 3:
		_finish(false, reason)
		return
	_step = 0
	_t = 0.0
	_state = {}
	if not bool(main.get("_busy")):
		main.call("quick_return")

func _finish(ok: bool, reason: String) -> void:
	_done = true
	_release_all()
	if ok:
		print("[bot] PARTIE TERMINEE en %s (temps de jeu), %d chute(s), %d/%d eclats, %d elans, %d lancers" % [GameState.format_precise(GameState.time), GameState.falls, GameState.shards.size(), GameState.shard_total, GameState.dashes, GameState.launches])
	else:
		print("[bot] ABANDON : %s" % reason)
	Engine.time_scale = 1.0
	get_tree().quit(0 if ok else 1)

# --- steps -----------------------------------------------------------------------

func _v2(a: Variant) -> Vector2:
	var arr: Array = a as Array
	return Vector2(float(arr[0]), float(arr[1]))

func _feet2() -> Vector2:
	return Vector2(_player.global_position.x, _player.global_position.z)

func _aim(target: Vector2, pitch: float = -0.1) -> void:
	var to: Vector2 = target - _feet2()
	if to.length() > 0.01:
		_rig.set_view(atan2(-to.x, -to.y), pitch)

func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "dash", "time_back", "time_forward"]:
		Input.action_release(a)

func _run(s: Dictionary, delta: float) -> bool:
	match str(s["op"]):
		"hour":
			return _op_hour(float(s["h"]))
		"go":
			var target: Vector2 = _v2(s["to"])
			var tol: float = float(s.get("tol", 0.6))
			var dist: float = _feet2().distance_to(target)
			if dist < tol:
				return true
			_aim(target)
			# close to a precise spot, walk in short pulses instead of
			# circling around it at full speed
			if dist < 0.8 and _player.horizontal_speed > 2.0:
				Input.action_release("move_forward")
			else:
				Input.action_press("move_forward")
			if bool(s.get("sprint", false)) and _feet2().distance_to(target) > 2.0:
				Input.action_press("dash")
			else:
				Input.action_release("dash")
			return false
		"beam":
			if bool(main.get("_busy")):
				return true
			_aim(_v2(s["to"]))
			Input.action_press("move_forward")
			return false
		"step":
			_aim(_v2(s["to"]))
			Input.action_press("move_forward")
			return _t >= float(s["time"])
		"wait_on":
			return GameState.checkpoint == str(s["island"]) and not bool(main.get("_busy"))
		"wait_free":
			return not bool(main.get("_busy"))
		"wait_seal":
			return GameState.seals_taken.has(str(s["id"]))
		"wait_gnomon":
			return GameState.gnomon_raised
		"wait_end":
			return GameState.phase == GameState.Phase.END
		"wait_cloud":
			return _op_cloud(float(s["x"]), float(s["z"]), float(s["clear"]))
		"wait_ferry":
			var c: ShadowSystem.Caster = _shadows.find(str(s["caster"]))
			var fraction: float = ShadowSystem.slide_fraction(c, _shadows.anim_time)
			return fraction < 0.02 and _covered(c, _v2(s["point"]), 0.35)
		"ride":
			if GameState.checkpoint == str(s["island"]) and _player.is_on_floor():
				return true
			_aim(Vector2(float(_world.island(str(s["island"]))["x"]), float(_world.island(str(s["island"]))["z"])))
			return false
		"leap":
			return _op_leap(s, delta)
		"climb":
			return _op_climb(s)
		"jib":
			return _op_jib()
	return true

func _op_hour(h: float) -> bool:
	var gap: float = h - _sun.target
	Input.action_release("time_back")
	Input.action_release("time_forward")
	# the keys move the hour at least 0.7 h/s: a frame of the fast mode
	# (4x) moves it about 0.05 h, hence the tolerance
	var tol: float = 0.06 if Engine.time_scale > 1.0 else 0.02
	if absf(gap) > tol:
		Input.action_press("time_forward" if gap > 0.0 else "time_back")
		return false
	return absf(_sun.hour - h) < tol * 2.0

func _covered(c: ShadowSystem.Caster, p: Vector2, margin: float) -> bool:
	var poly: PackedVector2Array = c.poly
	if poly.size() < 3:
		return false
	var eroded: Array[PackedVector2Array] = Geometry2D.offset_polygon(poly, -margin)
	for e in eroded:
		if Geometry2D.is_point_in_polygon(p, e):
			return true
	return false

## Waits until the cloud over this line of the bridge is far and leaving.
func _op_cloud(x: float, z: float, clear: float) -> bool:
	var clouds: Array = _shadows.get("_clouds")
	for cl in clouds:
		var cloud: Dictionary = cl as Dictionary
		if absf(float(cloud["x"]) - x) > 1.0:
			continue
		var dz: float = float(cloud["z"]) - z
		var prev: float = float(_state.get("dz", dz))
		_state["dz"] = dz
		return absf(dz) > clear and absf(dz) >= absf(prev)
	return true

## Run off the edge towards a platform, jump in the coyote time, dash at
## the top of the jump.
func _op_leap(s: Dictionary, _delta: float) -> bool:
	var target: Vector2 = _v2(s["to"])
	_aim(target)
	Input.action_press("move_forward")
	if not _state.has("air"):
		Input.action_press("dash")
		if not _player.is_on_floor():
			_state["air"] = 0.0
			Input.action_release("dash")
			Input.action_press("jump")
		return false
	_state["air"] = float(_state["air"]) + get_physics_process_delta_time()
	var air: float = float(_state["air"])
	if air > 0.12:
		Input.action_release("jump")
	if air > float(s.get("dash_delay", 0.3)) and not _state.has("dashed"):
		_state["dashed"] = true
		_player.bot_dash_press = true
	var target_def: Dictionary = _world.island(str(s["target"]))
	if not _player.is_on_floor() and World.contains(target_def, _player.global_position.x, _player.global_position.z, -0.6):
		# over the target: brake against the speed, as a player would
		Input.action_release("move_forward")
		Input.action_press("move_back")
	return _player.is_on_floor() and GameState.checkpoint == str(s["target"])

## Walk at a ledge and jump: the body grabs it and climbs.
func _op_climb(s: Dictionary) -> bool:
	var target: Vector2 = _v2(s["to"])
	_aim(target)
	Input.action_press("move_forward")
	if not _state.has("jumped"):
		_state["jumped"] = true
		Input.action_press("jump")
		return false
	if _t > 0.15:
		Input.action_release("jump")
	if _player.is_on_floor() and _player.global_position.y > float(s["top"]):
		return true
	if _player.is_on_floor() and _t > 0.6:
		_state.erase("jumped")
		_t = 0.0
	return false

## The jib: stand inside the rim of the Tower where the arm leaves it, and
## follow the arm out over the void when it passes.
func _op_jib() -> bool:
	var c: ShadowSystem.Caster = _shadows.find("fleche")
	var e2: Dictionary = _world.island("e2")
	var e3: Dictionary = _world.island("e3")
	if not _state.has("inside"):
		var dir: Vector3 = _sun.direction()
		var mid: float = c.size.y * 0.5 + (c.foot.y - c.plane)
		var hub := Vector2(c.pivot.x - dir.x * mid / dir.y, c.pivot.z - dir.z * mid / dir.y)
		var centre := Vector2(float(e2["x"]), float(e2["z"]))
		var r_rim: float = float(e2["r"])
		var to_e3: float = hub.distance_to(Vector2(float(e3["x"]), float(e3["z"])))
		var ride: float = clampf(to_e3, to_e3 - float(e3["r"]) + 0.8, c.size.x * 0.5 - 0.8)
		var d: float = hub.distance_to(centre)
		var u: Vector2 = (centre - hub) / d
		var a: float = (ride * ride - r_rim * r_rim + d * d) / (2.0 * d)
		var h: float = sqrt(maxf(ride * ride - a * a, 0.0))
		var base: Vector2 = hub + u * a
		var n := Vector2(-u.y, u.x)
		var best := Vector2.ZERO
		for sign_value in [-1.0, 1.0]:
			var x: Vector2 = base + n * h * float(sign_value)
			var r: Vector2 = x - hub
			var v := Vector2(r.y, -r.x) * signf(c.spin_speed)
			if v.dot(x - centre) > 0.0:
				best = x
		var out: Vector2 = (best - centre).normalized()
		_state["inside"] = centre + out * (r_rim - 0.5)
		_state["outside"] = centre + out * (r_rim + 0.7)
	var inside: Vector2 = _state["inside"]
	var outside: Vector2 = _state["outside"]
	if not _state.has("boarding"):
		if _feet2().distance_to(inside) > 0.25:
			_aim(inside)
			Input.action_press("move_forward")
			return false
		_aim(outside)
		if _covered(c, inside, 0.2):
			_state["boarding"] = 0.0
		return false
	_state["boarding"] = float(_state["boarding"]) + get_physics_process_delta_time()
	var on_tower: bool = World.contains(e2, _player.global_position.x, _player.global_position.z, 0.0)
	if on_tower and float(_state["boarding"]) < 0.45:
		_aim(outside)
		Input.action_press("move_forward")
		return false
	return true
