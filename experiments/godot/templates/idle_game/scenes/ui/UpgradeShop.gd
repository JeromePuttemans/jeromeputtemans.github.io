# =============================================================================
# UpgradeShop.gd — Grid of the available upgrades
# =============================================================================
# Lists the unlocked, not yet purchased upgrades, cheapest first, as tiles.
# The grid is rebuilt when an upgrade unlocks or is bought, after a
# crystallization and on a language switch. Hovering a tile shows the
# tooltip with its exact effect.
# =============================================================================

extends VBoxContainer

signal upgrade_bought(upgrade: Upgrade, at: Vector2)

const COLUMNS: int = 12

var tooltip: Control = null
var _title: Label
var _empty: Label
var _grid: GridContainer
var _scroll: ScrollContainer

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_title = UiTheme.label("", 18, UiTheme.TEXT)
	add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(holder)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	holder.add_child(_grid)
	_empty = UiTheme.label("", 14, UiTheme.MUTED)
	holder.add_child(_empty)
	ProducerManager.upgrade_unlocked.connect(func(_u: Upgrade) -> void: rebuild())
	ProducerManager.upgrade_purchased.connect(func(_u: Upgrade) -> void: rebuild())
	PrestigeManager.prestige_done.connect(func(_g: int, _t: int) -> void: rebuild())
	StringManager.language_changed.connect(func(_l: String) -> void: rebuild())
	rebuild()

func rebuild() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var available: Array[Upgrade] = ProducerManager.available_upgrades()
	for upgrade in available:
		var tile := Button.new()
		tile.set_script(load("res://scenes/ui/UpgradeTile.gd"))
		_grid.add_child(tile)
		tile.call("setup", upgrade)
		tile.connect("hovered", _on_tile_hovered)
		tile.connect("unhovered", _on_tile_unhovered)
		tile.connect("bought", func(u: Upgrade, at: Vector2) -> void: upgrade_bought.emit(u, at))
	_title.text = StringManager.t("upgrades_title", {value = available.size()})
	_empty.text = StringManager.t("upgrades_empty")
	_empty.visible = available.is_empty()
	# One row of tiles, or two when they do not fit (scroll beyond)
	var rows: int = clampi(ceili(available.size() / float(COLUMNS)), 1, 2)
	_scroll.custom_minimum_size = Vector2(0.0, rows * 60.0)
	if is_instance_valid(tooltip):
		tooltip.call("hide_tooltip")

func _on_tile_hovered(tile: Control) -> void:
	if is_instance_valid(tooltip):
		tooltip.call("show_upgrade", tile.get("upgrade"))

func _on_tile_unhovered() -> void:
	if is_instance_valid(tooltip):
		tooltip.call("hide_tooltip")
