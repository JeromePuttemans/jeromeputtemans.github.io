# =============================================================================
# Background.gd — Animated backdrop
# =============================================================================
# A vertical night gradient, slowly rising dust motes that twinkle, and a
# warm glow at the edges while the crystal overheats or erupts.
# =============================================================================

extends Control

const DUST_COUNT: int = 80

var _dust := PackedVector3Array()   # x, y, phase
var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in DUST_COUNT:
		_dust.append(Vector3(randf(), randf(), randf() * TAU))

func _process(delta: float) -> void:
	_time += delta
	for i in _dust.size():
		var mote: Vector3 = _dust[i]
		mote.y -= delta * (0.006 + 0.01 * fmod(mote.z, 1.0))
		if mote.y < -0.02:
			mote = Vector3(randf(), 1.02, randf() * TAU)
		_dust[i] = mote
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([rect.position, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
		PackedColorArray([UiTheme.BG_TOP, UiTheme.BG_TOP, UiTheme.BG_BOTTOM, UiTheme.BG_BOTTOM]))
	for mote in _dust:
		var alpha: float = 0.15 + 0.25 * (0.5 + 0.5 * sin(_time * 1.5 + mote.z))
		var radius: float = 1.0 + fmod(mote.z, 1.5)
		draw_circle(Vector2(mote.x * size.x, mote.y * size.y), radius, Color(0.7, 0.8, 1.0, alpha))
	_draw_boost_glow()

func _draw_boost_glow() -> void:
	var color: Color = Color.TRANSPARENT
	if BoostManager.is_frenzy():
		color = UiTheme.HEAT
	elif BoostManager.eruption_left > 0.0:
		color = UiTheme.GOLD
	if color.a == 0.0:
		return
	var strength: float = 0.18 + 0.08 * sin(_time * 6.0)
	for i in 6:
		var inset: float = i * 10.0
		draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), Color(color, strength * (1.0 - i / 6.0) * 0.5), false, 10.0)
