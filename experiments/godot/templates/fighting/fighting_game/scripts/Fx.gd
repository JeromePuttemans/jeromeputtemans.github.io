# =============================================================================
# Fx.gd — Glow texture generated once, shared by effects and projectiles
# =============================================================================
# Particles are drawn as textured quads with one shared white texture: the
# renderer batches them, and the colour comes from the modulate argument.
# =============================================================================

class_name Fx
extends RefCounted

const SIZE: int = 64

static var _glow: Texture2D = null

static func glow() -> Texture2D:
	if _glow == null:
		var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		var half: float = SIZE * 0.5
		for y in SIZE:
			for x in SIZE:
				var d: float = Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(clampf(1.0 - d, 0.0, 1.0), 2.0)))
		_glow = ImageTexture.create_from_image(image)
	return _glow

static func put(canvas: CanvasItem, texture: Texture2D, at: Vector2, radius: float, color: Color) -> void:
	canvas.draw_texture_rect(texture, Rect2(at.x - radius, at.y - radius, radius * 2.0, radius * 2.0), false, color)
