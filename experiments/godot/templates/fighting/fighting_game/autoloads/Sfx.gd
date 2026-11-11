# =============================================================================
# Sfx.gd — Autoload (Singleton): procedural sound effects, no audio files
# =============================================================================
# Every sound is synthesized once at startup into an AudioStreamWAV (16-bit
# mono, 22 050 Hz) from oscillators gliding between two frequencies
# (_tone) and low-passed noise (_noise). A pool of players is used in turn,
# with a minimum gap per sound and a small pitch jitter so repeated sounds
# (punches, blocks) never sound mechanical. Heavy hits mix a low thump with
# a noise crack, light hits are shorter and higher.
# =============================================================================

extends Node

const MIX_RATE: int = 22050
const POOL_SIZE: int = 20
const VOLUME_DB: float = -9.0

enum Wave { SINE, SQUARE, TRIANGLE, SAW }

var muted: bool = false
var _streams: Dictionary = {}
var _min_gap: Dictionary = {}
var _last_play: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	muted = bool(SaveManager.get_setting("muted", false))
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_build_combat()
	_build_match()
	_build_ui()

func play(sound: String, pitch: float = 1.0, jitter: float = 0.05, volume_offset_db: float = 0.0) -> void:
	if muted or not _streams.has(sound):
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_play.get(sound, -100000)) < int(float(_min_gap.get(sound, 0.03)) * 1000.0):
		return
	_last_play[sound] = now
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = _streams[sound] as AudioStreamWAV
	player.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
	player.volume_db = VOLUME_DB + volume_offset_db
	player.play()

func set_muted(value: bool) -> void:
	muted = value
	SaveManager.set_setting("muted", value)

func _build_combat() -> void:
	var b: PackedFloat32Array = _buffer(0.12)          # Light swing: short air whoosh
	_noise(b, 0.0, 0.1, 0.25, 0.55)
	_add("whoosh_l", b, 0.04)
	b = _buffer(0.22)                                  # Heavy swing: longer, lower
	_noise(b, 0.0, 0.2, 0.32, 0.3)
	_tone(b, 0.0, 0.18, 260.0, 140.0, Wave.SINE, 0.08)
	_add("whoosh_h", b, 0.05)
	b = _buffer(0.12)                                  # Light hit: snap
	_noise(b, 0.0, 0.07, 0.45, 0.65)
	_tone(b, 0.0, 0.08, 420.0, 180.0, Wave.SQUARE, 0.08)
	_add("hit_l", b, 0.03)
	b = _buffer(0.3)                                   # Heavy hit: thump and crack
	_noise(b, 0.0, 0.14, 0.6, 0.5)
	_tone(b, 0.0, 0.25, 160.0, 50.0, Wave.SINE, 0.5)
	_tone(b, 0.0, 0.1, 700.0, 300.0, Wave.SQUARE, 0.06)
	_add("hit_h", b, 0.04)
	b = _buffer(0.18)                                  # Block: metal clank
	_tone(b, 0.0, 0.16, 1480.0, 1400.0, Wave.TRIANGLE, 0.14)
	_tone(b, 0.0, 0.12, 2220.0, 2100.0, Wave.SINE, 0.07)
	_noise(b, 0.0, 0.04, 0.2, 0.8)
	_add("block", b, 0.04)
	b = _buffer(0.4)                                   # Counter hit: bright ping
	_tone(b, 0.0, 0.35, 1760.0, 1760.0, Wave.SINE, 0.16)
	_tone(b, 0.05, 0.3, 2640.0, 2640.0, Wave.SINE, 0.08)
	_add("counter", b, 0.1)
	b = _buffer(0.5)                                   # Parry: two chimes
	_tone(b, 0.0, 0.25, 1320.0, 1320.0, Wave.TRIANGLE, 0.14)
	_tone(b, 0.12, 0.35, 1980.0, 1980.0, Wave.TRIANGLE, 0.12)
	_add("parry", b, 0.1)
	b = _buffer(0.25)                                  # Armor absorbing a hit
	_tone(b, 0.0, 0.22, 220.0, 200.0, Wave.SQUARE, 0.08)
	_noise(b, 0.0, 0.1, 0.3, 0.3)
	_add("armor", b, 0.08)
	b = _buffer(0.35)                                  # Body hitting the floor
	_noise(b, 0.0, 0.25, 0.5, 0.15)
	_tone(b, 0.0, 0.25, 110.0, 45.0, Wave.SINE, 0.5)
	_add("thud", b, 0.08)
	b = _buffer(0.15)                                  # Jump: spring
	_tone(b, 0.0, 0.14, 300.0, 620.0, Wave.SINE, 0.12)
	_noise(b, 0.0, 0.05, 0.1, 0.5)
	_add("jump", b, 0.05)
	b = _buffer(0.1)                                   # Landing
	_noise(b, 0.0, 0.08, 0.3, 0.2)
	_tone(b, 0.0, 0.08, 120.0, 70.0, Wave.SINE, 0.25)
	_add("land", b, 0.05)
	b = _buffer(0.2)                                   # Dash: steam burst
	_noise(b, 0.0, 0.18, 0.3, 0.8)
	_add("dash", b, 0.08)
	b = _buffer(0.15)                                  # Grab
	_tone(b, 0.0, 0.1, 300.0, 200.0, Wave.SQUARE, 0.08)
	_noise(b, 0.0, 0.06, 0.25, 0.4)
	_add("grab", b, 0.08)
	b = _buffer(0.25)                                  # Throw broken
	_tone(b, 0.0, 0.2, 900.0, 600.0, Wave.TRIANGLE, 0.12)
	_noise(b, 0.0, 0.08, 0.2, 0.7)
	_add("tech", b, 0.1)
	b = _buffer(0.35)                                  # Projectile: steam whistle
	_noise(b, 0.0, 0.3, 0.2, 0.9)
	_tone(b, 0.0, 0.3, 900.0, 1300.0, Wave.SINE, 0.07)
	_add("projectile", b, 0.1)
	b = _buffer(0.25)                                  # Projectiles cancelling out
	_noise(b, 0.0, 0.2, 0.4, 0.6)
	_tone(b, 0.0, 0.2, 600.0, 200.0, Wave.SINE, 0.1)
	_add("proj_hit", b, 0.08)

func _build_match() -> void:
	var b: PackedFloat32Array = _buffer(0.9)           # Super: charge rising
	for i in 6:
		_tone(b, i * 0.08, 0.3, 300.0 * pow(1.26, i), 300.0 * pow(1.26, i) * 1.1, Wave.SAW, 0.05)
	_tone(b, 0.0, 0.8, 120.0, 240.0, Wave.SINE, 0.25)
	_add("super", b, 0.3)
	b = _buffer(1.2)                                   # Quake
	_noise(b, 0.0, 1.1, 0.6, 0.08)
	_tone(b, 0.0, 1.0, 70.0, 30.0, Wave.SINE, 0.6)
	_add("quake", b, 0.5)
	b = _buffer(1.6)                                   # K.O.: boom and long tail
	_noise(b, 0.0, 0.6, 0.6, 0.3)
	_tone(b, 0.0, 1.4, 90.0, 30.0, Wave.SINE, 0.6)
	_tone(b, 0.1, 1.2, 440.0, 220.0, Wave.TRIANGLE, 0.1)
	_add("ko", b, 0.5)
	b = _buffer(1.4)                                   # Round bell
	for i in 2:
		_tone(b, i * 0.3, 1.0, 880.0, 880.0, Wave.SINE, 0.18)
		_tone(b, i * 0.3, 1.0, 1320.0, 1320.0, Wave.SINE, 0.07)
		_tone(b, i * 0.3, 0.8, 2200.0, 2200.0, Wave.SINE, 0.04)
	_add("bell", b, 0.5)
	b = _buffer(1.2)                                   # Fight: gong
	_tone(b, 0.0, 1.1, 196.0, 190.0, Wave.SINE, 0.3)
	_tone(b, 0.0, 1.0, 294.0, 290.0, Wave.TRIANGLE, 0.12)
	_noise(b, 0.0, 0.2, 0.25, 0.4)
	_add("gong", b, 0.5)
	b = _buffer(1.0)                                   # Perfect
	var notes: Array[float] = [784.0, 988.0, 1175.0, 1568.0]
	for i in notes.size():
		_tone(b, i * 0.08, 0.5, notes[i], notes[i], Wave.TRIANGLE, 0.12)
	_add("perfect", b, 0.5)
	b = _buffer(1.4)                                   # Victory fanfare
	var fan: Array[float] = [523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0]
	for i in fan.size():
		_tone(b, i * 0.12, 0.45, fan[i], fan[i], Wave.SQUARE, 0.06)
		_tone(b, i * 0.12, 0.5, fan[i] * 0.5, fan[i] * 0.5, Wave.TRIANGLE, 0.12)
	_add("victory", b, 0.5)

func _build_ui() -> void:
	var b: PackedFloat32Array = _buffer(0.05)          # Button
	_tone(b, 0.0, 0.04, 1200.0, 900.0, Wave.SINE, 0.16)
	_add("ui", b, 0.04)
	b = _buffer(0.04)                                  # Focus move
	_tone(b, 0.0, 0.03, 800.0, 800.0, Wave.SINE, 0.07)
	_add("ui_move", b, 0.03)
	b = _buffer(0.25)                                  # Pause
	_tone(b, 0.0, 0.1, 880.0, 880.0, Wave.TRIANGLE, 0.12)
	_tone(b, 0.1, 0.12, 660.0, 660.0, Wave.TRIANGLE, 0.12)
	_add("pause", b, 0.1)
	b = _buffer(0.35)                                  # Fighter selected
	_tone(b, 0.0, 0.12, 440.0, 660.0, Wave.SQUARE, 0.07)
	_tone(b, 0.1, 0.22, 880.0, 880.0, Wave.SINE, 0.14)
	_noise(b, 0.0, 0.08, 0.15, 0.5)
	_add("select", b, 0.1)

func _buffer(duration: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(duration * MIX_RATE))
	return b

func _tone(b: PackedFloat32Array, start: float, duration: float, f0: float, f1: float, wave: Wave, volume: float) -> void:
	var first: int = int(start * MIX_RATE)
	var count: int = mini(int(duration * MIX_RATE), b.size() - first)
	var phase: float = 0.0
	var attack: float = 0.004 * MIX_RATE
	var frequency: float = f0
	var glide: float = pow(f1 / f0, 1.0 / float(maxi(count, 1)))
	for i in count:
		var x: float = float(i) / float(count)
		frequency *= glide
		phase = fmod(phase + frequency / MIX_RATE, 1.0)
		var envelope: float = minf(float(i) / attack, 1.0) * (1.0 - x) * (1.0 - x)
		b[first + i] += _sample(wave, phase) * envelope * volume

func _sample(wave: Wave, phase: float) -> float:
	match wave:
		Wave.SQUARE:
			return 1.0 if phase < 0.5 else -1.0
		Wave.TRIANGLE:
			return 4.0 * absf(phase - 0.5) - 1.0
		Wave.SAW:
			return 2.0 * phase - 1.0
	return sin(phase * TAU)

func _noise(b: PackedFloat32Array, start: float, duration: float, volume: float, cutoff: float) -> void:
	var first: int = int(start * MIX_RATE)
	var count: int = mini(int(duration * MIX_RATE), b.size() - first)
	var filtered: float = 0.0
	for i in count:
		var x: float = float(i) / float(count)
		filtered += cutoff * (randf_range(-1.0, 1.0) - filtered)
		b[first + i] += filtered * (1.0 - x) * (1.0 - x) * volume

func _add(sound: String, b: PackedFloat32Array, min_gap: float) -> void:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	_streams[sound] = wav
	_min_gap[sound] = min_gap
