# =============================================================================
# Items.gd — Gems, shards and power-ups, in packed arrays
# =============================================================================
# GEM    dropped by destroyed enemies, worth gem_value x chain
# SHARD  what a cancelled bullet becomes, worth shard_value x chain
# POWER  raises the weapon level (worth power_bonus points at the maximum)
# BOMB   one more bomb          LIFE   one more life
# An item pops up, then falls slowly. It is pulled toward the ship when the
# ship is within magnet_radius (wider in focus mode), when the ship is above
# the collect line (top of the field), or during an "attract all" period
# (bomb, broken boss phase).
# =============================================================================

class_name Items
extends Node2D

enum Kind { GEM, SHARD, POWER, BOMB, LIFE }

var field := Vector2(540.0, 720.0)
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _kind := PackedInt32Array()
var _magnet := PackedByteArray()
var _age := PackedFloat32Array()
var _font: Font = null

func _ready() -> void:
	_font = ThemeDB.fallback_font

func count() -> int:
	return _pos.size()

func spawn(at: Vector2, kind: int, spread: float = 1.0) -> void:
	_pos.append(at)
	_vel.append(Vector2(randf_range(-70.0, 70.0) * spread, randf_range(-170.0, -60.0) * (0.4 + 0.6 * spread)))
	_kind.append(kind)
	_magnet.append(0)
	_age.append(0.0)

## Moves the items and returns the ones collected: [{kind, at}].
func step(delta: float, ship: Vector2, ship_alive: bool, magnet_radius: float, collect_line: float, attract_all: bool) -> Array[Dictionary]:
	var collected: Array[Dictionary] = []
	var i: int = 0
	while i < _pos.size():
		_age[i] = _age[i] + delta
		var p: Vector2 = _pos[i]
		if ship_alive and _magnet[i] == 0 and _age[i] > 0.25:
			if attract_all or ship.y < collect_line or p.distance_squared_to(ship) < magnet_radius * magnet_radius:
				_magnet[i] = 1
		var v: Vector2 = _vel[i]
		if _magnet[i] == 1 and ship_alive:
			var speed: float = maxf(v.length(), 300.0) + 1400.0 * delta
			v = (ship - p).normalized() * minf(speed, 900.0)
		else:
			v.y = move_toward(v.y, 110.0, 280.0 * delta)
			v.x *= 1.0 - minf(2.5 * delta, 1.0)
		p += v * delta
		_vel[i] = v
		_pos[i] = p
		if ship_alive and p.distance_squared_to(ship) < 22.0 * 22.0:
			collected.append({kind = _kind[i], at = p})
			_remove(i)
			continue
		if p.y > field.y + 24.0:
			_remove(i)
			continue
		i += 1
	queue_redraw()
	return collected

func clear() -> void:
	_pos.resize(0)
	_vel.resize(0)
	_kind.resize(0)
	_magnet.resize(0)
	_age.resize(0)

func _remove(i: int) -> void:
	var last: int = _pos.size() - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_kind[i] = _kind[last]
		_magnet[i] = _magnet[last]
		_age[i] = _age[last]
	_pos.resize(last)
	_vel.resize(last)
	_kind.resize(last)
	_magnet.resize(last)
	_age.resize(last)

func _draw() -> void:
	var glow: Texture2D = Tex.glow()
	for i in _pos.size():
		var p: Vector2 = _pos[i]
		match _kind[i]:
			Kind.GEM:
				Tex.put(self, glow, p, 13.0, Color(1.0, 0.85, 0.3, 0.45))
				_diamond(p, 6.0, _age[i] * 5.0, Color("ffd34d"), Color("fff6c8"))
			Kind.SHARD:
				Tex.put(self, glow, p, 8.0, Color(0.5, 0.85, 1.0, 0.4))
				_diamond(p, 3.6, _age[i] * 7.0, Color("8fd9ff"), Color(1, 1, 1))
			Kind.POWER:
				_capsule(p, Color("ff4f6a"), "P")
			Kind.BOMB:
				_capsule(p, Color("4fd27a"), "B")
			Kind.LIFE:
				_capsule(p, Color("ff7ad9"), "1UP")

func _diamond(p: Vector2, r: float, spin: float, color: Color, light: Color) -> void:
	var w: float = r * absf(cos(spin))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 1.3), p + Vector2(maxf(w, 1.0), 0), p + Vector2(0, r * 1.3), p + Vector2(-maxf(w, 1.0), 0)]), color)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 1.3), p + Vector2(maxf(w, 1.0) * 0.5, -r * 0.2), p + Vector2(0, 0)]), light)

func _capsule(p: Vector2, color: Color, text: String) -> void:
	Tex.put(self, Tex.glow(), p, 22.0, Color(color, 0.5))
	var w: float = 26.0 if text.length() > 1 else 18.0
	draw_rect(Rect2(p - Vector2(w * 0.5, 9.0), Vector2(w, 18.0)), color.darkened(0.4))
	draw_rect(Rect2(p - Vector2(w * 0.5 - 2.0, 7.0), Vector2(w - 4.0, 14.0)), color)
	var size: int = 12 if text.length() > 1 else 14
	var tw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, p + Vector2(-tw * 0.5, 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)
