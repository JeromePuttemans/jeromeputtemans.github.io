# =============================================================================
# UpgradeTile.gd — One upgrade in the shop grid
# =============================================================================
# A square button drawn by code: the gem of the producer it improves (with
# its level, I to IV), a strike burst for click upgrades, a sun for global
# ones. Affordable: a gold border that breathes. Hovering shows the tooltip
# (hovered / unhovered); clicking buys it, or wiggles with a buzz when the
# shards are missing.
# =============================================================================

extends Button

signal hovered(tile: Control)
signal unhovered()
signal bought(upgrade: Upgrade, at: Vector2)

const SIZE: float = 54.0
const LEVELS: Array[String] = ["", "I", "II", "III", "IV"]

var upgrade: Upgrade = null
var _time: float = 0.0
var _shake: float = 0.0

func setup(u: Upgrade) -> void:
	upgrade = u
	custom_minimum_size = Vector2(SIZE, SIZE)
	focus_mode = Control.FOCUS_NONE
	flat = true
	mouse_entered.connect(func() -> void: hovered.emit(self))
	mouse_exited.connect(func() -> void: unhovered.emit())
	pressed.connect(_on_pressed)

func _process(delta: float) -> void:
	_time += delta
	_shake = maxf(_shake - delta * 4.0, 0.0)
	pivot_offset = size * 0.5
	rotation = sin(_shake * 40.0) * 0.1 * _shake
	queue_redraw()

func _on_pressed() -> void:
	if ProducerManager.buy_upgrade(upgrade.id):
		bought.emit(upgrade, get_global_rect().get_center())
	else:
		_shake = 1.0
		Sfx.play("deny")

func _draw() -> void:
	if upgrade == null:
		return
	var affordable: bool = ResourceManager.can_afford(ResourceManager.main_resource, upgrade.cost)
	var rect := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
	var background: StyleBoxFlat = UiTheme.box(UiTheme.PANEL_LIGHT if is_hovered() else UiTheme.PANEL, UiTheme.BORDER, 8, 0)
	if affordable:
		background.border_color = UiTheme.GOLD.lerp(UiTheme.GOLD.darkened(0.5), 0.5 + 0.5 * sin(_time * 4.0))
		background.set_border_width_all(2)
	draw_style_box(background, rect)
	var center: Vector2 = size * 0.5
	var alpha: float = 1.0 if affordable else 0.45
	match upgrade.effect_type:
		Upgrade.EffectType.MULTIPLY_PRODUCER:
			_draw_producer_icon(center, alpha)
		Upgrade.EffectType.MULTIPLY_ALL:
			_draw_sun(center, alpha)
		_:
			_draw_strike(center, alpha)

func _draw_producer_icon(center: Vector2, alpha: float) -> void:
	var producer: Producer = ProducerManager.producers.get(upgrade.effect_producer_id) as Producer
	if producer == null:
		return
	UiTheme.draw_gem(self, center + Vector2(0.0, -4.0), 15.0, producer.sides, Color(producer.color, alpha), 0.0)
	var level: String = LEVELS[clampi(int(upgrade.id.get_slice("_", 1)), 0, 4)]
	var font: Font = get_theme_default_font()
	var width: float = font.get_string_size(level, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string_outline(font, Vector2(center.x - width * 0.5, size.y - 6.0), level, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0.0, 0.0, 0.0, alpha))
	draw_string(font, Vector2(center.x - width * 0.5, size.y - 6.0), level, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UiTheme.GOLD, alpha))

func _draw_sun(center: Vector2, alpha: float) -> void:
	for i in 12:
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * i / 12.0 + _time * 0.4)
		draw_line(center + direction * 10.0, center + direction * 19.0, Color(UiTheme.GOLD, alpha), 2.0, true)
	draw_circle(center, 9.0, Color(UiTheme.GOLD, alpha))

func _draw_strike(center: Vector2, alpha: float) -> void:
	UiTheme.draw_gem(self, center, 13.0, 4, Color(UiTheme.CRYSTAL, alpha), PI * 0.25)
	for i in 6:
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * i / 6.0)
		draw_line(center + direction * 15.0, center + direction * 21.0, Color(UiTheme.CRYSTAL.lightened(0.4), alpha), 2.0, true)
	if upgrade.effect_type == Upgrade.EffectType.CLICK_RPS_SHARE:
		draw_arc(center, 22.0, 0.0, TAU, 32, Color(UiTheme.PRISM, alpha * 0.8), 1.5, true)
