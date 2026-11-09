# =============================================================================
# PlayerArt.gd — Draws Brindille, the leaf spirit, on any CanvasItem
# =============================================================================
# Shared by the Player node and the menus. The pose is a dictionary:
#   scale (Vector2)   squash and stretch, anchored at the feet
#   angle (float)     lean plus double-jump spin, around the body centre
#   facing (int)      -1 or 1
#   look (Vector2)    pupil offset, follows the velocity
#   blink (float)     0 = open, 1 = closed
#   run (float)       running phase, moves the feet
#   air (bool)        feet tucked under the body
#   leaf (float)      sprout angle, lags behind the movement
#   alpha (float)
# The origin is the bottom centre (the feet), the body is 32 px tall.
# =============================================================================

class_name PlayerArt
extends RefCounted

const BODY: Color = Color("8fd14f")
const SHADE: Color = Color("62a83b")
const BELLY: Color = Color("d2f19a")
const OUTLINE: Color = Color("22401a")
const LEAF: Color = Color("4fb534")
const LEAF_VEIN: Color = Color("2c6e20")
const CHEEK: Color = Color(0.95, 0.5, 0.5, 0.55)
const PUPIL: Color = Color("1a2a12")
const RX: float = 15.0
const RY: float = 16.0

static func default_pose() -> Dictionary:
	return {scale = Vector2.ONE, angle = 0.0, facing = 1, look = Vector2.ZERO, blink = 0.0, run = 0.0, air = false, leaf = 0.0, alpha = 1.0}

static func draw(canvas: CanvasItem, origin: Vector2, pose: Dictionary, size: float = 1.0) -> void:
	var s: Vector2 = (pose.get("scale", Vector2.ONE) as Vector2) * size
	var alpha: float = float(pose.get("alpha", 1.0))
	var facing: int = int(pose.get("facing", 1))
	var center: Vector2 = origin + Vector2(0.0, -RY * s.y)
	canvas.draw_set_transform(center, float(pose.get("angle", 0.0)), s)
	_draw_feet(canvas, pose, alpha)
	_draw_leaves(canvas, float(pose.get("leaf", 0.0)), alpha)
	ellipse(canvas, Vector2.ZERO, RX + 1.6, RY + 1.6, Color(OUTLINE, alpha))
	ellipse(canvas, Vector2.ZERO, RX, RY, Color(SHADE, alpha))
	ellipse(canvas, Vector2(0.0, -2.0), RX - 1.0, RY - 3.0, Color(BODY, alpha))
	ellipse(canvas, Vector2(facing * 3.0, 6.0), 8.0, 6.5, Color(BELLY, alpha * 0.85))
	ellipse(canvas, Vector2(-facing * 6.0, -9.0), 3.5, 2.2, Color(1.0, 1.0, 1.0, alpha * 0.35))
	_draw_face(canvas, pose, facing, alpha)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _draw_feet(canvas: CanvasItem, pose: Dictionary, alpha: float) -> void:
	var color := Color(OUTLINE, alpha)
	if bool(pose.get("air", false)):
		ellipse(canvas, Vector2(-6.0, RY - 3.0), 4.5, 3.5, color)
		ellipse(canvas, Vector2(6.0, RY - 3.0), 4.5, 3.5, color)
		return
	var run: float = float(pose.get("run", 0.0))
	var stride: float = sin(run) * 4.0
	var lift: float = maxf(cos(run), 0.0) * 2.5
	ellipse(canvas, Vector2(-6.0 + stride, RY - lift * 0.5), 5.0, 3.5, color)
	ellipse(canvas, Vector2(6.0 - stride, RY - (2.5 - lift) * 0.5), 5.0, 3.5, color)

static func _draw_leaves(canvas: CanvasItem, angle: float, alpha: float) -> void:
	var root := Vector2(0.0, -RY + 1.0)
	canvas.draw_line(root, root + Vector2(0.0, -5.0).rotated(angle), Color(LEAF_VEIN, alpha), 2.0)
	var tip: Vector2 = root + Vector2(0.0, -5.0).rotated(angle)
	_leaf(canvas, tip, angle - 0.9, 11.0, alpha)
	_leaf(canvas, tip, angle + 0.75, 8.0, alpha)

static func _leaf(canvas: CanvasItem, base: Vector2, angle: float, length: float, alpha: float) -> void:
	var dir := Vector2(0.0, -1.0).rotated(angle)
	var side := Vector2(dir.y, -dir.x)
	var points := PackedVector2Array()
	for i in 9:
		var t: float = float(i) / 8.0
		points.append(base + dir * length * t + side * sin(t * PI) * length * 0.32)
	for i in range(7, 0, -1):
		var t: float = float(i) / 8.0
		points.append(base + dir * length * t - side * sin(t * PI) * length * 0.32)
	canvas.draw_colored_polygon(points, Color(LEAF, alpha))
	canvas.draw_line(base, base + dir * length * 0.85, Color(LEAF_VEIN, alpha * 0.8), 1.2)

static func _draw_face(canvas: CanvasItem, pose: Dictionary, facing: int, alpha: float) -> void:
	var look: Vector2 = pose.get("look", Vector2.ZERO) as Vector2
	var blink: float = clampf(float(pose.get("blink", 0.0)), 0.0, 1.0)
	var eye_y: float = -3.0
	for side in [-1, 1]:
		var eye := Vector2(facing * 3.0 + side * 5.5, eye_y)
		var height: float = 5.2 * (1.0 - blink) + 0.6
		ellipse(canvas, eye, 3.6, height, Color(1.0, 1.0, 1.0, alpha))
		if blink < 0.7:
			ellipse(canvas, eye + look + Vector2(facing * 0.8, 0.6), 2.1, minf(2.9, height), Color(PUPIL, alpha))
			canvas.draw_circle(eye + look + Vector2(facing * 0.2 - 0.6, -1.2), 0.8, Color(1.0, 1.0, 1.0, alpha))
	ellipse(canvas, Vector2(facing * 3.0 - 10.0, 3.5), 2.6, 1.6, Color(CHEEK, CHEEK.a * alpha))
	ellipse(canvas, Vector2(facing * 3.0 + 10.0, 3.5), 2.6, 1.6, Color(CHEEK, CHEEK.a * alpha))

static func ellipse(canvas: CanvasItem, center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	var count: int = 20
	for i in count:
		var a: float = TAU * float(i) / float(count)
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	canvas.draw_colored_polygon(points, color)
