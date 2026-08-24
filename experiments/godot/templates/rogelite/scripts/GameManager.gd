extends Node

# GameManager (Autoload/Singleton)
# Manages global persistent variables: Fragments collected, Current Level, Unlocked Upgrades.

# Signals
signal fragments_changed(amount)
signal level_changed(new_level)
signal hp_changed(current_hp, max_hp)
signal upgrades_changed

# Constants
const MAX_FRAGMENTS_FOR_UPGRADE_HP = 10
const MAX_FRAGMENTS_FOR_UPGRADE_BOMB_COST = 15
const MAX_FRAGMENTS_FOR_UPGRADE_RESOURCE_RATE = 20

# Variables
var fragments : int = 0
var level : int = 1
var max_hp : int = 3
var current_hp : int = 3
var bomb_cost_hp : int = 20  # Base HP cost for bomb
var resource_spawn_rate : float = 0.1  # Base probability (10%)

# Upgrades (purchased with fragments)
var hp_upgrade_level : int = 0
var bomb_cost_upgrade_level : int = 0
var resource_rate_upgrade_level : int = 0

func _ready() -> void:
	# Initialize from saved data if any (for now, default values)
	pass

# Fragment management
func add_fragments(amount: int) -> void:
	fragments += amount
	emit_signal("fragments_changed", fragments)

func spend_fragments(amount: int) -> bool:
	if fragments >= amount:
		fragments -= amount
		emit_signal("fragments_changed", fragments)
		return true
	return false

# Level management
func set_level(new_level: int) -> void:
	level = new_level
	emit_signal("level_changed", level)
	# Optional: Adjust game difficulty based on level

# HP management
func modify_hp(amount: int) -> void:
	var old_hp = current_hp
	current_hp = clamp(current_hp + amount, 0, max_hp)
	if current_hp != old_hp:
		emit_signal("hp_changed", current_hp, max_hp)
	
	# Check for death
	if current_hp <= 0:
		# Trigger death handler (to be implemented in GameManager or via signal)
		emit_signal("player_died")

# Upgrade management
func can_upgrade_hp() -> bool:
	return hp_upgrade_level < MAX_FRAGMENTS_FOR_UPGRADE_HP

func upgrade_hp() -> void:
	if can_upgrade_hp():
		hp_upgrade_level += 1
		max_hp += 1
		current_hp = min(current_hp + 1, max_hp)  # Heal 1 HP on upgrade
		emit_signal("hp_changed", current_hp, max_hp)
		emit_signal("upgrades_changed")

func can_upgrade_bomb_cost() -> bool:
	return bomb_cost_upgrade_level < MAX_FRAGMENTS_FOR_UPGRADE_BOMB_COST

func upgrade_bomb_cost() -> void:
	if can_upgrade_bomb_cost():
		bomb_cost_upgrade_level += 1
		bomb_cost_hp = max(5, bomb_cost_hp - 1)  # Reduce cost by 1, min 5 HP
		emit_signal("upgrades_changed")

func can_upgrade_resource_rate() -> bool:
	return resource_rate_upgrade_level < MAX_FRAGMENTS_FOR_UPGRADE_RESOURCE_RATE

func upgrade_resource_rate() -> void:
	if can_upgrade_resource_rate():
		resource_rate_upgrade_level += 1
		resource_spawn_rate = min(0.5, resource_spawn_rate + 0.05)  # Increase by 5%, max 50%
		emit_signal("upgrades_changed")

# Save/Load (placeholder for persistence)
func save_game() -> void:
	# Implement saving to file if needed
	pass

func load_game() -> void:
	# Implement loading from file if needed
	pass