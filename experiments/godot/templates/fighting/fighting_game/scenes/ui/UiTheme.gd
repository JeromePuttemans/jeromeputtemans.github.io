# =============================================================================
# UiTheme.gd — Brass and ink palette, theme, small builders, portraits
# =============================================================================
# Every button plays a sound on focus and press and shows a brass border
# when focused, so the menus work with the keyboard or a pad. Texts use
# Latin-1 characters only (the web build has no font fallback).
# =============================================================================

class_name UiTheme
extends RefCounted

const PANEL: Color = Color(0.08, 0.06, 0.05, 0.94)
const BORDER: Color = Color(0.55, 0.42, 0.22)
const TEXT: Color = Color(0.96, 0.92, 0.84)
const MUTED: Color = Color(0.68, 0.62, 0.52)
const BRASS: Color = Color(0.92, 0.72, 0.36)
const P1: Color = Color(0.4, 0.8, 1.0)
const P2: Color = Color(1.0, 0.42, 0.36)
const RED: Color = Color(0.95, 0.3, 0.25)
const SHADOW: Color = Color(0.03, 0.02, 0.01, 0.9)

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 6, 16))
	theme.set_stylebox("normal", "Button", box(Color(0.14, 0.1, 0.07), Color(0.38, 0.28, 0.16), 4, 14))
	theme.set_stylebox("hover", "Button", box(Color(0.2, 0.15, 0.1), Color(0.65, 0.5, 0.28), 4, 14))
	theme.set_stylebox("pressed", "Button", box(Color(0.1, 0.07, 0.05), BRASS, 4, 14))
	theme.set_stylebox("disabled", "Button", box(Color(0.1, 0.08, 0.06, 0.8), Color(0.25, 0.2, 0.14), 4, 14))
	var focus := box(Color(0, 0, 0, 0), BRASS, 4, 14)
	focus.set_border_width_all(2)
	focus.draw_center = false
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", BRASS)
	theme.set_color("font_pressed_color", "Button", BRASS)
	return theme

static func box(bg: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.6
	style.content_margin_bottom = margin * 0.6
	return style

static func label(text: String, font_size: int, color: Color = TEXT, outline: int = 0) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	if outline > 0:
		result.add_theme_constant_override("outline_size", outline)
		result.add_theme_color_override("font_outline_color", SHADOW)
	return result

static func button(text: String, callback: Callable, min_width: float = 300.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 44.0)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(func() -> void:
		Sfx.play("ui")
		callback.call())
	b.focus_entered.connect(func() -> void: Sfx.play("ui_move"))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	return b

static func veil(alpha: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0.02, 0.015, 0.01, alpha)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect

static func center_box() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func gear(canvas: CanvasItem, at: Vector2, r: float, teeth: int, angle: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in teeth * 4:
		var a: float = angle + TAU * k / (teeth * 4)
		pts.append(at + Vector2.RIGHT.rotated(a) * r * (1.0 if (k % 4) < 2 else 0.84))
	canvas.draw_colored_polygon(pts, color)
	canvas.draw_circle(at, r * 0.6, color.darkened(0.25))
	canvas.draw_circle(at, r * 0.18, color.lightened(0.2))

## A fighter drawn idling (or in another pose) inside a control.
class Portrait extends Control:
	var fighter_id: String = "brio"
	var pose_name: String = "idle"
	var facing: int = 1
	var size_factor: float = 1.6
	var _time: float = 0.0
	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()
	func _draw() -> void:
		var character: Dictionary = GameState.roster.get(fighter_id, {}) as Dictionary
		var style: Dictionary = (character.get("style", {}) as Dictionary).duplicate()
		style["scale"] = float(style.get("scale", 1.0)) * size_factor
		var pose: Dictionary = Poses.copy(Poses.get_pose(pose_name))
		pose["torso"] = float(pose["torso"]) + sin(_time * 3.0) * 0.03
		pose["ua_f"] = float(pose["ua_f"]) + sin(_time * 3.0) * 0.04
		var feet := Vector2(size.x * 0.5, size.y - 10.0)
		draw_set_transform(feet, 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, 50.0 * size_factor, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Rig.draw(self, feet, pose, style, facing, 0.0, 1.0, _time)
