# =============================================================================
# Main.gd — Root of the game: builds everything and runs the phases
# =============================================================================
# TREE (all built by code)
#   WorldEnvironment (sky shader, fog, glow), DirectionalLight3D (the sun,
#   no engine shadows: only black stones cast shadows, drawn by
#   ShadowSystem), Sun, ShadowSystem, World, Effects3D, Player, CameraRig,
#   UI (HUD), Menus (title, pause, results), Fade.
# PHASES (GameState.Phase)
#   MENU     the camera circles the archipelago while the sun sweeps the
#            day; a click starts or continues the run (and locks the mouse)
#   PLAYING  arrivals on islands (banner, tip, save), pickups, falls, light
#            columns, seals set in the Dial, the great gnomon rising
#   PAUSED   tree paused, mouse free, settings
#   ENDING   at the observatory: control off, the view turns to the west
#            while the sun sets and the stars appear
#   END      results, then back to MENU
# =============================================================================

extends Node3D

var sun: Sun = null
var shadows: ShadowSystem = null
var world: World = null
var player: Player = null
var rig: CameraRig = null
var effects: Effects3D = null
var environment: Environment = null
var light: DirectionalLight3D = null
var sky_material: ShaderMaterial = null
var hud: Hud = null
var title: TitleScreen = null
var pause_menu: PauseMenu = null
var end_screen: EndScreen = null
var fade: Fade = null

var _busy: bool = false
var _placing: bool = false
var _ending: bool = false
var _streak: int = 0
var _streak_time: float = 0.0
var _title_time: float = 0.0
var _was_moving: bool = false
var _capture_grace: float = 0.0
var _hub: String = "cadran"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.register()
	_build_environment()
	sun = Sun.new()
	sun.name = "Sun"
	sun.light = light
	sun.environment = environment
	sun.sky_material = sky_material
	_pausable(sun)
	shadows = ShadowSystem.new()
	shadows.name = "ShadowSystem"
	_pausable(shadows)
	world = World.new()
	world.name = "World"
	_pausable(world)
	world.build(shadows)
	_hub = str(world.data.get("hub_island", "cadran"))
	sun.sea_material = world.sea_material()
	GameState.shard_total = world.shard_total()
	effects = Effects3D.new()
	effects.name = "Effects"
	_pausable(effects)
	player = Player.new()
	player.name = "Player"
	player.shadows = shadows
	player.sun = sun
	player.void_y = world.lowest_y - ConfigManager.get_float("void_depth", 16.0)
	player.ground_at = Callable(world, "island_at")
	_pausable(player)
	rig = CameraRig.new()
	rig.name = "CameraRig"
	rig.player = player
	rig.sun = sun
	player.rig = rig
	_pausable(rig)
	sun.hour_changed.connect(func(_a: float, _b: float) -> void: shadows.set_sun(sun.direction()))
	player.stepped.connect(_on_step)
	player.landed.connect(_on_land)
	player.jumped.connect(func() -> void:
		Sfx.play("jump", 1.0, 0.06, -4.0)
		rig.jump_kick())
	player.fell_out.connect(_on_fell_out)
	world.shard_collected.connect(_on_shard)
	world.seal_taken.connect(_on_seal)
	world.beam_entered.connect(_on_beam)
	world.observatory_reached.connect(_on_observatory)
	_build_ui()
	Sfx.ambience = true
	_enter_menu()

func _pausable(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(node)

func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = preload("res://shaders/sky.gdshader")
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.fog_enabled = true
	environment.fog_density = 0.0028
	environment.fog_sky_affect = 0.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.7
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)
	light = DirectionalLight3D.new()
	light.shadow_enabled = false
	add_child(light)

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 1
	add_child(ui)
	var theme: Theme = UiTheme.build()
	hud = Hud.new()
	hud.theme = theme
	hud.sun = sun
	hud.shard_total = world.shard_total()
	ui.add_child(hud)
	var menus := CanvasLayer.new()
	menus.layer = 2
	add_child(menus)
	title = TitleScreen.new()
	title.theme = theme
	title.start_requested.connect(_start)
	menus.add_child(title)
	pause_menu = PauseMenu.new()
	pause_menu.theme = theme
	pause_menu.visible = false
	pause_menu.resume_requested.connect(_resume)
	pause_menu.title_requested.connect(func() -> void:
		get_tree().paused = false
		pause_menu.visible = false
		GameState.hour = sun.hour
		GameState.save_run()
		_enter_menu())
	pause_menu.settings_changed.connect(func() -> void:
		rig.sensitivity = float(SaveManager.get_setting("sensitivity", ConfigManager.get_float("mouse_sensitivity", 0.12)))
		rig.invert_y = bool(SaveManager.get_setting("invert_y", false)))
	menus.add_child(pause_menu)
	end_screen = EndScreen.new()
	end_screen.theme = theme
	end_screen.visible = false
	end_screen.closed.connect(_enter_menu)
	menus.add_child(end_screen)
	var top := CanvasLayer.new()
	top.layer = 3
	add_child(top)
	fade = Fade.new()
	top.add_child(fade)

# --- phases ----------------------------------------------------------------------

func _enter_menu() -> void:
	_ending = false
	_busy = false
	get_tree().paused = false
	GameState.set_phase(GameState.Phase.MENU)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if SaveManager.has_run():
		GameState.load_run(SaveManager.get_run())
	else:
		GameState.new_run(str(world.data.get("start_island", "seuil")), ConfigManager.get_float("hour_start", 12.0))
	_apply_run_state()
	player.control_enabled = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	sun.control_enabled = false
	rig.follow = false
	rig.look_enabled = false
	rig.set_astrolabe_visible(false)
	shadows.set_shadows_visible(true)
	hud.visible = false
	pause_menu.visible = false
	end_screen.visible = false
	title.refresh()
	title.visible = true
	fade.color.a = 0.0

func _apply_run_state() -> void:
	world.set_shards_taken(GameState.shards)
	world.set_seals_state(GameState.seals_taken)
	world.set_sockets_state(GameState.seals_placed)
	var gnomon: Dictionary = {}
	for c in world.data.get("casters", []) as Array:
		if str((c as Dictionary)["id"]) == "gnomon":
			gnomon = c
	if not gnomon.is_empty():
		shadows.set_height("gnomon", float(gnomon.get("h_raised", gnomon["h"])) if GameState.gnomon_raised else float(gnomon["h"]))

func _start(new_game: bool) -> void:
	if GameState.phase != GameState.Phase.MENU:
		return
	var fresh: bool = new_game or not SaveManager.has_run()
	if fresh:
		GameState.new_run(str(world.data.get("start_island", "seuil")), ConfigManager.get_float("hour_start", 12.0))
		SaveManager.clear_run()
	else:
		GameState.load_run(SaveManager.get_run())
	_apply_run_state()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_capture_grace = 1.0
	title.visible = false
	hud.reset()
	hud.visible = true
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.teleport(world.spawn_point(GameState.checkpoint))
	var yaw: float = deg_to_rad(float(world.data.get("start_yaw", 90.0))) if fresh else rig.yaw
	rig.set_view(yaw, -0.08)
	rig.follow = true
	rig.look_enabled = true
	rig.set_astrolabe_visible(true)
	sun.set_hour_now(GameState.hour)
	shadows.set_sun(sun.direction())
	sun.control_enabled = true
	player.control_enabled = true
	GameState.set_phase(GameState.Phase.PLAYING)
	fade.color = Color(1.0, 1.0, 1.0, 1.0)
	fade.fade_from(0.8)
	if fresh:
		GameState.visit(GameState.checkpoint)
		GameState.save_run()
		await get_tree().create_timer(1.0).timeout
		GameState.banner(StringManager.t("island_" + GameState.checkpoint))
		Sfx.play("island")
		GameState.show_tip("tip_start")
		GameState.show_tip(str(world.island(GameState.checkpoint).get("tip", "")))

func _open_pause() -> void:
	if GameState.phase != GameState.Phase.PLAYING:
		return
	GameState.set_phase(GameState.Phase.PAUSED)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.hour = sun.hour
	GameState.save_run()
	pause_menu.open()

func _resume() -> void:
	pause_menu.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_capture_grace = 1.0
	GameState.set_phase(GameState.Phase.PLAYING)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameState.phase == GameState.Phase.PLAYING and not _busy:
		_open_pause()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameState.phase == GameState.Phase.PLAYING and not _busy:
			_open_pause()
			get_viewport().set_input_as_handled()
		elif GameState.phase == GameState.Phase.PAUSED:
			_resume()
			get_viewport().set_input_as_handled()
		return
	if GameState.phase != GameState.Phase.PLAYING:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			sun.nudge(1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			sun.nudge(-1.0)
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_capture_grace = 1.0

# --- frame -----------------------------------------------------------------------

func _process(delta: float) -> void:
	_streak_time = maxf(_streak_time - delta, 0.0)
	match GameState.phase:
		GameState.Phase.MENU:
			_title_flight(delta)
		GameState.Phase.PLAYING:
			_capture_grace = maxf(_capture_grace - delta, 0.0)
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and _capture_grace <= 0.0 and not _busy and DisplayServer.get_name() != "headless":
				_open_pause()
			var moving: bool = absf(sun.speed) > 0.05
			if moving and not _was_moving:
				shadows.pulse()
			_was_moving = moving

func _title_flight(delta: float) -> void:
	_title_time += delta
	var a: float = 0.6 + _title_time * 0.045
	var centre := Vector3(6.0, 0.0, -4.0)
	rig.global_position = centre + Vector3(cos(a) * 58.0, 20.0 + sin(_title_time * 0.11) * 4.0, sin(a) * 58.0)
	rig.look_at(centre + Vector3(0.0, -2.0, 0.0), Vector3.UP)
	sun.set_hour_now(12.0 + 4.6 * sin(_title_time * 0.16))
	shadows.set_sun(sun.direction())

func _physics_process(delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAYING:
		return
	GameState.add_time(delta)
	GameState.hour = sun.hour
	Sfx.set_wind(clampf((-player.velocity.y - 6.0) / 20.0, 0.0, 1.0))
	if _busy:
		return
	world.update_pickups(player.global_position, delta)
	var island: String = world.island_at(player.global_position) if player.is_on_floor() else ""
	if island != "" and island != GameState.checkpoint:
		_arrive(island)

func _arrive(island: String) -> void:
	var first: bool = GameState.visit(island)
	if first:
		GameState.banner(StringManager.t("island_" + island))
		Sfx.play("island")
		GameState.show_tip(str(world.island(island).get("tip", "")))
	GameState.hour = sun.hour
	GameState.save_run()
	if island == _hub and not GameState.seals_to_place().is_empty():
		_place_seals()

# --- events ----------------------------------------------------------------------

func _on_step(surface: String) -> void:
	var sound: String = "step_" + (surface if surface in ["grass", "stone", "shadow"] else "stone")
	Sfx.play(sound, 1.0, 0.1, 0.0 if player.sprinting else -3.0)

func _on_land(impact: float, surface: String) -> void:
	if impact < 2.0:
		return
	Sfx.play("land", clampf(1.25 - impact * 0.025, 0.7, 1.2), 0.05, clampf(impact * 0.7 - 8.0, -12.0, 2.0))
	if surface == "shadow":
		Sfx.play("step_shadow", 0.8, 0.05)
	rig.land(impact)
	if impact > 7.0:
		effects.dust(player.global_position, 16, 3.5)

func _on_fell_out() -> void:
	if _busy:
		return
	_busy = true
	player.control_enabled = false
	Sfx.play("fall")
	GameState.add_fall()
	await fade.fade_to(Color(0.96, 0.94, 1.0, 1.0), 0.6)
	player.teleport(world.spawn_point(GameState.checkpoint))
	Sfx.set_wind(0.0)
	await get_tree().create_timer(0.2).timeout
	Sfx.play("respawn")
	effects.burst(player.global_position + Vector3(0.0, 1.0, 0.0), Color(0.8, 0.85, 1.0), 30, 3.0, 1.0, -1.0)
	await fade.fade_from(0.6)
	_busy = false
	player.control_enabled = GameState.phase == GameState.Phase.PLAYING or GameState.phase == GameState.Phase.PAUSED
	GameState.show_tip("tip_fall")

func _on_shard(index: int, pos: Vector3) -> void:
	GameState.collect_shard(index)
	_streak = _streak + 1 if _streak_time > 0.0 else 0
	_streak_time = 3.0
	Sfx.play("shard", pow(1.0595, mini(_streak, 7) * 2), 0.0)
	effects.burst(pos, Color(1.0, 0.85, 0.4), 28, 4.5, 0.8, 3.0)

func _on_seal(id: String, pos: Vector3) -> void:
	if GameState.seals_taken.has(id):
		return
	GameState.take_seal(id)
	world.set_seals_state(GameState.seals_taken)
	Sfx.play("seal")
	effects.burst(pos, (World.SEAL_COLORS[id] as Color), 70, 7.0, 1.5, 1.0, 1.5)
	rig.add_shake(0.4)
	GameState.banner(StringManager.t("seal_" + id))
	GameState.show_tip("tip_beam")

func _on_beam(_id: String) -> void:
	if _busy:
		return
	_busy = true
	player.control_enabled = false
	Sfx.play("beam")
	await fade.fade_to(Color(0.8, 0.92, 1.0, 1.0), 0.7)
	var spawn: Vector3 = world.spawn_point(_hub)
	player.teleport(spawn)
	var socket: Vector3 = world.socket_position("noon")
	var to: Vector3 = socket - spawn
	rig.set_view(atan2(-to.x, -to.z), -0.05)
	await get_tree().create_timer(0.2).timeout
	await fade.fade_from(0.7)
	_busy = false
	player.control_enabled = true
	if GameState.checkpoint != _hub:
		_arrive(_hub)
	elif not GameState.seals_to_place().is_empty():
		_place_seals()

func _place_seals() -> void:
	if _placing:
		return
	_placing = true
	for id in GameState.seals_to_place():
		await get_tree().create_timer(0.9).timeout
		GameState.place_seal(id)
		world.set_sockets_state(GameState.seals_placed)
		var p: Vector3 = world.socket_position(id)
		Sfx.play("socket")
		effects.burst(p, (World.SEAL_COLORS[id] as Color), 50, 5.0, 1.2, 1.5)
		rig.add_shake(0.3)
		GameState.banner(StringManager.t("banner_seal_placed", {seal = StringManager.t("seal_" + id), n = GameState.seals_placed.size()}))
	_placing = false
	if GameState.seals_placed.size() >= 3 and not GameState.gnomon_raised:
		_raise_gnomon()

func _raise_gnomon() -> void:
	await get_tree().create_timer(2.0).timeout
	var def: Dictionary = {}
	for c in world.data.get("casters", []) as Array:
		if str((c as Dictionary)["id"]) == "gnomon":
			def = c
	if def.is_empty():
		return
	GameState.banner(StringManager.t("banner_gnomon"))
	var low: float = float(def["h"])
	var high: float = float(def.get("h_raised", low))
	var duration: float = ConfigManager.get_float("gnomon_rise_time", 7.0)
	var base := Vector3(float(def["x"]), 0.0, float(def["z"]))
	var t: float = 0.0
	var next_rumble: float = 0.0
	while t < duration:
		t += get_process_delta_time()
		shadows.set_height("gnomon", lerpf(low, high, smoothstep(0.0, 1.0, t / duration)))
		rig.add_shake(0.25)
		if t >= next_rumble:
			next_rumble += 1.0
			Sfx.play("rumble", 1.0, 0.05)
			effects.dust(base, 26, 6.0)
		await get_tree().process_frame
	shadows.set_height("gnomon", high)
	GameState.gnomon_raised = true
	GameState.save_run()
	Sfx.play("socket", 0.7, 0.0)
	GameState.show_tip("tip_final")

func _on_observatory() -> void:
	if _ending or not GameState.gnomon_raised or _busy:
		return
	_ending = true
	GameState.set_phase(GameState.Phase.ENDING)
	player.control_enabled = false
	sun.control_enabled = false
	Sfx.play("ending")
	sun.drive_to(18.8)
	var t: float = 0.0
	while t < 8.0:
		var dt: float = get_process_delta_time()
		t += dt
		rig.set_view(lerp_angle(rig.yaw, PI * 0.5, dt * 0.6), lerpf(rig.pitch, 0.12, dt * 0.6))
		if sun.hour > 17.3 and shadows.shadows_visible:
			shadows.set_shadows_visible(false)
		await get_tree().process_frame
	var record: bool = SaveManager.store_best(GameState.time, GameState.shards.size())
	var result: Dictionary = {time = GameState.time, shards = GameState.shards.size(), total = GameState.shard_total, falls = GameState.falls, record = record}
	SaveManager.clear_run()
	GameState.set_phase(GameState.Phase.END)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	rig.set_astrolabe_visible(false)
	hud.visible = false
	end_screen.show_results(result)
