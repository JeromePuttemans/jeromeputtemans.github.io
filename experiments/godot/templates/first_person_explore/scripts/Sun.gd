# =============================================================================
# Sun.gd — The hour of the day, which the player controls
# =============================================================================
# COURSE: the sun rises in the east (+x) at 6:00, culminates in the south
#   (+z) at noon at sun_max_elevation_deg, and sets in the west at 18:00:
#   with t = (hour - 6) / 12 x pi and phi the maximum elevation,
#   direction to the sun = (cos t, sin t sin phi, sin t cos phi). Shadows
#   point away from it: west in the morning, north at noon, east at dusk,
#   long when the sun is low. The player moves between hour_min and
#   hour_max (7:00 to 17:00).
# CONTROL: holding time_back / time_forward moves the target hour at a speed
#   that ramps from time_speed_min to time_speed_max hours per second in
#   time_ramp seconds (a tap moves a few minutes, a long press sweeps the
#   day); a mouse wheel notch moves it by wheel_step. The hour follows the
#   target with exponential smoothing, and a tick sounds every quarter hour.
# LOOK: light colour and energy, sky, fog, ambient light and the sea of
#   clouds all follow the sun's elevation, warmer in the evening; `night`
#   (ending) fades everything to a starry dusk.
# =============================================================================

class_name Sun
extends Node

signal hour_changed(previous: float, current: float)

var hour: float = 12.0
var target: float = 12.0
var hour_min: float = 7.0
var hour_max: float = 17.0
var max_elevation: float = 65.0
var control_enabled: bool = false
var speed: float = 0.0               # hours per second, for the HUD and sounds
var light: DirectionalLight3D = null
var environment: Environment = null
var sky_material: ShaderMaterial = null
var sea_material: ShaderMaterial = null

var _hold: float = 0.0
var _smoothing: float = 9.0
var _quarter: int = 0
var _free_course: bool = false        # ending: the sun may set past hour_max

func _ready() -> void:
	hour_min = ConfigManager.get_float("hour_min", 7.0)
	hour_max = ConfigManager.get_float("hour_max", 17.0)
	max_elevation = ConfigManager.get_float("sun_max_elevation_deg", 65.0)
	_smoothing = ConfigManager.get_float("time_smoothing", 9.0)

static func direction_for(h: float, max_elevation_deg: float) -> Vector3:
	var t: float = (h - 6.0) / 12.0 * PI
	var phi: float = deg_to_rad(max_elevation_deg)
	return Vector3(cos(t), sin(t) * sin(phi), sin(t) * cos(phi)).normalized()

func direction() -> Vector3:
	return direction_for(hour, max_elevation)

func set_hour_now(h: float) -> void:
	hour = clampf(h, hour_min, hour_max)
	target = hour
	_quarter = floori(hour * 4.0)
	_apply()

## Ending: the sun is driven to `h` (may go past hour_max), slowly.
func drive_to(h: float) -> void:
	_free_course = true
	target = h

func nudge(steps: float) -> void:
	if not control_enabled:
		return
	target = clampf(target + steps * ConfigManager.get_float("wheel_step", 0.25), hour_min, hour_max)

func _process(delta: float) -> void:
	if control_enabled:
		var input: float = Input.get_action_strength("time_forward") - Input.get_action_strength("time_back")
		if absf(input) > 0.1:
			_hold += delta
			var ramp: float = clampf(_hold / ConfigManager.get_float("time_ramp", 0.9), 0.0, 1.0)
			var rate: float = lerpf(ConfigManager.get_float("time_speed_min", 0.6), ConfigManager.get_float("time_speed_max", 2.2), ramp * ramp)
			target = clampf(target + signf(input) * rate * delta, hour_min, hour_max)
		else:
			_hold = 0.0
	var previous: float = hour
	var smoothing: float = 0.6 if _free_course else _smoothing
	hour = lerpf(hour, target, 1.0 - exp(-smoothing * delta))
	if absf(hour - target) < 0.0005:
		hour = target
	speed = (hour - previous) / maxf(delta, 0.0001)
	if hour != previous:
		hour_changed.emit(previous, hour)
		_apply()
		var q: int = floori(hour * 4.0)
		if q != _quarter and not _free_course:
			_quarter = q
			Sfx.play("tick", 0.9 + minf(absf(speed), 3.0) * 0.12, 0.04)

func _apply() -> void:
	var dir: Vector3 = direction()
	var elevation: float = rad_to_deg(asin(clampf(dir.y, -1.0, 1.0)))
	var low: float = 1.0 - smoothstep(5.0, 35.0, elevation)
	var evening: float = smoothstep(12.0, 16.5, hour)
	var night: float = smoothstep(17.4, 18.5, hour)
	var zenith: Color = Color(0.2, 0.42, 0.84).lerp(Color(0.27, 0.32, 0.62), low)
	var horizon_low: Color = Color(1.0, 0.72, 0.5).lerp(Color(1.0, 0.52, 0.42), evening)
	var horizon: Color = Color(0.78, 0.86, 0.96).lerp(horizon_low, low)
	var sun_color: Color = Color(1.0, 0.97, 0.9).lerp(Color(1.0, 0.72, 0.48).lerp(Color(1.0, 0.58, 0.36), evening), low)
	zenith = zenith.lerp(Color(0.02, 0.03, 0.09), night)
	horizon = horizon.lerp(Color(0.12, 0.08, 0.2), night)
	sun_color = sun_color.lerp(Color(0.5, 0.3, 0.4), night)
	var below: Color = horizon.lerp(Color(0.45, 0.5, 0.66), 0.5).lerp(Color(0.04, 0.04, 0.1), night)
	if light != null:
		if dir.y > 0.01:
			light.basis = Basis.looking_at(-dir, Vector3.UP)
		light.light_color = sun_color
		light.light_energy = lerpf(1.25, 0.9, low) * (1.0 - night * 0.95)
	if sky_material != null:
		sky_material.set_shader_parameter("sun_dir", dir)
		sky_material.set_shader_parameter("zenith_color", zenith)
		sky_material.set_shader_parameter("horizon_color", horizon)
		sky_material.set_shader_parameter("low_color", below)
		sky_material.set_shader_parameter("sun_color", sun_color)
		sky_material.set_shader_parameter("night", night)
	if environment != null:
		environment.fog_light_color = horizon
		environment.ambient_light_color = zenith.lerp(horizon, 0.55)
		environment.ambient_light_energy = lerpf(0.75, 0.6, low) * (1.0 - night * 0.6)
	if sea_material != null:
		sea_material.set_shader_parameter("light_color", horizon.lerp(sun_color, 0.35))
		sea_material.set_shader_parameter("shade_color", below.lerp(zenith, 0.3))
