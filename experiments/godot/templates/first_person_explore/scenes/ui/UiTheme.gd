# =============================================================================
# UiTheme.gd: Palette, theme and small builders shared by the interface
# =============================================================================
# Architect's sheet: graphite ink on white paper, square corners, thin
# rules, headings in letter-spaced capitals, one accent colour (the same as
# the shards and seals) for focus, records and what matters now. Buttons are
# flat text underlined in the accent colour when focused, and play a sound
# on focus and on press. A white halo around the labels drawn over the world
# was tried and dropped: over a dark stone it made the letters look hollow;
# what must stay readable everywhere sits on a white card instead.
# =============================================================================

class_name UiTheme
extends RefCounted

const INK: Color = Color(0.11, 0.11, 0.12)
const MUTED: Color = Color(0.43, 0.43, 0.45)
const FAINT: Color = Color(0.11, 0.11, 0.12, 0.22)
const PAPER: Color = Color(0.975, 0.97, 0.96, 0.95)
const ACCENT: Color = Color(1.0, 0.38, 0.1)
const HALO: Color = Color(1.0, 1.0, 1.0, 0.35)

static var _spaced: Dictionary = {}

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", INK)
	theme.set_stylebox("panel", "PanelContainer", box(PAPER, FAINT, 30))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.content_margin_left = 4
	normal.content_margin_right = 4
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var focus: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focus.border_color = ACCENT
	focus.border_width_bottom = 2
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", focus)
	theme.set_stylebox("pressed", "Button", focus)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_hover_pressed_color", "Button", ACCENT)
	return theme

static func box(bg: Color, border: Color, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.8
	style.content_margin_bottom = margin * 0.8
	return style

## The default font with extra space between letters, for headings.
static func spaced_font(spacing: int) -> Font:
	if _spaced.has(spacing):
		return _spaced[spacing]
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.spacing_glyph = spacing
	_spaced[spacing] = font
	return font

static func label(text: String, font_size: int, color: Color = INK, halo: int = 0, spacing: int = 0) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	if spacing > 0:
		result.add_theme_font_override("font", spaced_font(spacing))
	if halo > 0:
		result.add_theme_constant_override("outline_size", halo)
		result.add_theme_color_override("font_outline_color", HALO)
	return result

static func button(text: String, callback: Callable, min_width: float = 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(min_width, 40.0)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(func() -> void:
		Sfx.play("ui")
		callback.call())
	b.focus_entered.connect(func() -> void: Sfx.play("ui_move"))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	return b

## Thin horizontal rule.
static func rule(width: float, color: Color = INK, thickness: float = 1.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(width, thickness)
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func veil(alpha: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0.96, 0.96, 0.95, alpha)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect

static func center_box() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## "9 h 30" / "9:30", minutes rounded to five.
static func hour_text(h: float) -> String:
	var minutes: int = int(round(h * 60.0 / 5.0)) * 5
	return StringManager.t("hour_format", {h = floori(minutes / 60.0), m = "%02d" % (minutes % 60)})

## "+4,00" / "+4.00": a level mark, as on an architect's section.
static func level_text(y: float) -> String:
	var text: String = "%+.2f" % y
	if StringManager.get_language() == "fr":
		text = text.replace(".", ",")
	return StringManager.t("level_format", {v = text})

## Fills {back}, {fwd}, {move}, {dash} and {reset} with the keys of the
## player's keyboard.
static func keys(text: String) -> String:
	return text.replace("{back}", InputSetup.key_name(KEY_Q)).replace("{fwd}", InputSetup.key_name(KEY_E)).replace("{move}", InputSetup.move_keys()).replace("{reset}", InputSetup.key_name(KEY_R))
