# =============================================================================
# Shots.gd: Still images from preset viewpoints (needs a window)
# =============================================================================
# Run: godot --path . -- --shot=NAME --out=FILE.png [--hud]
# NAME is one of the keys of SHOTS, "title" (the title screen), "pause"
# (the pause menu), "end" (the results), or "all" (every shot, FILE is
# then a folder). The game starts, the body is
# put at the viewpoint with the hour of the shot, the world is left a
# second to settle (kinetic stones keep moving), the image is saved and
# the game quits. A .jpg extension writes a JPEG (the page's thumbnail).
# =============================================================================

extends Node

const SHOTS: Dictionary = {
	"start":   {pos = [31.5, 0.1, 10.8],  look = [12.0, -1.0, 3.0],  hour = 7.15},
	"hub":     {pos = [9.0, 0.1, -8.5],   look = [-6.0, -1.0, 4.0],  hour = 9.0},
	"bridge":  {pos = [-36.0, 0.1, -2.0], look = [-60.0, 0.0, -5.0], hour = 7.1},
	"ferry":   {pos = [22.0, 2.1, -22.5], look = [38.0, 1.0, -21.0], hour = 9.8},
	"hanging": {pos = [53.0, 0.1, 1.5],   look = [62.0, 4.0, 6.0],   hour = 7.4},
	"jib":     {pos = [76.0, 4.1, 13.0],  look = [90.0, 3.0, 4.0],   hour = 15.1},
	"oculus":  {pos = [5.5, 0.1, -2.5],   look = [0.0, 3.0, -29.0],  hour = 12.0, gnomon = true},
	"aerial":  {cam = [62.0, 48.0, 46.0], look = [14.0, 0.0, -6.0],  hour = 9.0, fov = 38.0},
	"axo":     {cam = [-20.0, 30.0, 24.0], look = [0.0, 0.0, -4.0],  hour = 7.2, fov = 40.0},
}

var main: Node = null
var shot: String = ""
var _out: String = ""
var _queue: Array[String] = []
var _frames: int = 0
var _current: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	if shot == "all":
		_queue.append("title")
		for k in SHOTS:
			_queue.append(str(k))
		_queue.append("pause")
		_queue.append("end")
	else:
		_queue.append(shot)
	_next()

func _next() -> void:
	if _queue.is_empty():
		get_tree().quit()
		return
	_current = _queue.pop_front()
	_frames = 0
	if _current != "title" and GameState.phase == GameState.Phase.MENU:
		main.call("_start", true)

func _process(_delta: float) -> void:
	_frames += 1
	if _current != "title" and SHOTS.has(_current):
		_place(SHOTS[_current] as Dictionary)
	elif _current == "pause" and _frames == 20:
		_place(SHOTS["bridge"] as Dictionary)
		main.call("_open_pause")
	elif _current == "end" and _frames == 20:
		get_tree().paused = false
		(main.get("pause_menu") as Control).visible = false
		_place(SHOTS["axo"] as Dictionary)
		(main.get("hud") as Control).visible = false
		(main.get("end_screen") as EndScreen).show_results({time = 214.6, shards = 27, total = 30, falls = 3, dashes = 41, launches = 2, record = true})
	if _frames == (220 if _current == "end" else 70):
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = _out
		if shot == "all":
			path = _out.path_join(_current + ".png")
		if path.get_extension().to_lower() == "jpg":
			image.save_jpg(path, 0.9)
		else:
			image.save_png(path)
		print("shot saved: ", path)
		_next()

func _place(s: Dictionary) -> void:
	var sun: Sun = main.get("sun")
	var rig: CameraRig = main.get("rig")
	var player: Player = main.get("player")
	var shadows: ShadowSystem = main.get("shadows")
	var hud: Control = main.get("hud")
	sun.set_hour_now(float(s["hour"]))
	shadows.set_sun(sun.direction())
	shadows.set_height("gnomon", 40.0 if bool(s.get("gnomon", false)) else 2.0)
	hud.visible = OS.get_cmdline_user_args().has("--hud")
	var look_at: Array = s["look"] as Array
	var target := Vector3(float(look_at[0]), float(look_at[1]), float(look_at[2]))
	if s.has("cam"):
		var cam: Array = s["cam"] as Array
		rig.follow = false
		rig.set_dial_visible(false)
		rig.global_position = Vector3(float(cam[0]), float(cam[1]), float(cam[2]))
		rig.look_at(target, Vector3.UP)
		rig.camera.fov = float(s.get("fov", 60.0))
		player.control_enabled = false
		return
	var p: Array = s["pos"] as Array
	var feet := Vector3(float(p[0]), float(p[1]), float(p[2]))
	rig.follow = true
	rig.set_dial_visible(true)
	if _frames < 3:
		player.teleport(feet)
	var to: Vector3 = target - (feet + Vector3(0.0, 1.6, 0.0))
	rig.set_view(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))
