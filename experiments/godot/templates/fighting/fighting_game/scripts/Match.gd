# =============================================================================
# Match.gd — A fight between two automatons: rounds, hits, camera
# =============================================================================
# One step per physics tick (60 per second):
#   fighters step (each reads its input) -> projectiles move -> pushboxes
#   keep the bodies apart -> hitboxes against hurtboxes -> round logic ->
#   camera.
# Both fighters' hits are checked against the state of the same frame, so
# two attacks landing together trade.
#
# HITSTOP: on contact both fighters freeze for the move's hitstop frames
# (more on counter hits); the impact reads as heavy. A super freezes the
# whole screen for superfreeze frames while the screen darkens. The final
# K.O. plays in slow motion (one step out of three).
# ROUNDS: round_time seconds, first to rounds_to_win round wins. At time
# out, the higher health ratio wins the round. A round won without losing
# any health is announced as perfect.
# =============================================================================

class_name Match
extends Node2D

signal match_over(winner: int)
signal announce(text_key: String, style: String)

enum Phase { INTRO, CALL, FIGHT, KO, ROUND_END, OVER }

const STAGE_WIDTH: float = 1800.0
const WALL: float = 50.0
const MAX_SEPARATION: float = 980.0

var fighters: Array[Fighter] = []
var projectiles: Array[Projectile] = []
var stage: Stage = null
var sparks: Effects = null
var dust_fx: Effects = null
var labels: WorldLabels = null
var camera: Camera2D = null
var phase: Phase = Phase.INTRO
var phase_frame: int = 0
var round_number: int = 1
var wins: Array[int] = [0, 0]
var timer_frames: int = 0
var training: bool = false
var freeze: int = 0
var freeze_owner: Fighter = null
var round_winner: int = -1
var last_info: Dictionary = {}
var dummy_mode: String = "stand"

var _round_time: int = 60
var _rounds_to_win: int = 2
var _slowmo: int = 0
var _slow_tick: int = 0
var _trauma: float = 0.0
var _cam_x: float = 900.0
var _cam_zoom: float = 1.0
var _hp_at_round_start: Array[float] = [0.0, 0.0]
var _regen_timer: Array[int] = [0, 0]

func setup(p1_id: String, p2_id: String, roster: Dictionary, inputs: Array, stage_id: String, training_mode: bool) -> void:
	training = training_mode
	_round_time = ConfigManager.get_int("round_time", 60)
	_rounds_to_win = ConfigManager.get_int("rounds_to_win", 2)
	stage = Stage.new()
	stage.theme_id = stage_id
	add_child(stage)
	dust_fx = Effects.new()
	dust_fx.additive = false
	add_child(dust_fx)
	var ids: Array[String] = [p1_id, p2_id]
	for i in 2:
		var f := Fighter.new()
		f.match_node = self
		f.setup(ids[i], roster[ids[i]] as Dictionary, i)
		f.input = inputs[i]
		add_child(f)
		fighters.append(f)
	fighters[0].opponent = fighters[1]
	fighters[1].opponent = fighters[0]
	sparks = Effects.new()
	add_child(sparks)
	labels = WorldLabels.new()
	add_child(labels)
	camera = Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	camera.make_current()
	_start_round()

# =============================================================================
# ROUND FLOW
# =============================================================================

func _start_round() -> void:
	for p in projectiles:
		p.queue_free()
	projectiles.clear()
	var mid: float = STAGE_WIDTH * 0.5
	fighters[0].reset_for_round(mid - 230.0, 1)
	fighters[1].reset_for_round(mid + 230.0, -1)
	for f in fighters:
		f.controllable = false
		if not training:
			f.meter = minf(f.meter, 100.0)
	_hp_at_round_start = [fighters[0].hp, fighters[1].hp]
	timer_frames = _round_time * 60
	round_winner = -1
	_slowmo = 0
	freeze = 0
	_cam_x = mid
	_set_phase(Phase.INTRO)
	_update_camera(true)

func _set_phase(p: Phase) -> void:
	phase = p
	phase_frame = 0

func _round_logic() -> void:
	phase_frame += 1
	match phase:
		Phase.INTRO:
			if phase_frame == 1 and training:
				for f in fighters:
					f.controllable = true
				_set_phase(Phase.FIGHT)
				return
			if phase_frame >= 30:
				var final: bool = wins[0] == _rounds_to_win - 1 and wins[1] == _rounds_to_win - 1
				announce.emit("round_final" if final else "round_%d" % mini(round_number, 9), "round")
				Sfx.play("bell")
				_set_phase(Phase.CALL)
		Phase.CALL:
			if phase_frame >= 75:
				announce.emit("fight", "fight")
				Sfx.play("gong")
				for f in fighters:
					f.controllable = true
				_set_phase(Phase.FIGHT)
		Phase.FIGHT:
			if training:
				_training_upkeep()
				return
			timer_frames -= 1
			for i in 2:
				if fighters[i].state == Fighter.State.KO:
					_on_ko(1 - i)
					return
			if timer_frames <= 0:
				_on_timeout()
		Phase.KO:
			if phase_frame >= 100 and fighters[round_winner].state != Fighter.State.ATTACK:
				fighters[round_winner].win()
				var loser: int = 1 - round_winner
				if fighters[round_winner].hp >= _hp_at_round_start[round_winner] - 0.5:
					announce.emit("perfect", "perfect")
					Sfx.play("perfect")
				elif fighters[loser].hp > 0.0:
					pass
				_set_phase(Phase.ROUND_END)
		Phase.ROUND_END:
			if phase_frame >= 130:
				if round_winner >= 0:
					wins[round_winner] += 1
				if round_winner >= 0 and wins[round_winner] >= _rounds_to_win:
					announce.emit("winner_%d" % round_winner, "winner")
					Sfx.play("victory")
					_set_phase(Phase.OVER)
				else:
					round_number += 1
					_start_round()
		Phase.OVER:
			if phase_frame == 120:
				match_over.emit(round_winner)

func _on_ko(winner: int) -> void:
	round_winner = winner
	for f in fighters:
		f.controllable = false
	_slowmo = 80
	announce.emit("ko", "ko")
	Sfx.play("ko")
	shake(0.9)
	sparks.flash(Color(1.0, 0.95, 0.85), 0.8)
	_set_phase(Phase.KO)

func _on_timeout() -> void:
	for f in fighters:
		f.controllable = false
	var r0: float = fighters[0].hp / fighters[0].max_hp
	var r1: float = fighters[1].hp / fighters[1].max_hp
	round_winner = -1 if absf(r0 - r1) < 0.001 else (0 if r0 > r1 else 1)
	announce.emit("time_over" if round_winner >= 0 else "draw", "ko")
	Sfx.play("bell")
	if round_winner >= 0:
		fighters[round_winner].win()
	_set_phase(Phase.ROUND_END)

## Training: health refills a second after a combo, meter stays full.
func _training_upkeep() -> void:
	for i in 2:
		var f: Fighter = fighters[i]
		f.meter = 100.0 if i == 0 else f.meter
		if f.state in [Fighter.State.IDLE, Fighter.State.WALK, Fighter.State.CROUCH]:
			_regen_timer[i] += 1
			if _regen_timer[i] > 50:
				f.hp = f.max_hp
		else:
			_regen_timer[i] = 0
		if f.state == Fighter.State.KO:
			f.hp = f.max_hp
			f.reset_for_round(f.position.x, f.facing)
			f.controllable = true

# =============================================================================
# FRAME
# =============================================================================

func _physics_process(_delta: float) -> void:
	if freeze > 0:
		freeze -= 1
		_update_camera(false)
		return
	if _slowmo > 0:
		_slowmo -= 1
		_slow_tick += 1
		if _slow_tick % 3 != 0:
			_update_camera(false)
			return
	for f in fighters:
		f.step()
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Projectile = projectiles[i]
		p.step()
		if p.dead:
			projectiles.remove_at(i)
			p.queue_free()
	_resolve_pushboxes()
	if phase in [Phase.FIGHT, Phase.KO]:
		_resolve_hits()
		_resolve_projectiles()
	_round_logic()
	_update_camera(false)

func clamp_x(x: float) -> float:
	return clampf(x, WALL, STAGE_WIDTH - WALL)

func _resolve_pushboxes() -> void:
	var a: Fighter = fighters[0]
	var b: Fighter = fighters[1]
	if a.passes_through() or b.passes_through() or a.state == Fighter.State.THROWN or b.state == Fighter.State.THROWN:
		return
	if a.state in [Fighter.State.KO, Fighter.State.KNOCKDOWN] or b.state in [Fighter.State.KO, Fighter.State.KNOCKDOWN]:
		return
	var d: float = b.position.x - a.position.x
	if absf(d) > MAX_SEPARATION:
		var excess: float = (absf(d) - MAX_SEPARATION) * 0.5 * signf(d)
		a.position.x += excess
		b.position.x -= excess
	if absf(a.position.y - b.position.y) > 120.0:
		return
	var min_d: float = a.pushbox_half() + b.pushbox_half()
	if absf(d) >= min_d:
		return
	var s: float = signf(d) if absf(d) > 0.5 else float(a.facing)
	var overlap: float = min_d - absf(d)
	a.position.x = clamp_x(a.position.x - s * overlap * 0.5)
	b.position.x = clamp_x(b.position.x + s * overlap * 0.5)
	var still: float = min_d - absf(b.position.x - a.position.x)
	if still > 0.5:
		if a.position.x <= WALL + 0.5 or a.position.x >= STAGE_WIDTH - WALL - 0.5:
			b.position.x = clamp_x(b.position.x + s * still)
		else:
			a.position.x = clamp_x(a.position.x - s * still)

func _resolve_hits() -> void:
	var queue: Array[Dictionary] = []
	for i in 2:
		var a: Fighter = fighters[i]
		var d: Fighter = fighters[1 - i]
		if a.throwing_now():
			var reach: float = float(a.move.get("range", 80)) * float(a.style.get("scale", 1.0))
			if absf(a.position.x - d.position.x) <= reach and d.can_be_thrown():
				queue.append({kind = "throw", a = a, d = d, move = a.move})
			continue
		if not a.hitting_now():
			continue
		var hb: Rect2 = a.hitbox_world()
		for hurt in d.hurtboxes():
			if hb.intersects(hurt):
				var point: Vector2 = hb.intersection(hurt).get_center()
				queue.append({kind = "hit", a = a, d = d, hit = a.current_hit(), point = point})
				break
	for q in queue:
		if str(q["kind"]) == "throw":
			_start_throw(q["a"] as Fighter, q["d"] as Fighter, q["move"] as Dictionary)
		else:
			_apply_hit(q["a"] as Fighter, q["d"] as Fighter, q["hit"] as Dictionary, q["point"] as Vector2, false)

func _apply_hit(a: Fighter, d: Fighter, hit: Dictionary, point: Vector2, projectile: bool) -> String:
	var result: String = d.receive(a, hit, projectile)
	var damage: float = float(hit.get("damage", 0))
	var stop: int = int(hit.get("hitstop", 8))
	match result:
		"none":
			return result
		"block":
			if not projectile:
				a.register_contact(true)
				a.hitstop = int(stop * 0.7)
				a.meter = minf(a.meter + damage * 0.04, 100.0)
			d.hitstop = int(stop * 0.7)
			sparks.block(point, d.facing)
			Sfx.play("block", randf_range(0.95, 1.1))
			_wall_transfer(a, d)
			_info(a, d, hit, true)
		"armor":
			if not projectile:
				a.register_contact(true)
				a.hitstop = 6
			d.hitstop = 6
			sparks.armor(point)
			labels.add(d.position + Vector2(0.0, -220.0), StringManager.t("armor"), Color(1.0, 0.8, 0.4))
			Sfx.play("armor")
		"parry":
			var cs: Dictionary = d.move["counter_stance"] as Dictionary
			a.register_contact(true)
			a.parried(d)
			d.invuln = 20
			var counter_hit: Dictionary = {damage = cs.get("damage", 90), launch = cs.get("launch", [5.0, 9.0]), knockdown = true, hitstop = 14, away = d.facing}
			d.move_id = ""
			d.move = {}
			d._to_neutral()
			sparks.counter(point)
			labels.add(d.position + Vector2(0.0, -230.0), StringManager.t("parry"), Color(0.6, 0.95, 1.0))
			Sfx.play("parry")
			var res2: String = a.receive(d, counter_hit, false)
			a.hitstop = 14
			d.hitstop = 14
			shake(0.45)
			if res2 == "ko":
				return "ko"
		_:
			if not projectile:
				a.register_contact(false)
			var counter: bool = result == "counter"
			var frames: int = stop + (4 if counter else 0)
			a.hitstop = frames if not projectile else 0
			d.hitstop = frames
			a.meter = minf(a.meter + damage * 0.08, 100.0)
			var heavy: bool = damage >= 80.0 or bool(hit.get("knockdown", false))
			sparks.hit(point, a.facing if not projectile else int(hit.get("away", 1)), heavy, Color(str(a.style.get("eye", "ffffff"))))
			Sfx.play("hit_h" if heavy else "hit_l", randf_range(0.92, 1.08))
			if heavy:
				shake(0.35 if damage < 150.0 else 0.6)
			if counter:
				labels.add(d.position + Vector2(0.0, -230.0), StringManager.t("counter"), Color(1.0, 0.55, 0.3))
				Sfx.play("counter")
			_wall_transfer(a, d)
			_info(a, d, hit, false)
	return result

## Pushback against a wall moves the attacker instead.
func _wall_transfer(a: Fighter, d: Fighter) -> void:
	if d.position.x <= WALL + 2.0 or d.position.x >= STAGE_WIDTH - WALL - 2.0:
		a.push = -d.push
		d.push = 0.0

## Training display: frame advantage of the last hit or block.
func _info(a: Fighter, d: Fighter, hit: Dictionary, blocked: bool) -> void:
	if not training or a.move.is_empty():
		return
	var s: int = int(a.move.get("startup", 0))
	var act: int = int(a.move.get("active", 0))
	var rec: int = int(a.move.get("recovery", 0))
	var remaining: int = maxi(s + act - a.move_frame, 0) + rec
	var stun: int = int(hit.get("blockstun" if blocked else "hitstun", 0))
	last_info = {move = a.move_id, startup = s, damage = d.combo_damage, advantage = stun - remaining, blocked = blocked, launch = hit.has("launch") or bool(hit.get("knockdown", false))}

func _start_throw(a: Fighter, d: Fighter, move: Dictionary) -> void:
	var command: bool = bool(move.get("command", false))
	d.start_thrown(a, not command, move)
	a.register_contact(false)
	Sfx.play("grab")

func throw_teched(a: Fighter, d: Fighter) -> void:
	var dir: int = a.facing
	d.tech_release(dir)
	a.push = -dir * 9.0
	a.move_id = ""
	a.move = {}
	a.stun = 14
	a._set_state(Fighter.State.BLOCKSTUN)
	sparks.block((a.position + d.position) * 0.5 + Vector2(0.0, -120.0), dir)
	labels.add((a.position + d.position) * 0.5 + Vector2(0.0, -230.0), StringManager.t("tech"), Color(0.8, 0.9, 1.0))
	Sfx.play("tech")

func throw_land(a: Fighter, d: Fighter, move: Dictionary) -> void:
	var damage: float = float(move.get("damage", 100))
	d.throw_impact(damage, a.facing)
	sparks.hit(d.position + Vector2(0.0, -100.0), a.facing, true, Color(str(a.style.get("eye", "ffffff"))))
	shake(0.5)
	Sfx.play("hit_h")
	a.hitstop = 10
	d.hitstop = 10

func _resolve_projectiles() -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Projectile = projectiles[i]
		if p.dead:
			continue
		for k in range(projectiles.size()):
			var q: Projectile = projectiles[k]
			if q != p and not q.dead and q.owner_fighter != p.owner_fighter and p.box().intersects(q.box()):
				p.dead = true
				q.dead = true
				sparks.hit((p.position + q.position) * 0.5, 1, false, Color.WHITE)
				Sfx.play("proj_hit")
		if p.dead:
			continue
		var target: Fighter = p.owner_fighter.opponent
		for hurt in target.hurtboxes():
			if p.box().intersects(hurt):
				var hit: Dictionary = p.data.duplicate()
				hit["away"] = p.dir
				var result: String = _apply_hit(p.owner_fighter, target, hit, p.position, true)
				if result != "none":
					p.dead = true
					p.owner_fighter.meter = minf(p.owner_fighter.meter + 4.0, 100.0)
				break

# =============================================================================
# CALLS FROM FIGHTERS
# =============================================================================

func spawn_projectile(owner: Fighter, data: Dictionary) -> void:
	var p := Projectile.new()
	p.owner_fighter = owner
	p.data = data
	p.dir = owner.facing
	p.position = owner.position + Vector2(owner.facing * 60.0 * float(owner.style.get("scale", 1.0)), float(data.get("y", -120)))
	add_child(p)
	projectiles.append(p)
	Sfx.play("projectile")

func has_projectile(owner: Fighter) -> bool:
	for p in projectiles:
		if p.owner_fighter == owner and not p.dead:
			return true
	return false

func quake(owner: Fighter, data: Dictionary) -> void:
	var target: Fighter = owner.opponent
	sparks.quake(Vector2(owner.position.x, 0.0))
	shake(1.0)
	Sfx.play("quake")
	if not target.airborne:
		var hit: Dictionary = {damage = data.get("damage", 250), launch = data.get("launch", [4.0, 10.0]), knockdown = true, unblockable = true, hitstop = 14, away = owner.facing, height = "low"}
		_apply_hit(owner, target, hit, target.position + Vector2(0.0, -40.0), true)

func super_freeze(owner: Fighter, frames: int) -> void:
	freeze = frames
	freeze_owner = owner
	sparks.super_flash(owner.position + Vector2(0.0, -110.0), Color(str(owner.style.get("eye", "ffffff"))))
	labels.add(owner.position + Vector2(0.0, -250.0), StringManager.t(str(owner.moves["super"].get("name", ""))), Color(str(owner.style.get("eye", "ffffff"))), 26)
	Sfx.play("super")

func on_attack_started(_f: Fighter, _id: String) -> void:
	pass

func dust(at: Vector2, count: int) -> void:
	dust_fx.dust(at, count)

func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

# =============================================================================
# CAMERA
# =============================================================================

func _update_camera(snap: bool) -> void:
	var a: Fighter = fighters[0]
	var b: Fighter = fighters[1]
	var dist: float = absf(a.position.x - b.position.x)
	var view_w: float = clampf(dist + 440.0, 760.0, 1160.0)
	var zoom: float = 1280.0 / view_w
	var mid: float = (a.position.x + b.position.x) * 0.5
	var k: float = 1.0 if snap else 0.12
	_cam_zoom = lerpf(_cam_zoom, zoom, k)
	_cam_x = lerpf(_cam_x, mid, k * 1.5)
	var half_w: float = 640.0 / _cam_zoom
	var cx: float = clampf(_cam_x, half_w, STAGE_WIDTH - half_w)
	var top: float = minf(a.position.y, b.position.y)
	var cy: float = -262.0 / _cam_zoom - maxf(-top - 150.0, 0.0) * 0.45
	camera.zoom = Vector2(_cam_zoom, _cam_zoom)
	camera.position = Vector2(cx, cy)
	_trauma = maxf(_trauma - 0.035, 0.0)
	var amount: float = _trauma * _trauma * 14.0
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount
	stage.camera_center = camera.position
	stage.camera_zoom = _cam_zoom
	if snap:
		camera.reset_physics_interpolation()

func dim() -> float:
	return clampf(float(freeze) / 12.0, 0.0, 1.0) if freeze > 0 else 0.0
