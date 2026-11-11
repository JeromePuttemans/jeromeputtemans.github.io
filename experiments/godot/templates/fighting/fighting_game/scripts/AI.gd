# =============================================================================
# AI.gd — Computer opponent with human-like reaction time
# =============================================================================
# The AI sees the opponent as it was "reaction" frames ago (a history of
# snapshots), never its future inputs. Each decision about an event is
# drawn once (one roll per opponent attack, per jump, per opening), so a
# 60 % block chance really blocks 60 % of the attacks.
#   defence     block the attacks it sees coming (crouching for lows)
#   anti-air    answer a jump-in with its rising special or a heavy
#   punish      hit an opponent stuck in the recovery of a move
#   combos      after a hit that connected, cancel light -> heavy ->
#               special, or into the super when the gauge is full
#   neutral     intentions held for a while: approach, back off, wait,
#               projectile at range, poke at mid range, jab or throw up
#               close, jump in now and then
# Levels (data/config.json "ai"): reaction frames and the chance of each
# behaviour.
# =============================================================================

class_name AIInput
extends RefCounted

var level: Dictionary = {}
var _history: Array[Dictionary] = []
var _serial: int = 0
var _block_serial: int = -1
var _block_now: bool = false
var _aa_serial: int = -1
var _punish_serial: int = -1
var _combo_move: int = -1
var _combo_go: bool = false
var _move_serial: int = 0
var _intent: String = "wait"
var _intent_frames: int = 0
var _jump_serial: int = 0
var _prev: Dictionary = {}
var _pending: Array[Dictionary] = []

func _init(params: Dictionary) -> void:
	level = params

func _blank() -> Dictionary:
	return {x = 0, y = 0, L = false, H = false, S = false, hL = false, hH = false, hS = false}

func _snap(o: Fighter) -> Dictionary:
	var height: String = str(o.move.get("height", "mid")) if o.state == Fighter.State.ATTACK else ""
	var reach: float = 0.0
	if o.state == Fighter.State.ATTACK and o.move.has("limb"):
		reach = absf(o.hitbox_world().get_center().x - o.position.x) + 50.0
	return {state = o.state, move = o.move_id, phase = o.phase(), frame = o.move_frame, x = o.position.x, y = o.position.y, vy = o.vel.y, airborne = o.airborne, height = height, reach = reach}

func poll(me: Fighter) -> Dictionary:
	var opp: Fighter = me.opponent
	var now: Dictionary = _snap(opp)
	if not _history.is_empty():
		var last: Dictionary = _history[_history.size() - 1]
		if now["state"] == Fighter.State.ATTACK and (last["state"] != Fighter.State.ATTACK or int(now["frame"]) < int(last["frame"])):
			_serial += 1
		if bool(now["airborne"]) and not bool(last["airborne"]):
			_jump_serial += 1
	_history.push_back(now)
	if _history.size() > 40:
		_history.pop_front()
	var reaction: int = int(level.get("reaction", 12))
	var seen: Dictionary = _history[maxi(_history.size() - 1 - reaction, 0)]
	if me.state == Fighter.State.ATTACK and me.move_frame <= 1:
		_move_serial += 1
	var out: Dictionary = _decide(me, opp, seen)
	return _edges(out)

## Turns "button wanted this frame" into a press only when it was not held
## the frame before, like a real button.
func _edges(out: Dictionary) -> Dictionary:
	for b in ["L", "H", "S"]:
		var want: bool = bool(out[b])
		out[b] = want and not bool(_prev.get(b, false))
		out["h" + b] = want
		_prev[b] = want
	return out

func _decide(me: Fighter, opp: Fighter, seen: Dictionary) -> Dictionary:
	var out: Dictionary = _blank()
	var t: int = me.toward()
	var dist: float = absf(opp.position.x - me.position.x)
	if not _pending.is_empty():
		var queued: Dictionary = _pending.pop_front()
		for key in queued:
			out[key] = queued[key]
		return out
	match me.state:
		Fighter.State.ATTACK:
			_combo(me, out)
			return out
		Fighter.State.BLOCKSTUN:
			out["x"] = -t
			out["y"] = 1 if str(seen["height"]) == "low" else 0
			return out
		Fighter.State.AIR:
			if dist < 130.0 and me.vel.y > 0.0 and me.position.y < -60.0 and randf() < 0.15:
				out["H"] = true
			return out
		Fighter.State.IDLE, Fighter.State.WALK, Fighter.State.CROUCH:
			pass
		_:
			return out
	# A ground quake cannot be blocked: jump over it
	if seen["state"] == Fighter.State.ATTACK and str(seen["phase"]) == "startup" and opp.move.has("quake"):
		if _block_serial != -200 - _serial:
			_block_serial = -200 - _serial
			_block_now = randf() < float(level.get("anti_air", 0.5))
		if _block_now:
			out["y"] = -1
			return out
	# Defence against an attack seen coming
	if seen["state"] == Fighter.State.ATTACK and str(seen["phase"]) != "recovery" and dist < float(seen["reach"]) + 70.0:
		if _block_serial != _serial:
			_block_serial = _serial
			_block_now = randf() < float(level.get("block", 0.6))
		if _block_now:
			out["x"] = -t
			out["y"] = 1 if str(seen["height"]) == "low" else 0
			return out
	if _incoming_projectile(me, opp):
		if _block_serial != -100 - _serial:
			_block_serial = -100 - _serial
			_block_now = randf() < float(level.get("block", 0.6))
		if _block_now:
			out["x"] = -t
			out["y"] = 1 if _projectile_low(opp) else 0
			return out
	# Anti-air
	if bool(seen["airborne"]) and float(seen["y"]) < -50.0 and dist < 240.0 and opp.state in [Fighter.State.AIR, Fighter.State.ATTACK]:
		if _aa_serial != _jump_serial:
			_aa_serial = _jump_serial
			if randf() < float(level.get("anti_air", 0.5)):
				if me.moves.has("sp_d") and not me.moves["sp_d"].has("throw"):
					out["y"] = 1
					out["S"] = true
				else:
					out["H"] = true
				return out
	# Punish a move in recovery
	if seen["state"] == Fighter.State.ATTACK and str(seen["phase"]) == "recovery" and dist < 210.0:
		if _punish_serial != _serial:
			_punish_serial = _serial
			if randf() < float(level.get("punish", 0.5)):
				if me.meter >= 100.0 and randf() < 0.4:
					out["H"] = true
					out["S"] = true
				else:
					out["x"] = t
					out["H"] = true
				return out
	return _neutral(me, opp, dist, t, out)

func _neutral(me: Fighter, opp: Fighter, dist: float, t: int, out: Dictionary) -> Dictionary:
	_intent_frames -= 1
	if _intent_frames <= 0:
		_choose_intent(me, opp, dist)
	match _intent:
		"approach":
			out["x"] = t
		"retreat":
			out["x"] = -t
		"crouch":
			out["y"] = 1
			out["x"] = -t if randf() < 0.5 else 0
		"projectile":
			out["S"] = true
			_intent_frames = 0
		"poke":
			if dist < 260.0:
				if randf() < 0.5:
					out["y"] = 1
				out["H"] = true
				_intent_frames = 0
			else:
				out["x"] = t
		"jab":
			if dist < 150.0:
				if randf() < 0.4:
					out["y"] = 1
				out["L"] = true
				_intent_frames = 0
			else:
				out["x"] = t
		"throw":
			if dist < 85.0:
				out["L"] = true
				out["H"] = true
				_intent_frames = 0
			else:
				out["x"] = t
		"rush":
			out["x"] = t
			out["S"] = true
			_intent_frames = 0
		"jump":
			out["y"] = -1
			out["x"] = t
			_intent_frames = 0
		"dash":
			# Double tap toward the opponent: press, release, press
			out["x"] = t
			_pending = [{x = 0}, {x = t}]
			_intent_frames = 0
	return out

func _choose_intent(me: Fighter, opp: Fighter, dist: float) -> void:
	var aggr: float = float(level.get("aggression", 0.5))
	var r: float = randf()
	if dist > 480.0:
		if r < float(level.get("special", 0.4)) * 0.6 and me.moves.has("sp_n") and me.moves["sp_n"].has("projectile"):
			_set_intent("projectile", 1)
		elif r < 0.75:
			_set_intent("approach", randi_range(15, 40))
		else:
			_set_intent("dash", 3)
	elif dist > 200.0:
		if r < aggr * 0.35:
			_set_intent("poke", randi_range(10, 25))
		elif r < aggr * 0.5:
			_set_intent("jump", 1)
		elif r < aggr * 0.5 + float(level.get("special", 0.4)) * 0.25:
			if me.moves.has("sp_n") and me.moves["sp_n"].has("projectile") and randf() < 0.5:
				_set_intent("projectile", 1)
			else:
				_set_intent("rush", 1)
		elif r < 0.85:
			_set_intent("approach", randi_range(10, 30))
		else:
			_set_intent("retreat", randi_range(8, 20))
	else:
		if r < float(level.get("throw", 0.2)):
			_set_intent("throw", 12)
		elif r < aggr:
			_set_intent("jab", 10)
		elif r < aggr + 0.15:
			_set_intent("crouch", randi_range(10, 25))
		else:
			_set_intent("retreat", randi_range(8, 18))

func _set_intent(intent: String, frames: int) -> void:
	_intent = intent
	_intent_frames = frames

func _combo(me: Fighter, out: Dictionary) -> void:
	if not me.connected or not me.move.has("cancel"):
		return
	if _combo_move != _move_serial:
		_combo_move = _move_serial
		_combo_go = randf() < float(level.get("combo", 0.6))
	if not _combo_go:
		return
	var cancels: Array = me.move["cancel"] as Array
	if cancels.has("super") and me.meter >= 100.0 and randf() < 0.5:
		out["H"] = true
		out["S"] = true
		return
	if me.move_id in ["st_l", "cr_l"] and cancels.has("st_h"):
		out["H"] = true
		if me.move_id == "cr_l" and cancels.has("cr_h") and randf() < 0.4:
			out["y"] = 1
		return
	if cancels.has("special"):
		var r: float = randf()
		if r < 0.5 and me.moves.has("sp_f"):
			out["x"] = me.facing
		elif r < 0.75 and me.moves.has("sp_d") and not me.moves["sp_d"].has("throw"):
			out["y"] = 1
		out["S"] = true

func _incoming_projectile(me: Fighter, opp: Fighter) -> bool:
	var m: Node = me.match_node
	for p in m.get("projectiles") as Array:
		var pr: Projectile = p as Projectile
		if pr.owner_fighter == opp and not pr.dead and signf(me.position.x - pr.position.x) == float(pr.dir) and absf(me.position.x - pr.position.x) < 260.0:
			return true
	return false

func _projectile_low(opp: Fighter) -> bool:
	for p in opp.match_node.get("projectiles") as Array:
		var pr: Projectile = p as Projectile
		if pr.owner_fighter == opp and str(pr.data.get("height", "mid")) == "low":
			return true
	return false
