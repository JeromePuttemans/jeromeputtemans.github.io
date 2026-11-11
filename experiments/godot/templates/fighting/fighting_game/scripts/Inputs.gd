# =============================================================================
# Inputs.gd — Input sources of a fighter: keyboard or pad, training dummy
# =============================================================================
# Every source answers poll(fighter) once per frame with
#   {x: -1/0/1, y: -1 (up) / 0 / 1 (down), L, H, S: pressed this frame,
#    hL, hH, hS: held}
# Presses are detected as an edge of the held state between two polls:
# the same rule for keys, pad buttons and simulated input.
# =============================================================================

class_name Inputs
extends RefCounted

## A human player reading the actions prefix + left/right/up/down/light/heavy/special.
class Human extends RefCounted:
	var prefix: String = "p1_"
	var _prev: Dictionary = {L = false, H = false, S = false}

	func _init(action_prefix: String) -> void:
		prefix = action_prefix

	func poll(_f: Fighter) -> Dictionary:
		var x: int = 0
		if Input.is_action_pressed(prefix + "left"):
			x -= 1
		if Input.is_action_pressed(prefix + "right"):
			x += 1
		var y: int = 0
		if Input.is_action_pressed(prefix + "up"):
			y -= 1
		if Input.is_action_pressed(prefix + "down"):
			y += 1
		var out: Dictionary = {x = x, y = y}
		for pair in [["L", "light"], ["H", "heavy"], ["S", "special"]]:
			var held: bool = Input.is_action_pressed(prefix + str(pair[1]))
			out[pair[0]] = held and not bool(_prev[pair[0]])
			out["h" + str(pair[0])] = held
			_prev[pair[0]] = held
		return out

## Training dummy: stands, blocks every attack (crouching against lows),
## blocks one attack out of two, or jumps in place.
class Dummy extends RefCounted:
	var mode: String = "stand"
	var _frame: int = 0
	var _block_this: bool = true
	var _last_serial: String = ""

	func poll(f: Fighter) -> Dictionary:
		_frame += 1
		var out: Dictionary = {x = 0, y = 0, L = false, H = false, S = false, hL = false, hH = false, hS = false}
		var opp: Fighter = f.opponent
		var attacking: bool = opp.state == Fighter.State.ATTACK or f.state == Fighter.State.BLOCKSTUN
		match mode:
			"block", "random":
				if opp.state == Fighter.State.ATTACK:
					var serial: String = "%s_%d" % [opp.move_id, opp.state_frame - opp.move_frame]
					if serial != _last_serial:
						_last_serial = serial
						_block_this = mode == "block" or randf() < 0.5
				if attacking and _block_this:
					out["x"] = -f.toward()
					out["y"] = 1 if str(opp.move.get("height", "mid")) == "low" else 0
			"crouch":
				out["y"] = 1
			"jump":
				out["y"] = -1 if _frame % 50 < 3 else 0
		return out
