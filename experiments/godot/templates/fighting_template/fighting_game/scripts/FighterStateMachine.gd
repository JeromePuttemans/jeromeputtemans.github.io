# FighterStateMachine.gd
# Finite State Machine for a fighting game character.
#
# PATTERN: Explicit enum-based FSM.
# WHY: Fighting games require frame-perfect state transitions and strict
#      priority rules (e.g., hitstun > attack > jump). An enum FSM makes
#      illegal transitions visible and auditable — critical for gameplay feel.
#
# STATES:
#   IDLE       → default grounded state
#   WALK       → horizontal movement on ground
#   JUMP       → airborne (single jump only)
#   ATTACK     → startup / active / recovery frames
#   BLOCK      → grounded defensive stance
#   HITSTUN    → cannot act (took a hit)
#   BLOCKSTUN  → brief freeze after blocking
#   DASH       → quick burst forward/backward
#   KO         → match over for this fighter

class_name FighterStateMachine
extends RefCounted

enum State {
	IDLE,
	WALK,
	JUMP,
	ATTACK,
	BLOCK,
	HITSTUN,
	BLOCKSTUN,
	DASH,
	KO
}

signal state_changed(old_state: State, new_state: State)

var current: State = State.IDLE
var _owner_name: String  # for debug logs only

func _init(owner_name: String) -> void:
	_owner_name = owner_name

# Attempt a transition; returns true when allowed.
func transition_to(new_state: State) -> bool:
	if new_state == current:
		return false

	# Guard: KO is a terminal state — no exit
	if current == State.KO:
		return false

	# Guard: Hitstun / blockstun can only exit to IDLE (enforced by timer in Fighter)
	if current in [State.HITSTUN, State.BLOCKSTUN] and new_state != State.IDLE:
		return false

	var old := current
	current = new_state
	state_changed.emit(old, new_state)
	return true

func is_actionable() -> bool:
	return current in [State.IDLE, State.WALK, State.JUMP]

func is_grounded() -> bool:
	return current in [State.IDLE, State.WALK, State.BLOCK, State.DASH]

func is_attacking() -> bool:
	return current == State.ATTACK
