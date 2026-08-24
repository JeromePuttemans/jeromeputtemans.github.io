# =============================================================================
# GameManager.gd — Autoload (Singleton)
# =============================================================================
# Orchestrates the game loop. All tunable constants come from ConfigManager.
# =============================================================================

extends Node

var is_paused: bool = false
var _auto_save_timer: float = 0.0

func _ready() -> void:
	var last_save_timestamp = SaveManager.load_game()
	if last_save_timestamp > 0.0:
		var offline_gold = _calculate_offline_progress(last_save_timestamp)
		if offline_gold > 0.0:
			ResourceManager.add(ResourceManager.main_resource, offline_gold)
			print(StringManager.t("offline_log", {value = Utils.format_number(offline_gold)}))

func _process(delta: float) -> void:
	if is_paused:
		return
	ProducerManager.tick(delta)
	_auto_save_timer += delta
	if _auto_save_timer >= ConfigManager.auto_save_interval:
		_auto_save_timer = 0.0
		SaveManager.save_game()

func manual_click() -> void:
	ResourceManager.add(
		ResourceManager.main_resource,
		ConfigManager.click_base_value * ProducerManager.click_multiplier
	)

func _calculate_offline_progress(last_save_timestamp: float) -> float:
	var elapsed = Time.get_unix_time_from_system() - last_save_timestamp
	elapsed = clamp(elapsed, 0.0, ConfigManager.offline_cap_seconds)
	return elapsed * ProducerManager.get_total_rps() * ConfigManager.offline_factor
