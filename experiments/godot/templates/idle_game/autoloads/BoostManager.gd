# =============================================================================
# BoostManager.gd — Autoload (Singleton)
# =============================================================================
# Temporary boosts that reward active play.
#
# OVERHEAT: each click adds heat_per_click to a gauge (0..1). After
#   heat_decay_delay seconds without clicking, the gauge cools down at
#   heat_decay_per_second. When it is full, the crystal overheats for
#   frenzy_duration seconds: production and clicks x frenzy_multiplier.
#   With the default values, 34 fast clicks fill the gauge.
# METEORS: the first one comes after meteor_first_delay seconds, then one
#   every meteor_interval_min to meteor_interval_max seconds. It stays
#   meteor_lifetime seconds; catching it (a click, handled by the UI) gives:
#     rain      an instant gift of meteor_rain_seconds of production
#               (at least meteor_rain_min_clicks clicks)
#     eruption  production x meteor_eruption_multiplier for
#               meteor_eruption_duration seconds
# =============================================================================

extends Node

signal frenzy_started(duration: float)
signal frenzy_ended()
signal meteor_spawned(kind: String, lifetime: float)
signal meteor_expired()
signal meteor_caught(kind: String, amount: float)

const KINDS: Array[String] = ["rain", "eruption"]

var heat: float = 0.0
var frenzy_left: float = 0.0
var eruption_left: float = 0.0
var meteor_active: bool = false
var meteor_kind: String = ""
var _since_click: float = 0.0
var _meteor_timer: float = 30.0
var _meteor_left: float = 0.0

func _ready() -> void:
	reset()

func reset() -> void:
	heat = 0.0
	frenzy_left = 0.0
	eruption_left = 0.0
	meteor_active = false
	_meteor_timer = ConfigManager.get_float("meteor_first_delay", 30.0)

func is_frenzy() -> bool:
	return frenzy_left > 0.0

func production_multiplier() -> float:
	var value: float = 1.0
	if is_frenzy():
		value *= ConfigManager.get_float("frenzy_multiplier", 2.0)
	if eruption_left > 0.0:
		value *= ConfigManager.get_float("meteor_eruption_multiplier", 5.0)
	return value

func click_multiplier() -> float:
	return ConfigManager.get_float("frenzy_multiplier", 2.0) if is_frenzy() else 1.0

func add_heat() -> void:
	_since_click = 0.0
	if is_frenzy():
		return
	heat = minf(heat + ConfigManager.get_float("heat_per_click", 0.03), 1.0)
	if heat >= 1.0:
		frenzy_left = ConfigManager.get_float("frenzy_duration", 8.0)
		frenzy_started.emit(frenzy_left)

func tick(delta: float) -> void:
	_tick_heat(delta)
	eruption_left = maxf(eruption_left - delta, 0.0)
	_tick_meteor(delta)

func _tick_heat(delta: float) -> void:
	if is_frenzy():
		frenzy_left -= delta
		heat = clampf(frenzy_left / ConfigManager.get_float("frenzy_duration", 8.0), 0.0, 1.0)
		if frenzy_left <= 0.0:
			frenzy_left = 0.0
			heat = 0.0
			frenzy_ended.emit()
		return
	_since_click += delta
	if _since_click > ConfigManager.get_float("heat_decay_delay", 1.0):
		heat = maxf(heat - ConfigManager.get_float("heat_decay_per_second", 0.12) * delta, 0.0)

func _tick_meteor(delta: float) -> void:
	if meteor_active:
		_meteor_left -= delta
		if _meteor_left <= 0.0:
			meteor_active = false
			meteor_expired.emit()
			_schedule_meteor()
		return
	_meteor_timer -= delta
	if _meteor_timer <= 0.0:
		meteor_active = true
		meteor_kind = KINDS[randi() % KINDS.size()]
		_meteor_left = ConfigManager.get_float("meteor_lifetime", 7.0)
		meteor_spawned.emit(meteor_kind, _meteor_left)

func _schedule_meteor() -> void:
	_meteor_timer = randf_range(ConfigManager.get_float("meteor_interval_min", 45.0),
		ConfigManager.get_float("meteor_interval_max", 90.0))

## Called by the UI when the player clicks the meteor. Returns the shards
## given (0 for an eruption, whose reward is the boost itself).
func catch_meteor() -> float:
	if not meteor_active:
		return 0.0
	meteor_active = false
	_schedule_meteor()
	var amount: float = 0.0
	if meteor_kind == "rain":
		var production: float = ProducerManager.get_base_rps() * ConfigManager.get_float("meteor_rain_seconds", 45.0)
		var clicks: float = ProducerManager.click_value() * ConfigManager.get_float("meteor_rain_min_clicks", 40.0)
		amount = maxf(production, clicks)
		ResourceManager.add(ResourceManager.main_resource, amount)
	else:
		eruption_left = ConfigManager.get_float("meteor_eruption_duration", 15.0)
	meteor_caught.emit(meteor_kind, amount)
	return amount
