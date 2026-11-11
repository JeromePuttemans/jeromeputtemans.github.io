# =============================================================================
# Rig.gd — Skeleton of an automaton: joint positions and drawing
# =============================================================================
# joints() turns a pose (Poses.gd) and a style (proportions from
# data/fighters.json) into joint positions, in local coordinates: origin
# at the feet, x forward (facing right), y down. Each limb hangs from its
# parent joint: elbow = shoulder + down(upper arm angle) x upper length,
# hand = elbow + down(upper + forearm angle) x forearm length, same for
# legs. The hip is lowered until the lower foot touches the floor.
# The same joints feed the drawing AND the hitboxes (Fighter.gd), so a
# punch hits exactly where the fist is drawn.
# =============================================================================

class_name Rig
extends RefCounted

static func down(angle: float) -> Vector2:
	return Vector2(sin(angle), cos(angle))

static func joints(pose: Dictionary, style: Dictionary) -> Dictionary:
	var s: float = float(style.get("scale", 1.0))
	var thigh: float = float(style.get("thigh", 44.0)) * s
	var shin: float = float(style.get("shin", 44.0)) * s
	var torso: float = float(style.get("torso", 56.0)) * s
	var upper: float = float(style.get("upper", 30.0)) * s
	var fore: float = float(style.get("fore", 30.0)) * s
	var th_f: float = pose["th_f"]
	var th_b: float = pose["th_b"]
	var drop_f: float = thigh * cos(th_f) + shin * cos(th_f + float(pose["sh_f"]))
	var drop_b: float = thigh * cos(th_b) + shin * cos(th_b + float(pose["sh_b"]))
	var hip_h: float = maxf(maxf(drop_f, drop_b), 10.0 * s) + float(pose["lift"]) * s
	var hip := Vector2(float(pose["hx"]) * s, -hip_h)
	var t: float = pose["torso"]
	var shoulder: Vector2 = hip + Vector2(sin(t), -cos(t)) * torso
	var head_angle: float = t + float(pose["head"])
	var head: Vector2 = shoulder + Vector2(sin(head_angle), -cos(head_angle)) * float(style.get("neck", 22.0)) * s
	var j: Dictionary = {hip = hip, shoulder = shoulder, head = head}
	j["elbow_f"] = shoulder + down(pose["ua_f"]) * upper
	j["hand_f"] = j["elbow_f"] + down(float(pose["ua_f"]) + float(pose["fa_f"])) * fore
	j["elbow_b"] = shoulder + down(pose["ua_b"]) * upper
	j["hand_b"] = j["elbow_b"] + down(float(pose["ua_b"]) + float(pose["fa_b"])) * fore
	j["knee_f"] = hip + down(th_f) * thigh
	j["foot_f"] = j["knee_f"] + down(th_f + float(pose["sh_f"])) * shin
	j["knee_b"] = hip + down(th_b) * thigh
	j["foot_b"] = j["knee_b"] + down(th_b + float(pose["sh_b"])) * shin
	return j

## Box around the distal segment of a limb: "fist_f", "fist_b", "foot_f",
## "foot_b" or "body". Used for hitboxes and extended hurtboxes.
static func limb_box(j: Dictionary, limb: String, style: Dictionary, reach: float) -> Rect2:
	var s: float = float(style.get("scale", 1.0))
	var w: float = float(style.get("limb_w", 12.0)) * s
	var a: Vector2
	var b: Vector2
	match limb:
		"fist_f":
			a = j["elbow_f"]
			b = j["hand_f"]
		"fist_b":
			a = j["elbow_b"]
			b = j["hand_b"]
		"foot_f":
			a = j["knee_f"]
			b = j["foot_f"]
		"foot_b":
			a = j["knee_b"]
			b = j["foot_b"]
		_:
			a = j["hip"]
			b = j["head"]
	var tip: Vector2 = b + (b - a).normalized() * reach
	var r := Rect2(a, Vector2.ZERO).expand(tip)
	return r.grow(w * 0.6)

# =============================================================================
# DRAWING
# =============================================================================

static func draw(canvas: CanvasItem, origin: Vector2, pose: Dictionary, style: Dictionary, facing: int, flash: float, alpha: float, time: float) -> void:
	var j: Dictionary = joints(pose, style)
	var s: float = float(style.get("scale", 1.0))
	var w: float = float(style.get("limb_w", 12.0)) * s
	var body := Color(str(style.get("body", "4a7fd6")))
	var dark := Color(str(style.get("dark", "26406e")))
	var metal := Color(str(style.get("metal", "d9b56a")))
	var eye := Color(str(style.get("eye", "8ff7ff")))
	if flash > 0.0:
		body = body.lerp(Color.WHITE, flash)
		dark = dark.lerp(Color(0.85, 0.85, 0.9), flash)
		metal = metal.lerp(Color.WHITE, flash)
	var outline := Color(0.05, 0.04, 0.07, alpha)
	body.a = alpha
	dark.a = alpha
	metal.a = alpha
	canvas.draw_set_transform(origin, 0.0, Vector2(facing, 1.0))
	_limb(canvas, j["shoulder"], j["elbow_b"], j["hand_b"], w * 0.9, dark, outline, metal)
	_limb(canvas, j["hip"], j["knee_b"], j["foot_b"], w * 1.1, dark, outline, metal)
	_foot(canvas, j["knee_b"], j["foot_b"], w, dark, outline)
	_torso(canvas, j, style, w, body, dark, outline, metal, time)
	_head(canvas, j, style, s, body, dark, outline, eye, alpha)
	_limb(canvas, j["hip"], j["knee_f"], j["foot_f"], w * 1.15, body, outline, metal)
	_foot(canvas, j["knee_f"], j["foot_f"], w, body, outline)
	_limb(canvas, j["shoulder"], j["elbow_f"], j["hand_f"], w, body, outline, metal)
	_fist(canvas, j["hand_f"], w, body, outline, metal)
	_fist(canvas, j["hand_b"], w * 0.9, dark, outline, metal)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _segment(canvas: CanvasItem, a: Vector2, b: Vector2, width: float, color: Color, outline: Color) -> void:
	canvas.draw_line(a, b, outline, width + 4.0)
	canvas.draw_circle(a, (width + 4.0) * 0.5, outline)
	canvas.draw_circle(b, (width + 4.0) * 0.5, outline)
	canvas.draw_line(a, b, color, width)
	canvas.draw_circle(a, width * 0.5, color)
	canvas.draw_circle(b, width * 0.5, color)

static func _limb(canvas: CanvasItem, root: Vector2, mid: Vector2, tip: Vector2, width: float, color: Color, outline: Color, metal: Color) -> void:
	_segment(canvas, root, mid, width, color, outline)
	_segment(canvas, mid, tip, width * 0.85, color, outline)
	canvas.draw_circle(mid, width * 0.32, metal)

static func _foot(canvas: CanvasItem, knee: Vector2, foot: Vector2, width: float, color: Color, outline: Color) -> void:
	var dir: Vector2 = (foot - knee).normalized()
	var fwd: Vector2 = Vector2(dir.y, -dir.x) * -1.0
	if fwd.x < 0.0:
		fwd = -fwd
	var heel: Vector2 = foot - fwd * width * 0.4
	var toe: Vector2 = foot + fwd * width * 1.3
	canvas.draw_line(heel, toe, outline, width * 0.9 + 4.0)
	canvas.draw_line(heel, toe, color, width * 0.9)

static func _fist(canvas: CanvasItem, at: Vector2, width: float, color: Color, outline: Color, metal: Color) -> void:
	canvas.draw_circle(at, width * 0.75 + 2.0, outline)
	canvas.draw_circle(at, width * 0.75, color)
	canvas.draw_arc(at, width * 0.75, -0.8, 0.8, 6, metal, 2.0)

static func _torso(canvas: CanvasItem, j: Dictionary, style: Dictionary, w: float, body: Color, dark: Color, outline: Color, metal: Color, time: float) -> void:
	var hip: Vector2 = j["hip"]
	var sh: Vector2 = j["shoulder"]
	var axis: Vector2 = (sh - hip).normalized()
	var side := Vector2(-axis.y, axis.x)
	var chest: float = w * float(style.get("chest", 1.7))
	var waist: float = w * float(style.get("waist", 1.1))
	var pts := PackedVector2Array([hip - side * waist, hip + side * waist, sh + side * chest, sh - side * chest])
	var grown := PackedVector2Array()
	var c: Vector2 = (hip + sh) * 0.5
	for p in pts:
		grown.append(p + (p - c).normalized() * 3.0)
	canvas.draw_colored_polygon(grown, outline)
	canvas.draw_colored_polygon(pts, body)
	canvas.draw_colored_polygon(PackedVector2Array([hip - side * waist * 0.6, hip + side * waist * 0.2, sh + side * chest * 0.2, sh - side * chest * 0.6]), dark.lerp(body, 0.5))
	var gear_at: Vector2 = hip.lerp(sh, 0.62)
	var gear_r: float = w * 0.55
	for k in 8:
		var a: float = time * 2.5 + TAU * k / 8.0
		canvas.draw_line(gear_at + Vector2.RIGHT.rotated(a) * gear_r * 0.6, gear_at + Vector2.RIGHT.rotated(a) * gear_r * 1.25, metal, 3.0)
	canvas.draw_circle(gear_at, gear_r, metal)
	canvas.draw_circle(gear_at, gear_r * 0.45, dark)
	canvas.draw_line(hip - side * waist, hip + side * waist, metal, 3.0)
	match str(style.get("extra", "")):
		"pads":
			for k in 2:
				var p: Vector2 = sh + side * chest * (0.9 if k == 0 else -0.9)
				canvas.draw_circle(p, w * 1.05 + 2.0, outline)
				canvas.draw_circle(p, w * 1.05, metal)
				canvas.draw_circle(p, w * 0.6, dark)
		"scarf":
			var neck: Vector2 = sh + axis * 6.0
			var tail := PackedVector2Array()
			for k in 7:
				var f: float = float(k) / 6.0
				tail.append(neck + Vector2(-30.0 * f - 6.0, 6.0 * f + sin(time * 9.0 + f * 4.0) * 5.0 * f))
			canvas.draw_polyline(tail, outline, 10.0)
			canvas.draw_polyline(tail, metal, 6.0)

static func _head(canvas: CanvasItem, j: Dictionary, style: Dictionary, s: float, body: Color, dark: Color, outline: Color, eye: Color, alpha: float) -> void:
	var at: Vector2 = j["head"]
	var r: float = float(style.get("head_r", 16.0)) * s
	var forward: Vector2 = Vector2(1.0, 0.0)
	eye.a = alpha
	match str(style.get("head_shape", "round")):
		"square":
			canvas.draw_rect(Rect2(at - Vector2(r + 3.0, r + 3.0), Vector2(r + 3.0, r + 3.0) * 2.0), outline)
			canvas.draw_rect(Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), body)
			canvas.draw_rect(Rect2(at + Vector2(r * 0.1, -r * 0.35), Vector2(r * 0.9, r * 0.4)), dark)
			canvas.draw_rect(Rect2(at + Vector2(r * 0.25, -r * 0.25), Vector2(r * 0.6, r * 0.2)), eye)
		"spike":
			var pts := PackedVector2Array([at + Vector2(-r, r * 0.8), at + Vector2(-r * 0.6, -r), at + Vector2(r * 0.2, -r * 1.5), at + Vector2(r * 1.3, -r * 0.1), at + Vector2(r * 0.8, r * 0.8)])
			var grown := PackedVector2Array()
			for p in pts:
				grown.append(at + (p - at) * 1.18)
			canvas.draw_colored_polygon(grown, outline)
			canvas.draw_colored_polygon(pts, body)
			canvas.draw_line(at + Vector2(r * 0.1, -r * 0.1), at + Vector2(r * 1.0, -r * 0.1), eye, 4.0)
		_:
			canvas.draw_circle(at, r + 3.0, outline)
			canvas.draw_circle(at, r, body)
			canvas.draw_rect(Rect2(at + Vector2(-r * 0.1, -r * 0.4), Vector2(r * 1.05, r * 0.55)), dark)
			canvas.draw_circle(at + forward * r * 0.55, r * 0.22, eye)
	canvas.draw_line(at + Vector2(-r * 0.3, -r), at + Vector2(-r * 0.5, -r * 1.6), outline, 3.0)
	canvas.draw_circle(at + Vector2(-r * 0.5, -r * 1.6), 3.0, eye)
