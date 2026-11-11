# =============================================================================
# Tex.gd — Small textures generated once at startup
# =============================================================================
# Hundreds of bullets and particles are drawn every frame. Drawing them as
# textured quads (draw_texture_rect) with the same texture lets the canvas
# renderer batch them into a few draw calls, where hundreds of draw_circle
# would each build a polygon. The textures are white: the colour comes from
# the modulate argument.
#   disc()   solid disc with a 1-2 px soft edge (bullet body, gems)
#   glow()   radial falloff, (1 - d)^2 (halos, sparks, stars)
#   ring()   thin ring with soft edges (graze circle, shockwaves)
# =============================================================================

class_name Tex
extends RefCounted

const SIZE: int = 64

static var _disc: Texture2D = null
static var _glow: Texture2D = null
static var _ring: Texture2D = null

static func disc() -> Texture2D:
	if _disc == null:
		_disc = _make(func(d: float) -> float: return clampf((1.0 - d) * SIZE * 0.25, 0.0, 1.0))
	return _disc

static func glow() -> Texture2D:
	if _glow == null:
		_glow = _make(func(d: float) -> float: return pow(clampf(1.0 - d, 0.0, 1.0), 2.0))
	return _glow

static func ring() -> Texture2D:
	if _ring == null:
		_ring = _make(func(d: float) -> float: return clampf(1.0 - absf(d - 0.9) * SIZE * 0.3, 0.0, 1.0))
	return _ring

static func _make(alpha_of: Callable) -> Texture2D:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var half: float = SIZE * 0.5
	for y in SIZE:
		for x in SIZE:
			var d: float = Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, float(alpha_of.call(d))))
	return ImageTexture.create_from_image(image)

## Draws texture centred on at with the given radius.
static func put(canvas: CanvasItem, texture: Texture2D, at: Vector2, radius: float, color: Color) -> void:
	canvas.draw_texture_rect(texture, Rect2(at.x - radius, at.y - radius, radius * 2.0, radius * 2.0), false, color)
