# FighterVisual.gd [v2]
# Draws a stick figure using _draw().
# Facing is handled via draw_set_transform scale X flip — all draw calls use
# positive coordinates only, which fixes the Rect2 mirroring bug.

class_name FighterVisual
extends Node2D

const BODY_W := 28.0
const BODY_H := 50.0
const HEAD_R := 14.0
const LEG_H  := 36.0
const ARM_W  := 30.0

@export var base_color: Color  = Color(0.2, 0.6, 1.0)
@export var accent_color: Color = Color(1.0, 1.0, 1.0)

var _state: FighterStateMachine.State = FighterStateMachine.State.IDLE
var _facing: int   = 1
var _scale_x: float = 1.0
var _scale_y: float = 1.0
var _anim_time: float = 0.0
var _flash_timer: float = 0.0
var _idle_bob: float = 0.0

const FLASH_DURATION := 0.1

func _process(delta: float) -> void:
	_anim_time  += delta
	_idle_bob    = sin(_anim_time * 4.0) * 2.0
	_scale_x     = lerpf(_scale_x, 1.0, delta * 12.0)
	_scale_y     = lerpf(_scale_y, 1.0, delta * 12.0)
	if _flash_timer > 0.0:
		_flash_timer -= delta
	queue_redraw()

func set_state(state: FighterStateMachine.State, facing: int) -> void:
	_state  = state
	_facing = facing

func flash_hit() -> void:
	_flash_timer = FLASH_DURATION
	_scale_x = 1.35
	_scale_y = 0.75

func squash_attack() -> void:
	_scale_x = 0.75
	_scale_y = 1.3

func _draw() -> void:
	var flash    := _flash_timer > 0.0
	var body_col := Color.WHITE if flash else base_color
	var dark_col := Color.WHITE if flash else base_color.darkened(0.4)

	# KEY FIX: apply facing as a transform scale on X.
	# All draw functions use positive X = "forward" direction.
	# draw_set_transform mirrors the canvas for P2 without changing any coordinates.
	var sx := _scale_x * float(_facing)
	var sy := _scale_y
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))

	match _state:
		FighterStateMachine.State.IDLE, FighterStateMachine.State.WALK:
			_draw_idle(body_col, dark_col)
		FighterStateMachine.State.JUMP:
			_draw_jump(body_col, dark_col)
		FighterStateMachine.State.ATTACK:
			_draw_attack(body_col, dark_col)
		FighterStateMachine.State.BLOCK:
			_draw_block(body_col, dark_col)
		FighterStateMachine.State.HITSTUN, FighterStateMachine.State.BLOCKSTUN:
			_draw_hitstun(body_col, dark_col)
		FighterStateMachine.State.DASH:
			_draw_dash(body_col, dark_col)
		FighterStateMachine.State.KO:
			_draw_ko(body_col, dark_col)
		_:
			_draw_idle(body_col, dark_col)

	# Reset transform so future draws aren't affected
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ── All draw functions use POSITIVE X = forward, Y = down ────────────────────
# The draw_set_transform above handles mirroring for P2.

func _draw_idle(col: Color, dark: Color) -> void:
	var bob := _idle_bob / _scale_y   # compensate for sy already in transform
	# Legs
	draw_line(Vector2(-8,  BODY_H), Vector2(-14, BODY_H + LEG_H + bob), dark, 5.0)
	draw_line(Vector2(8,   BODY_H), Vector2(14,  BODY_H + LEG_H + bob), dark, 5.0)
	# Body
	draw_rect(Rect2(Vector2(-BODY_W * 0.5, 0.0), Vector2(BODY_W, BODY_H)), col)
	# Arms — left arm back, right arm relaxed forward
	draw_line(Vector2(-4, 12 + bob), Vector2(-ARM_W * 0.8, 28 + bob), dark, 5.0)
	draw_line(Vector2(4,  12 + bob), Vector2(ARM_W * 0.7,  26 + bob), dark, 5.0)
	# Head
	draw_circle(Vector2(0, -HEAD_R + bob), HEAD_R, col)
	# Eye (forward side)
	draw_circle(Vector2(5, -HEAD_R + bob), 3.5, dark)

func _draw_jump(col: Color, dark: Color) -> void:
	# Legs tucked
	draw_line(Vector2(-6, BODY_H), Vector2(-16, BODY_H + 16), dark, 5.0)
	draw_line(Vector2(6,  BODY_H), Vector2(16,  BODY_H + 16), dark, 5.0)
	draw_rect(Rect2(Vector2(-BODY_W * 0.5, 0), Vector2(BODY_W, BODY_H)), col)
	# Arms raised
	draw_line(Vector2(-4, 10), Vector2(-ARM_W * 0.8, -10), dark, 5.0)
	draw_line(Vector2(4,  10), Vector2(ARM_W,         -10), dark, 5.0)
	draw_circle(Vector2(0, -HEAD_R), HEAD_R, col)
	draw_circle(Vector2(5, -HEAD_R), 3.5, dark)

func _draw_attack(col: Color, dark: Color) -> void:
	# Legs stable
	draw_line(Vector2(-8, BODY_H), Vector2(-14, BODY_H + LEG_H), dark, 5.0)
	draw_line(Vector2(8,  BODY_H), Vector2(18,  BODY_H + LEG_H), dark, 5.0)
	draw_rect(Rect2(Vector2(-BODY_W * 0.5, 0), Vector2(BODY_W, BODY_H)), col)
	# Back arm pulled back
	draw_line(Vector2(-4, 14), Vector2(-ARM_W * 0.6, 24), dark, 5.0)
	# Front arm EXTENDED toward opponent (positive X = forward)
	draw_line(Vector2(4, 12), Vector2(ARM_W * 1.8, 13), Color.YELLOW, 6.0)
	draw_circle(Vector2(ARM_W * 1.8, 13), 8.0, Color.YELLOW)
	# Head
	draw_circle(Vector2(2, -HEAD_R), HEAD_R, col)
	draw_circle(Vector2(7, -HEAD_R), 3.5, dark)

func _draw_block(col: Color, dark: Color) -> void:
	draw_line(Vector2(-6, BODY_H), Vector2(-10, BODY_H + LEG_H), dark, 5.0)
	draw_line(Vector2(6,  BODY_H), Vector2(10,  BODY_H + LEG_H), dark, 5.0)
	draw_rect(Rect2(Vector2(-BODY_W * 0.5, 6), Vector2(BODY_W, BODY_H * 0.9)), col)
	# Arms crossed in FRONT (positive X)
	draw_line(Vector2(4,  8),  Vector2(BODY_W * 0.9,  26), dark, 6.0)
	draw_line(Vector2(2,  18), Vector2(BODY_W * 0.9,  40), dark, 6.0)
	draw_circle(Vector2(0, -HEAD_R * 0.9 + 6), HEAD_R * 0.9, col)

func _draw_hitstun(col: Color, dark: Color) -> void:
	# Leaning BACK (negative X = away from opponent)
	draw_line(Vector2(-4, BODY_H), Vector2(-18, BODY_H + LEG_H), dark, 5.0)
	draw_line(Vector2(4,  BODY_H), Vector2(8,   BODY_H + LEG_H), dark, 5.0)
	draw_rect(Rect2(Vector2(-BODY_W * 0.6, 0), Vector2(BODY_W, BODY_H)), col)
	# Arms thrown back/up
	draw_line(Vector2(-2, 14), Vector2(-ARM_W,       8), dark, 5.0)
	draw_line(Vector2(2,  14), Vector2(ARM_W * 0.4, 8), dark, 5.0)
	# Head recoiling back
	draw_circle(Vector2(-4, -HEAD_R), HEAD_R, col)
	# X eyes
	draw_line(Vector2(-8, -HEAD_R - 4), Vector2(-1, -HEAD_R + 4), Color.RED, 2.5)
	draw_line(Vector2(-1, -HEAD_R - 4), Vector2(-8, -HEAD_R + 4), Color.RED, 2.5)

func _draw_dash(col: Color, dark: Color) -> void:
	# Low forward lean
	draw_line(Vector2(-4, BODY_H * 0.8), Vector2(-8,  BODY_H * 0.8 + LEG_H * 0.9), dark, 5.0)
	draw_line(Vector2(4,  BODY_H * 0.8), Vector2(18,  BODY_H * 0.8 + LEG_H * 0.9), dark, 5.0)
	draw_rect(Rect2(Vector2(-BODY_W * 0.5, 4), Vector2(BODY_W, BODY_H * 0.8)), col)
	draw_line(Vector2(-2, 10), Vector2(ARM_W,       22), dark, 5.0)
	draw_line(Vector2(2,  10), Vector2(-ARM_W * 0.3, 18), dark, 5.0)
	draw_circle(Vector2(5, -HEAD_R * 0.8 + 4), HEAD_R * 0.85, col)
	# Speed lines trailing BEHIND (negative X)
	for i in range(3):
		var lx := -20.0 - float(i) * 10.0
		var ly := float(i * 14 + 10)
		draw_line(Vector2(lx, ly), Vector2(lx - 16.0, ly), col.lightened(0.4), 2.0)

func _draw_ko(col: Color, dark: Color) -> void:
	# Lying on ground — not affected by facing transform (reset separately)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_scale_x, _scale_y))
	draw_line(Vector2(-40, 0), Vector2(40, 0), dark, 7.0)
	draw_circle(Vector2(46, -8), HEAD_R * 0.9, col)
	draw_line(Vector2(-12, 0), Vector2(-26, -18), dark, 4.0)
	draw_line(Vector2(12,  0), Vector2(28,  -16), dark, 4.0)
	draw_line(Vector2(-18, 0), Vector2(-30,  18), dark, 4.0)
	draw_line(Vector2(18,  0), Vector2(34,   16), dark, 4.0)
	for i in range(3):
		var angle := _anim_time * 2.0 + float(i) * TAU / 3.0
		draw_circle(Vector2(46, -8) + Vector2(cos(angle), sin(angle)) * 22.0, 4.0, Color.YELLOW)
