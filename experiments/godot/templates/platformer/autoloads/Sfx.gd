# =============================================================================
# Sfx.gd — Autoload (Singleton): procedural sound effects, no audio files
# =============================================================================
# Every sound is synthesized once at startup into an AudioStreamWAV (16-bit
# mono, 22 050 Hz) from oscillators gliding between two frequencies
# (_tone) and low-passed noise (_noise). A pool of players is used in turn,
# with a minimum gap per sound and a small pitch jitter so repeated sounds
# (steps, fireflies) never sound mechanical.
# =============================================================================

extends Node

const MIX_RATE: int = 22050
const POOL_SIZE: int = 14
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
	_build_movement()
	_build_world()
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

func _build_movement() -> void:
	var b: PackedFloat32Array = _buffer(0.14)          # Jump: quick upward chirp
	_tone(b, 0.0, 0.13, 330.0, 700.0, Wave.SQUARE, 0.07)
	_tone(b, 0.0, 0.13, 330.0, 700.0, Wave.SINE, 0.12)
	_add("jump", b, 0.05)
	b = _buffer(0.22)                                  # Air jump: airy swish, higher
	_tone(b, 0.0, 0.2, 600.0, 1250.0, Wave.SINE, 0.16)
	_tone(b, 0.03, 0.17, 900.0, 1800.0, Wave.TRIANGLE, 0.06)
	_noise(b, 0.0, 0.16, 0.12, 0.5)
	_add("air_jump", b, 0.05)
	b = _buffer(0.16)                                  # Wall jump: knock + chirp
	_noise(b, 0.0, 0.04, 0.3, 0.35)
	_tone(b, 0.02, 0.13, 420.0, 820.0, Wave.SQUARE, 0.07)
	_add("wall_jump", b, 0.05)
	b = _buffer(0.1)                                   # Landing: soft thud
	_noise(b, 0.0, 0.08, 0.35, 0.18)
	_tone(b, 0.0, 0.08, 140.0, 70.0, Wave.SINE, 0.3)
	_add("land", b, 0.06)
	b = _buffer(0.5)                                   # Death: pop and falling tone
	_noise(b, 0.0, 0.12, 0.4, 0.5)
	_tone(b, 0.0, 0.45, 620.0, 110.0, Wave.TRIANGLE, 0.2)
	_tone(b, 0.0, 0.45, 640.0, 115.0, Wave.SQUARE, 0.05)
	_add("death", b, 0.2)
	b = _buffer(0.35)                                  # Respawn: rising shimmer
	for i in 4:
		_tone(b, i * 0.05, 0.18, 520.0 * pow(1.26, i), 520.0 * pow(1.26, i), Wave.SINE, 0.12)
	_add("respawn", b, 0.2)

func _build_world() -> void:
	var b: PackedFloat32Array = _buffer(0.16)          # Firefly: bright blip (pitch rises in a streak)
	_tone(b, 0.0, 0.06, 1318.0, 1318.0, Wave.SQUARE, 0.06)
	_tone(b, 0.05, 0.1, 1976.0, 1976.0, Wave.SINE, 0.14)
	_add("firefly", b, 0.03)
	b = _buffer(0.9)                                   # Golden acorn: arpeggio
	var notes: Array[float] = [784.0, 988.0, 1175.0, 1568.0, 1976.0]
	for i in notes.size():
		_tone(b, i * 0.07, 0.5, notes[i], notes[i], Wave.TRIANGLE, 0.14)
		_tone(b, i * 0.07, 0.3, notes[i] * 2.0, notes[i] * 2.0, Wave.SINE, 0.04)
	_add("acorn", b, 0.3)
	b = _buffer(0.22)                                  # Stomp: squish + boing
	_noise(b, 0.0, 0.06, 0.4, 0.25)
	_tone(b, 0.03, 0.18, 200.0, 520.0, Wave.SQUARE, 0.08)
	_tone(b, 0.03, 0.18, 200.0, 520.0, Wave.SINE, 0.14)
	_add("stomp", b, 0.05)
	b = _buffer(0.4)                                   # Spring: wobbling boing
	var k: int = b.size()
	for i in k:
		var x: float = float(i) / float(k)
		var f: float = 180.0 + 500.0 * x
		b[i] += sin(TAU * f * float(i) / MIX_RATE + sin(x * 60.0) * 2.0) * (1.0 - x) * 0.22
	_add("spring", b, 0.1)
	b = _buffer(0.8)                                   # Lantern: warm chime
	_tone(b, 0.0, 0.7, 660.0, 660.0, Wave.SINE, 0.16)
	_tone(b, 0.0, 0.7, 990.0, 990.0, Wave.SINE, 0.08)
	_tone(b, 0.12, 0.6, 1320.0, 1320.0, Wave.TRIANGLE, 0.06)
	_add("checkpoint", b, 0.3)
	b = _buffer(0.09)                                  # Coloured blocks swap: click-clack
	_tone(b, 0.0, 0.04, 1500.0, 1100.0, Wave.SQUARE, 0.05)
	_tone(b, 0.04, 0.04, 900.0, 700.0, Wave.SQUARE, 0.05)
	_add("toggle", b, 0.04)
	b = _buffer(0.35)                                  # Crumble: rumble
	_noise(b, 0.0, 0.32, 0.3, 0.12)
	_tone(b, 0.0, 0.3, 90.0, 60.0, Wave.SAW, 0.08)
	_add("crumble", b, 0.08)
	b = _buffer(0.14)                                  # Spitter: pfft
	_noise(b, 0.0, 0.1, 0.25, 0.6)
	_tone(b, 0.0, 0.08, 500.0, 300.0, Wave.SINE, 0.1)
	_add("spit", b, 0.08)
	b = _buffer(1.2)                                   # Exit: fanfare
	var fanfare: Array[float] = [523.0, 659.0, 784.0, 1047.0]
	for i in fanfare.size():
		_tone(b, i * 0.11, 0.6, fanfare[i], fanfare[i], Wave.SQUARE, 0.06)
		_tone(b, i * 0.11, 0.7, fanfare[i], fanfare[i], Wave.SINE, 0.12)
	_tone(b, 0.44, 0.7, 1568.0, 1568.0, Wave.TRIANGLE, 0.08)
	_add("exit", b, 0.5)

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
	b = _buffer(0.8)                                   # New record
	for i in 6:
		_tone(b, i * 0.06, 0.35, 880.0 * pow(1.122, i), 880.0 * pow(1.122, i), Wave.SINE, 0.12)
	_add("record", b, 0.4)

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
