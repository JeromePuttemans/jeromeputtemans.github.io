# =============================================================================
# Fighter.gd — One automaton: state machine, frame data, hits, animation
# =============================================================================
# The whole fight runs at 60 steps per second (Match._physics_process), and
# every duration is a number of frames, as in arcade fighting games.
#
# MOVES (data/fighters.json): startup frames (wind-up), active frames (the
# hitbox can touch), recovery frames (vulnerable). The hitbox is the box
# around the striking limb of the "active" pose (Rig.limb_box), so it sits
# exactly on the drawn fist or foot. During active and recovery frames the
# limb is also a hurtbox: a whiffed attack can be punished on the limb.
#
# CANCELS: a move that touched (hit or blocked) can be interrupted, during
# its active frames and the first CANCEL_WINDOW frames of recovery, by a
# move of its "cancel" list ("special" and "super" stand for those moves).
# That is how light -> heavy -> special combos are built.
#
# DEFENCE: holding away from the opponent blocks. Standing blocks mid and
# high (jumping attacks), crouching blocks mid and low. Blocked specials
# still cost a little health (chip). Attacks hitting during the startup of
# an opponent's move are counter hits: x1.25 damage, +6 hitstun frames.
# Combo damage is scaled: from the third hit, each hit is 12 % weaker
# (never below 30 %). An opponent juggled more than 3 times becomes
# invulnerable until it lands.
# =============================================================================

class_name Fighter
extends Node2D

enum State { IDLE, WALK, CROUCH, PREJUMP, AIR, ATTACK, DASH, BACKDASH, BLOCKSTUN, HITSTUN, AIR_HIT, KNOCKDOWN, WAKEUP, THROWN, KO, VICTORY }

const NEUTRAL: Dictionary = {x = 0, y = 0, L = false, H = false, S = false, hL = false, hH = false, hS = false}
const BUFFER: int = 6
const CANCEL_WINDOW: int = 8
const PREJUMP_FRAMES: int = 3
const KNOCKDOWN_FRAMES: int = 34
const WAKEUP_FRAMES: int = 18
const TECH_WINDOW: int = 8
const DASH_TAP_WINDOW: int = 12

var match_node: Node = null
var index: int = 0
var char_id: String = ""
var data: Dictionary = {}
var style: Dictionary = {}
var moves: Dictionary = {}
var input: Object = null
var opponent: Fighter = null
var controllable: bool = false

var hp: float = 1000.0
var max_hp: float = 1000.0
var meter: float = 0.0
var state: State = State.IDLE
var state_frame: int = 0
var facing: int = 1
var vel := Vector2.ZERO
var airborne: bool = false
var hitstop: int = 0
var invuln: int = 0
var move_id: String = ""
var move: Dictionary = {}
var move_frame: int = 0
var hits_done: int = 0
var next_hit: int = 0
var connected: bool = false
var was_blocked: bool = false
var armor_used: int = 0
var stun: int = 0
var push: float = 0.0
var juggle: int = 0
var combo_hits: int = 0
var combo_damage: float = 0.0
var air_jumps_left: int = 0
var air_attack_used: bool = false
var crouching: bool = false
var low_hit: bool = false
var thrown_by: Fighter = null
var throw_techable: bool = true
var last_input: Dictionary = NEUTRAL

var pose: Dictionary = {}
var flash: float = 0.0
var _time: float = 0.0
var _buf: Dictionary = {L = 99, H = 99, S = 99}
var _tap_fwd: int = 99
var _tap_back: int = 99
var _prev_fx: int = 0
var _dash_request: int = 0
var _jump_dir: int = 0
var _hitbox_cache: Dictionary = {}
var _trail: Array[Dictionary] = []
var _throw_move: Dictionary = {}

func setup(id: String, character: Dictionary, player_index: int) -> void:
	char_id = id
	data = character
	style = character.get("style", {}) as Dictionary
	moves = character.get("moves", {}) as Dictionary
	index = player_index
	max_hp = float(character.get("hp", 1000))
	hp = max_hp
	pose = Poses.copy(Poses.get_pose("idle"))

func reset_for_round(x: float, face: int) -> void:
	position = Vector2(x, 0.0)
	facing = face
	hp = max_hp
	vel = Vector2.ZERO
	airborne = false
	push = 0.0
	stun = 0
	hitstop = 0
	invuln = 0
	juggle = 0
	combo_hits = 0
	combo_damage = 0.0
	move_id = ""
	thrown_by = null
	_buf = {L = 99, H = 99, S = 99}
	_trail.clear()
	_set_state(State.IDLE)
	pose = Poses.copy(Poses.get_pose("idle"))
	reset_physics_interpolation()

# =============================================================================
# FRAME STEP
# =============================================================================

func step() -> void:
	var inp: Dictionary = NEUTRAL
	if controllable and input != null:
		inp = input.call("poll", self) as Dictionary
	last_input = inp
	if hitstop > 0:
		hitstop -= 1
		_record(inp, false)
		return
	_record(inp, true)
	state_frame += 1
	if invuln > 0:
		invuln -= 1
	match state:
		State.IDLE, State.WALK, State.CROUCH:
			_neutral(inp)
		State.PREJUMP:
			if state_frame >= PREJUMP_FRAMES:
				_jump(_jump_dir)
		State.AIR:
			_air(inp)
		State.ATTACK:
			_attack_step(inp)
		State.DASH, State.BACKDASH:
			_dash_step()
		State.BLOCKSTUN, State.HITSTUN:
			stun -= 1
			if stun <= 0:
				_to_neutral()
		State.KNOCKDOWN:
			if state_frame >= KNOCKDOWN_FRAMES:
				_set_state(State.WAKEUP)
				invuln = WAKEUP_FRAMES + 2
		State.WAKEUP:
			if state_frame >= WAKEUP_FRAMES:
				_to_neutral()
		State.THROWN:
			_thrown_step()
	_physics()
	_update_pose()
	if state in [State.DASH, State.BACKDASH] or (state == State.ATTACK and (move_id == "super" or move.has("pass_through"))):
		_trail.push_front({pos = position, pose = pose.duplicate(), facing = facing})
	elif not _trail.is_empty():
		_trail.pop_back()
	while _trail.size() > 5:
		_trail.pop_back()

func _record(inp: Dictionary, age: bool) -> void:
	for b in ["L", "H", "S"]:
		if bool(inp[b]):
			_buf[b] = 0
		elif age:
			_buf[b] = mini(int(_buf[b]) + 1, 99)
	if not age:
		return
	var fx: int = int(inp["x"]) * toward()
	if fx > 0 and _prev_fx <= 0:
		if _tap_fwd < DASH_TAP_WINDOW:
			_dash_request = 1
		_tap_fwd = 0
	elif fx < 0 and _prev_fx >= 0:
		if _tap_back < DASH_TAP_WINDOW:
			_dash_request = -1
		_tap_back = 0
	_tap_fwd = mini(_tap_fwd + 1, 99)
	_tap_back = mini(_tap_back + 1, 99)
	_prev_fx = fx

func pressed(button: String) -> bool:
	return int(_buf[button]) < BUFFER

func _consume(button: String) -> void:
	_buf[button] = 99

func toward() -> int:
	if opponent == null:
		return facing
	var d: float = opponent.position.x - position.x
	if absf(d) < 1.0:
		return facing
	return 1 if d > 0.0 else -1

func holding_back() -> bool:
	return int(last_input["x"]) == -toward()

func holding_down() -> bool:
	return int(last_input["y"]) > 0

func _set_state(s: State) -> void:
	state = s
	state_frame = 0

func _to_neutral() -> void:
	move_id = ""
	move = {}
	if airborne:
		_set_state(State.AIR)
		return
	vel.x = 0.0
	if holding_down():
		crouching = true
		_set_state(State.CROUCH)
	else:
		crouching = false
		_set_state(State.IDLE)
	combo_hits = 0
	combo_damage = 0.0
	juggle = 0

# =============================================================================
# NEUTRAL, JUMPS, DASHES
# =============================================================================

func _neutral(inp: Dictionary) -> void:
	facing = toward()
	combo_hits = 0
	combo_damage = 0.0
	juggle = 0
	if _try_attack(inp, []):
		return
	var fx: int = int(inp["x"]) * facing
	if int(inp["y"]) < 0:
		_jump_dir = fx
		_set_state(State.PREJUMP)
		vel.x = 0.0
		return
	if _dash_request != 0:
		var dir: int = _dash_request
		_dash_request = 0
		_set_state(State.DASH if dir > 0 else State.BACKDASH)
		if dir < 0:
			invuln = int(data.get("backdash_invuln", 6))
		Sfx.play("dash")
		return
	if int(inp["y"]) > 0:
		crouching = true
		vel.x = 0.0
		if state != State.CROUCH:
			_set_state(State.CROUCH)
		return
	crouching = false
	if fx > 0:
		vel.x = float(data.get("walk_forward", 4.0)) * facing
	elif fx < 0:
		vel.x = -float(data.get("walk_back", 3.0)) * facing
	else:
		vel.x = 0.0
	var walking: bool = fx != 0
	if walking and state != State.WALK:
		_set_state(State.WALK)
	elif not walking and state != State.IDLE:
		_set_state(State.IDLE)

func _jump(dir: int) -> void:
	airborne = true
	air_attack_used = false
	air_jumps_left = int(data.get("air_jumps", 0))
	vel = Vector2(dir * facing * float(data.get("jump_forward", 4.5)), -float(data.get("jump_velocity", 15.0)))
	_set_state(State.AIR)
	Sfx.play("jump")

func _air(inp: Dictionary) -> void:
	if not air_attack_used and (pressed("L") or pressed("H")):
		var id: String = "j_h" if pressed("H") else "j_l"
		_consume("L")
		_consume("H")
		air_attack_used = true
		_start_move(id)
		return
	if air_jumps_left > 0 and int(inp["y"]) < 0 and vel.y > -4.0 and state_frame > 6:
		air_jumps_left -= 1
		vel = Vector2(int(inp["x"]) * float(data.get("jump_forward", 4.5)), -float(data.get("jump_velocity", 15.0)) * 0.85)
		state_frame = 0
		Sfx.play("jump", 1.2)
		if match_node != null:
			match_node.call("dust", position + Vector2(0.0, -20.0), 4)

func _dash_step() -> void:
	var forward: bool = state == State.DASH
	var frames: int = int(data.get("dash_frames" if forward else "backdash_frames", 14))
	var speed: float = float(data.get("dash_speed" if forward else "backdash_speed", 9.0))
	var k: float = 1.0 - float(state_frame) / float(frames)
	vel.x = (1.0 if forward else -1.0) * facing * speed * (0.4 + 0.6 * k)
	if state_frame >= frames:
		vel.x = 0.0
		_to_neutral()

# =============================================================================
# ATTACKS
# =============================================================================

## Starts the move asked by the buffered buttons, if allowed. allowed = []
## means any move (neutral state); otherwise only the listed cancels.
func _try_attack(inp: Dictionary, allowed: Array) -> bool:
	var any: bool = allowed.is_empty()
	var fx: int = int(inp["x"]) * toward()
	if pressed("H") and pressed("S") and meter >= 100.0 and (any or allowed.has("super")) and moves.has("super"):
		_consume("H")
		_consume("S")
		meter -= float((moves["super"] as Dictionary).get("cost", 100))
		_start_move("super")
		return true
	if any and pressed("L") and pressed("H") and absi(int(_buf["L"]) - int(_buf["H"])) <= 3:
		_consume("L")
		_consume("H")
		_start_move("throw")
		return true
	if pressed("S") and (any or allowed.has("special")):
		var id: String = "sp_n"
		if int(inp["y"]) > 0:
			id = "sp_d"
		elif fx > 0:
			id = "sp_f"
		elif fx < 0:
			id = "sp_b"
		if moves.has(id) and not (id == "sp_n" and (match_node.call("has_projectile", self) as bool)):
			_consume("S")
			_start_move(id)
			return true
	for button in ["H", "L"]:
		if pressed(button):
			var id2: String = ("cr_" if int(inp["y"]) > 0 else "st_") + button.to_lower()
			if any or allowed.has(id2):
				_consume(button)
				_start_move(id2)
				return true
	return false

func _start_move(id: String) -> void:
	move_id = id
	move = moves[id] as Dictionary
	move_frame = 0
	hits_done = 0
	next_hit = 0
	connected = false
	was_blocked = false
	armor_used = 0
	crouching = bool(move.get("crouching", false))
	if not airborne:
		vel.x = 0.0
		facing = toward()
	_set_state(State.ATTACK)
	meter = minf(meter + float(move.get("meter_gain", 3.0)), 100.0)
	if move.has("superfreeze") and match_node != null:
		match_node.call("super_freeze", self, int(move["superfreeze"]))
	if match_node != null:
		match_node.call("on_attack_started", self, id)

func _attack_step(inp: Dictionary) -> void:
	move_frame += 1
	var s: int = int(move.get("startup", 5))
	var a: int = int(move.get("active", 3))
	var r: int = int(move.get("recovery", 10))
	if move.has("rise") and airborne and move_frame > s + a:
		move_frame = s + a + 1
	var moving: bool = false
	for seg in move.get("move", []) as Array:
		var sg: Array = seg as Array
		if move_frame >= int(sg[0]) and move_frame <= int(sg[1]):
			vel.x = float(sg[2]) * facing
			moving = true
	if not moving and not airborne:
		vel.x = 0.0
	if move_frame == s + 1:
		_on_active_start()
	if (connected or was_blocked) and move_frame <= s + a + CANCEL_WINDOW and move.has("cancel"):
		if _try_attack(inp, move["cancel"] as Array):
			return
	if move_frame >= s + a + r:
		if airborne:
			move_id = ""
			move = {}
			_set_state(State.AIR)
		else:
			_to_neutral()

func _on_active_start() -> void:
	if move.has("rise"):
		var rise: Array = move["rise"] as Array
		vel = Vector2(float(rise[0]) * facing, -float(rise[1]))
		airborne = true
	if move.has("projectile"):
		match_node.call("spawn_projectile", self, move["projectile"])
	if move.has("quake"):
		match_node.call("quake", self, move["quake"])
	if move.has("meter_gain") and move_id == "sp_b":
		meter = minf(meter + float(move["meter_gain"]), 100.0)
	if move.has("damage") or move.has("throw"):
		Sfx.play("whoosh_h" if int(move.get("damage", 0)) >= 70 else "whoosh_l", randf_range(0.95, 1.08))

func phase() -> String:
	if state != State.ATTACK:
		return ""
	var s: int = int(move.get("startup", 5))
	var a: int = int(move.get("active", 3))
	if move_frame <= s:
		return "startup"
	if move_frame <= s + a:
		return "active"
	return "recovery"

func _in_window(window: Variant) -> bool:
	if not (window is Array):
		return false
	var w: Array = window as Array
	return move_frame >= int(w[0]) and move_frame <= int(w[1])

## True when the move's hitbox can touch this frame (multi-hit moves strike
## every hit_every frames, up to "hits" times).
func hitting_now() -> bool:
	if state != State.ATTACK or not move.has("limb") or int(move.get("damage", 0)) <= 0:
		return false
	if phase() != "active":
		return false
	if hits_done >= int(move.get("hits", 1)):
		return false
	return move_frame >= next_hit

func throwing_now() -> bool:
	return state == State.ATTACK and bool(move.get("throw", false)) and move_frame == int(move.get("startup", 4)) + 1

func hitbox_world() -> Rect2:
	if not _hitbox_cache.has(move_id):
		var j: Dictionary = Rig.joints(Poses.get_pose(str((move["poses"] as Array)[1])), style)
		_hitbox_cache[move_id] = Rig.limb_box(j, str(move["limb"]), style, float(move.get("reach", 6.0)))
	return to_world(_hitbox_cache[move_id] as Rect2)

func to_world(r: Rect2) -> Rect2:
	if facing < 0:
		r = Rect2(-r.end.x, r.position.y, r.size.x, r.size.y)
	return Rect2(r.position + position, r.size)

func hurtboxes() -> Array[Rect2]:
	var j: Dictionary = Rig.joints(pose, style)
	var s: float = float(style.get("scale", 1.0))
	var head_r: float = float(style.get("head_r", 16.0)) * s
	var body := Rect2((j["head"] as Vector2) - Vector2(head_r, head_r), Vector2(head_r, head_r) * 2.0)
	for key in ["shoulder", "hip", "knee_f", "knee_b", "foot_f", "foot_b"]:
		body = body.expand(j[key])
	var out: Array[Rect2] = [to_world(body.grow(float(style.get("limb_w", 12.0)) * s * 0.5))]
	if state == State.ATTACK and move.has("limb") and phase() != "startup":
		out.append(to_world(Rig.limb_box(j, str(move["limb"]), style, 0.0)))
	return out

func pushbox_half() -> float:
	return 28.0 * float(style.get("scale", 1.0))

func passes_through() -> bool:
	return state == State.ATTACK and move.has("pass_through") and phase() == "active"

## The hit description handed to the defender, for this hit of the move.
func current_hit() -> Dictionary:
	var hit: Dictionary = move.duplicate()
	var last: bool = hits_done == int(move.get("hits", 1)) - 1
	if last and move.has("finish"):
		var fin: Dictionary = move["finish"] as Dictionary
		hit["damage"] = fin.get("damage", hit.get("damage", 0))
		hit["launch"] = fin.get("launch", [4.0, 9.0])
		hit["knockdown"] = true
	elif int(move.get("hits", 1)) > 1:
		hit.erase("launch")
		hit.erase("knockdown")
	hit["away"] = facing
	return hit

func register_contact(blocked: bool) -> void:
	hits_done += 1
	next_hit = move_frame + int(move.get("hit_every", 99))
	if blocked:
		was_blocked = true
	else:
		connected = true

# =============================================================================
# BEING HIT
# =============================================================================

func can_block() -> bool:
	return not airborne and state in [State.IDLE, State.WALK, State.CROUCH, State.BLOCKSTUN]

func can_be_thrown() -> bool:
	if airborne or invuln > 0:
		return false
	if state in [State.IDLE, State.WALK, State.CROUCH, State.DASH, State.PREJUMP]:
		return true
	return state == State.ATTACK and phase() != "active"

## Result: "none", "block", "armor", "parry", "hit", "counter", "ko".
func receive(attacker: Fighter, hit: Dictionary, from_projectile: bool) -> String:
	if state == State.KO or state == State.KNOCKDOWN or state == State.WAKEUP or invuln > 0:
		return "none"
	if state == State.ATTACK and move.has("counter_stance") and phase() == "active" and not from_projectile:
		return "parry"
	var away: int = int(hit.get("away", -toward()))
	var height: String = str(hit.get("height", "mid"))
	var damage: float = float(hit.get("damage", 0))
	if can_block() and holding_back() and not bool(hit.get("unblockable", false)):
		var crouch: bool = holding_down()
		var ok: bool = height == "mid" or (height == "low" and crouch) or (height == "high" and not crouch)
		if ok:
			stun = int(hit.get("blockstun", 10))
			crouching = crouch
			_set_state(State.BLOCKSTUN)
			hp = maxf(hp - float(hit.get("chip", 0)), 1.0)
			push = float(hit.get("push", 5)) * away
			meter = minf(meter + damage * 0.04, 100.0)
			return "block"
	if state == State.ATTACK and _in_window(move.get("armor")) and armor_used < 2 and not from_projectile:
		armor_used += 1
		hp = maxf(hp - damage * 0.5, 1.0)
		flash = 1.0
		return "armor"
	var counter: bool = state == State.ATTACK and phase() == "startup"
	var scale: float = 1.0
	if combo_hits >= 2:
		scale = maxf(1.0 - 0.12 * (combo_hits - 1), 0.3)
	var dealt: float = damage * scale * (1.25 if counter else 1.0)
	hp -= dealt
	combo_hits += 1
	combo_damage += dealt
	meter = minf(meter + dealt * 0.05, 100.0)
	low_hit = height == "low"
	flash = 1.0
	move_id = ""
	move = {}
	if hp <= 0.0:
		hp = 0.0
		airborne = true
		vel = Vector2(away * 5.0, -10.0)
		_set_state(State.KO)
		return "ko"
	if airborne or hit.has("launch") or bool(hit.get("knockdown", false)):
		var launch: Array = hit.get("launch", [3.0, 6.0]) as Array
		vel = Vector2(away * float(launch[0]), -float(launch[1]))
		airborne = true
		juggle += 1
		if juggle > 3:
			invuln = 90
		_set_state(State.AIR_HIT)
	else:
		stun = int(hit.get("hitstun", 14)) + (6 if counter else 0)
		push = float(hit.get("push", 5)) * away
		_set_state(State.HITSTUN)
	return "counter" if counter else "hit"

func start_thrown(by: Fighter, techable: bool, throw_move: Dictionary) -> void:
	thrown_by = by
	throw_techable = techable
	_throw_move = throw_move
	move_id = ""
	move = {}
	vel = Vector2.ZERO
	push = 0.0
	_set_state(State.THROWN)

func _thrown_step() -> void:
	if thrown_by == null:
		_to_neutral()
		return
	position = thrown_by.position + Vector2(thrown_by.facing * 60.0 * float(thrown_by.style.get("scale", 1.0)), -10.0)
	if throw_techable and state_frame <= TECH_WINDOW and int(_buf["L"]) <= 3 and int(_buf["H"]) <= 3:
		match_node.call("throw_teched", thrown_by, self)
		thrown_by = null
		return
	if state_frame > (TECH_WINDOW if throw_techable else 2):
		var by: Fighter = thrown_by
		thrown_by = null
		match_node.call("throw_land", by, self, _throw_move)

func tech_release(dir: int) -> void:
	position.y = 0.0
	push = dir * 9.0
	stun = 14
	_set_state(State.BLOCKSTUN)

func throw_impact(damage: float, away: int) -> bool:
	hp -= damage
	flash = 1.0
	combo_hits += 1
	combo_damage += damage
	airborne = true
	if hp <= 0.0:
		hp = 0.0
		vel = Vector2(away * 5.0, -10.0)
		_set_state(State.KO)
		return true
	vel = Vector2(away * 4.0, -8.0)
	_set_state(State.AIR_HIT)
	return false

func parried(by: Fighter) -> void:
	hitstop = 0
	stun = 30
	push = -toward() * 3.0
	_set_state(State.HITSTUN)

func win() -> void:
	move_id = ""
	move = {}
	vel = Vector2.ZERO
	if not airborne:
		_set_state(State.VICTORY)

# =============================================================================
# PHYSICS
# =============================================================================

func _physics() -> void:
	if state == State.THROWN:
		return
	position.x += vel.x + push
	push *= 0.8
	if absf(push) < 0.1:
		push = 0.0
	if airborne:
		vel.y += float(data.get("gravity", 0.78)) * (0.85 if state == State.AIR_HIT else 1.0)
		position.y += vel.y
		if position.y >= 0.0 and vel.y > 0.0:
			position.y = 0.0
			_land()
	if match_node != null:
		position.x = match_node.call("clamp_x", position.x) as float

func _land() -> void:
	airborne = false
	var impact: float = vel.y
	vel.y = 0.0
	match state:
		State.AIR:
			vel.x = 0.0
			_to_neutral()
			match_node.call("dust", position, 3)
			Sfx.play("land", 1.0, 0.1, -6.0)
		State.ATTACK:
			if move.has("rise"):
				vel.x = 0.0
				move_frame = int(move.get("startup", 5)) + int(move.get("active", 3)) + 1
			else:
				vel.x = 0.0
				_to_neutral()
		State.AIR_HIT:
			vel.x = 0.0
			_set_state(State.KNOCKDOWN)
			match_node.call("dust", position, 8)
			match_node.call("shake", 0.25)
			Sfx.play("thud", 1.0, 0.08)
		State.KO:
			vel.x *= 0.3
			if impact > 3.0:
				airborne = true
				vel.y = -impact * 0.35
				match_node.call("dust", position, 10)
				Sfx.play("thud", 0.8, 0.05)
			else:
				vel.x = 0.0
		_:
			vel.x = 0.0

# =============================================================================
# ANIMATION
# =============================================================================

func _update_pose() -> void:
	var target: Dictionary
	var k: float = 0.3
	var base_name: String = "crouch" if crouching else "idle"
	match state:
		State.IDLE:
			target = Poses.copy(Poses.get_pose("block" if _guarding_visual() else "idle"))
			target["torso"] = float(target["torso"]) + sin(_time * 3.0) * 0.03
			k = 0.25
		State.WALK:
			target = Poses.copy(Poses.get_pose("block" if _guarding_visual() else "idle"))
			var dirv: float = signf(vel.x) * facing
			var phase_t: float = state_frame * 0.22 * (1.0 if dirv >= 0.0 else -1.0)
			target["th_f"] = float(target["th_f"]) + sin(phase_t) * 0.38
			target["th_b"] = float(target["th_b"]) - sin(phase_t) * 0.38
			target["sh_f"] = float(target["sh_f"]) - maxf(cos(phase_t), 0.0) * 0.5
			target["sh_b"] = float(target["sh_b"]) - maxf(-cos(phase_t), 0.0) * 0.5
			k = 0.4
		State.CROUCH:
			target = Poses.get_pose("crouch_block" if _guarding_visual() else "crouch")
			k = 0.35
		State.PREJUMP:
			target = Poses.blend(Poses.get_pose("idle"), Poses.get_pose("crouch"), 0.55)
			k = 0.6
		State.AIR:
			target = Poses.get_pose("jump" if vel.y < 0.0 else "fall")
			k = 0.25
		State.ATTACK:
			var poses: Array = move.get("poses", ["idle", "idle"]) as Array
			match phase():
				"startup":
					target = Poses.get_pose(str(poses[0]))
					k = 0.5
				"active":
					target = Poses.get_pose(str(poses[1]))
					k = 1.0
				_:
					target = Poses.get_pose("jump" if airborne else base_name)
					k = 0.16
		State.DASH:
			target = Poses.get_pose("dash")
			k = 0.4
		State.BACKDASH:
			target = Poses.get_pose("backdash")
			k = 0.4
		State.BLOCKSTUN:
			target = Poses.get_pose("crouch_block" if crouching else "block")
			k = 0.7
		State.HITSTUN:
			target = Poses.get_pose("hit_low" if low_hit else "hit_high")
			k = 0.7 if state_frame < 4 else 0.15
		State.AIR_HIT, State.THROWN:
			target = Poses.get_pose("air_hit")
			k = 0.4
		State.KNOCKDOWN:
			target = Poses.get_pose("down")
			k = 0.35
		State.WAKEUP:
			target = Poses.get_pose("getup" if state_frame * 2 < WAKEUP_FRAMES else "idle")
			k = 0.25
		State.KO:
			target = Poses.get_pose("ko" if not airborne else "air_hit")
			k = 0.2
		State.VICTORY:
			target = Poses.copy(Poses.get_pose("victory"))
			target["torso"] = float(target["torso"]) + sin(_time * 4.0) * 0.05
			k = 0.12
	pose = Poses.blend(pose, target, k)

## Raise the guard when holding back while the opponent attacks.
func _guarding_visual() -> bool:
	return holding_back() and opponent != null and opponent.state == State.ATTACK

func _process(delta: float) -> void:
	_time += delta
	flash = maxf(flash - delta * 6.0, 0.0)
	queue_redraw()

func _draw() -> void:
	var ground: float = -position.y
	var spread: float = clampf(1.0 - position.y / -300.0, 0.4, 1.0)
	draw_set_transform(Vector2(0.0, ground), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 46.0 * float(style.get("scale", 1.0)) * spread, Color(0.0, 0.0, 0.0, 0.35 * spread))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in range(_trail.size() - 1, -1, -1):
		var t: Dictionary = _trail[i]
		var offset: Vector2 = (t["pos"] as Vector2) - position
		Rig.draw(self, offset, t["pose"] as Dictionary, _ghost_style(), int(t["facing"]), 0.0, 0.25 * (1.0 - float(i) / 5.0), _time)
	if meter >= 100.0 and state != State.KO:
		# Super ready: a soft pulsing halo and sparks rising around the body
		var eye := Color(str(style.get("eye", "ffffff")))
		var sc: float = float(style.get("scale", 1.0))
		Fx.put(self, Fx.glow(), Vector2(0.0, -95.0 * sc), 120.0 * sc, Color(eye, 0.12 + 0.06 * sin(_time * 8.0)))
		for k in 4:
			var phase_k: float = fmod(_time * 0.9 + k * 0.25, 1.0)
			var spark := Vector2(sin(k * 2.1 + _time) * 34.0 * sc, -phase_k * 190.0 * sc)
			draw_circle(spark, 3.0 * (1.0 - phase_k) + 1.0, Color(eye, 1.0 - phase_k))
	var alpha: float = 1.0
	if state == State.WAKEUP or (invuln > 0 and state == State.AIR_HIT):
		alpha = 0.55 + 0.45 * absf(sin(_time * 20.0))
	Rig.draw(self, Vector2.ZERO, pose, style, facing, flash, alpha, _time)

func _ghost_style() -> Dictionary:
	var g: Dictionary = style.duplicate()
	g["body"] = style.get("eye", "ffffff")
	g["dark"] = style.get("eye", "ffffff")
	return g
