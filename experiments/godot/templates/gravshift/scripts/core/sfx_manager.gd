extends Node

# SfxManager: procedural sound effects, no audio files (built by game_manager).
#
# SYNTHESIS: every sound is generated once at startup into an AudioStreamWAV
#   (16-bit mono PCM, 22 050 Hz): _tone() is an oscillator gliding from f0
#   to f1 with a short attack and a quadratic decay, _noise() is low-passed
#   white noise for impacts and explosions.
# PLAYBACK: a pool of players used in turn, a minimum gap per sound and a
#   small random pitch jitter. The capture tick is played at a pitch that
#   rises with the number of bullets in orbit, so filling the orbit sounds
#   like a charge building up.

const MIX_RATE: int = 22050
const POOL_SIZE: int = 20
const VOLUME_DB: float = -8.0

enum Wave { SINE, SQUARE, TRIANGLE, SAW }

var muted: bool = false
var _streams: Dictionary = {}
var _min_gap: Dictionary = {}
var _last_play: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_build_well_sounds()
	_build_combat_sounds()
	_build_ui_sounds()

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

func _build_well_sounds() -> void:
	var b: PackedFloat32Array = _buffer(0.35)          # Well opens: low rising hum
	_tone(b, 0.0, 0.33, 70.0, 140.0, Wave.SAW, 0.12)
	_tone(b, 0.0, 0.33, 140.0, 280.0, Wave.SINE, 0.16)
	_add("well_open", b, 0.15)
	b = _buffer(0.07)                                  # Bullet captured: glassy tick
	_tone(b, 0.0, 0.06, 1400.0, 1800.0, Wave.SINE, 0.16)
	_tone(b, 0.0, 0.04, 2800.0, 3200.0, Wave.TRIANGLE, 0.05)
	_add("capture", b, 0.025)
	b = _buffer(0.55)                                  # Fling: whoosh and chord
	_noise(b, 0.0, 0.3, 0.35, 0.7)
	_tone(b, 0.0, 0.45, 300.0, 900.0, Wave.SAW, 0.07)
	_tone(b, 0.02, 0.45, 450.0, 1350.0, Wave.SINE, 0.12)
	_add("fling", b, 0.12)
	b = _buffer(0.3)                                   # Shockwave thump
	_noise(b, 0.0, 0.2, 0.35, 0.2)
	_tone(b, 0.0, 0.25, 120.0, 50.0, Wave.SINE, 0.45)
	_add("shock", b, 0.1)
	b = _buffer(0.5)                                   # Well collapses: flux exhausted
	_tone(b, 0.0, 0.45, 400.0, 90.0, Wave.SQUARE, 0.08)
	_tone(b, 0.0, 0.45, 300.0, 70.0, Wave.SINE, 0.14)
	_add("collapse", b, 0.3)
	b = _buffer(0.05)                                  # Auto-fire: soft tick
	_tone(b, 0.0, 0.04, 1600.0, 1000.0, Wave.SQUARE, 0.025)
	_add("shot", b, 0.08)

func _build_combat_sounds() -> void:
	var b: PackedFloat32Array = _buffer(0.05)          # Enemy hit
	_noise(b, 0.0, 0.04, 0.15, 0.5)
	_tone(b, 0.0, 0.04, 600.0, 400.0, Wave.SQUARE, 0.03)
	_add("hit", b, 0.04)
	b = _buffer(0.3)                                   # Small explosion
	_noise(b, 0.0, 0.25, 0.42, 0.35)
	_tone(b, 0.0, 0.2, 280.0, 70.0, Wave.SQUARE, 0.08)
	_add("pop", b, 0.035)
	b = _buffer(0.8)                                   # Large explosion
	_noise(b, 0.0, 0.7, 0.55, 0.18)
	_tone(b, 0.0, 0.6, 140.0, 35.0, Wave.SINE, 0.5)
	_add("boom", b, 0.1)
	b = _buffer(0.25)                                  # Two enemies crashing
	_tone(b, 0.0, 0.2, 900.0, 600.0, Wave.TRIANGLE, 0.12)
	_tone(b, 0.0, 0.2, 1270.0, 820.0, Wave.SQUARE, 0.05)
	_noise(b, 0.0, 0.08, 0.3, 0.6)
	_add("crash", b, 0.06)
	b = _buffer(0.5)                                   # Hull hit
	_noise(b, 0.0, 0.3, 0.55, 0.3)
	_tone(b, 0.0, 0.4, 500.0, 90.0, Wave.SAW, 0.14)
	_add("player_hit", b, 0.2)
	b = _buffer(1.1)                                   # Ship destroyed
	_noise(b, 0.0, 0.9, 0.6, 0.2)
	_tone(b, 0.0, 1.0, 400.0, 40.0, Wave.SAW, 0.16)
	_tone(b, 0.0, 0.6, 90.0, 30.0, Wave.SINE, 0.45)
	_add("death", b, 0.5)
	b = _buffer(0.1)                                   # Enemy volley
	_tone(b, 0.0, 0.08, 700.0, 450.0, Wave.SINE, 0.06)
	_add("enemy_shot", b, 0.1)
	b = _buffer(0.25)                                  # Heavy orb
	_tone(b, 0.0, 0.22, 220.0, 120.0, Wave.SQUARE, 0.08)
	_noise(b, 0.0, 0.1, 0.15, 0.3)
	_add("heavy_shot", b, 0.15)
	b = _buffer(0.6)                                   # Repair
	for i in 4:
		_tone(b, i * 0.07, 0.3, 660.0 * pow(1.26, i), 660.0 * pow(1.26, i), Wave.TRIANGLE, 0.12)
	_add("repair", b, 0.3)
	b = _buffer(2.0)                                   # Boss destroyed
	_noise(b, 0.0, 1.8, 0.6, 0.1)
	_tone(b, 0.0, 1.8, 90.0, 25.0, Wave.SINE, 0.5)
	for i in 4:
		_noise(b, 0.2 + i * 0.3, 0.4, 0.35, 0.4)
	_add("boss_death", b, 1.0)

func _build_ui_sounds() -> void:
	var b: PackedFloat32Array = _buffer(0.8)           # Sector starts
	for i in 3:
		_tone(b, i * 0.12, 0.4, 440.0 * pow(1.335, i), 440.0 * pow(1.335, i), Wave.SINE, 0.14)
	_add("wave_start", b, 0.5)
	b = _buffer(0.9)                                   # Sector cleared
	var notes: Array[float] = [523.0, 659.0, 784.0, 1047.0]
	for i in notes.size():
		_tone(b, i * 0.09, 0.45, notes[i], notes[i], Wave.SQUARE, 0.06)
		_tone(b, i * 0.09, 0.45, notes[i], notes[i], Wave.SINE, 0.1)
	_add("wave_clear", b, 0.5)
	b = _buffer(1.6)                                   # Boss warning: siren
	for i in 2:
		_tone(b, i * 0.8, 0.4, 330.0, 520.0, Wave.SQUARE, 0.08)
		_tone(b, i * 0.8 + 0.4, 0.4, 520.0, 330.0, Wave.SQUARE, 0.08)
	_add("warning", b, 1.0)
	b = _buffer(0.5)                                   # Upgrade chosen
	for i in 5:
		_tone(b, i * 0.05, 0.25, 700.0 * pow(1.19, i), 700.0 * pow(1.19, i), Wave.SINE, 0.12)
	_add("upgrade", b, 0.2)
	b = _buffer(0.04)                                  # Focus move
	_tone(b, 0.0, 0.03, 800.0, 800.0, Wave.SINE, 0.07)
	_add("ui_move", b, 0.03)
	b = _buffer(0.06)                                  # Validate
	_tone(b, 0.0, 0.05, 1200.0, 900.0, Wave.SINE, 0.16)
	_add("ui_select", b, 0.04)

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
