# =============================================================================
# Sfx.gd — Autoload (Singleton): procedural sound effects, no audio files
# =============================================================================
# Every sound is synthesized once at startup into an AudioStreamWAV (16-bit
# mono, 22 050 Hz) from oscillators gliding between two frequencies
# (_tone) and low-passed noise (_noise). A pool of players is used in turn,
# with a minimum gap per sound and a small pitch jitter so repeated sounds
# (shots, hits, gems) never sound mechanical. The shot is very quiet: it
# plays fifteen times per second.
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
	_build_player()
	_build_combat()
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

func _build_player() -> void:
	var b: PackedFloat32Array = _buffer(0.05)          # Shot: soft tick
	_tone(b, 0.0, 0.045, 1800.0, 900.0, Wave.SQUARE, 0.025)
	_noise(b, 0.0, 0.03, 0.05, 0.7)
	_add("shot", b, 0.06)
	b = _buffer(0.05)                                  # Graze: bright scrape
	_tone(b, 0.0, 0.04, 3200.0, 2600.0, Wave.SINE, 0.07)
	_noise(b, 0.0, 0.03, 0.06, 0.9)
	_add("graze", b, 0.035)
	b = _buffer(0.12)                                  # Gem: bling (pitch set by the caller)
	_tone(b, 0.0, 0.05, 1568.0, 1568.0, Wave.SQUARE, 0.04)
	_tone(b, 0.04, 0.08, 2349.0, 2349.0, Wave.SINE, 0.1)
	_add("gem", b, 0.03)
	b = _buffer(0.6)                                   # Power up: rising arpeggio
	var notes: Array[float] = [523.0, 659.0, 784.0, 1047.0, 1319.0]
	for i in notes.size():
		_tone(b, i * 0.06, 0.3, notes[i], notes[i], Wave.SQUARE, 0.06)
		_tone(b, i * 0.06, 0.3, notes[i], notes[i], Wave.SINE, 0.1)
	_add("power", b, 0.2)
	b = _buffer(1.3)                                   # Bomb: whoosh then boom
	_noise(b, 0.0, 0.5, 0.35, 0.08)
	_tone(b, 0.0, 0.5, 200.0, 1400.0, Wave.SAW, 0.06)
	_noise(b, 0.35, 0.9, 0.5, 0.15)
	_tone(b, 0.35, 0.9, 120.0, 30.0, Wave.SINE, 0.5)
	_add("bomb", b, 0.5)
	b = _buffer(1.0)                                   # Player destroyed
	_noise(b, 0.0, 0.7, 0.55, 0.25)
	_tone(b, 0.0, 0.8, 600.0, 60.0, Wave.SAW, 0.16)
	_tone(b, 0.0, 0.5, 90.0, 30.0, Wave.SINE, 0.45)
	_add("death", b, 0.5)
	b = _buffer(1.0)                                   # Extend: extra life
	var fanfare: Array[float] = [784.0, 988.0, 1175.0, 1568.0]
	for i in fanfare.size():
		_tone(b, i * 0.09, 0.5, fanfare[i], fanfare[i], Wave.SQUARE, 0.06)
		_tone(b, i * 0.09, 0.55, fanfare[i] * 0.5, fanfare[i] * 0.5, Wave.TRIANGLE, 0.12)
	_add("extend", b, 0.5)
	b = _buffer(0.12)                                  # Focus mode on
	_tone(b, 0.0, 0.1, 400.0, 260.0, Wave.SINE, 0.12)
	_add("focus", b, 0.1)

func _build_combat() -> void:
	var b: PackedFloat32Array = _buffer(0.05)          # Enemy hit: dull tick
	_noise(b, 0.0, 0.04, 0.12, 0.45)
	_tone(b, 0.0, 0.04, 520.0, 380.0, Wave.SQUARE, 0.03)
	_add("hit", b, 0.05)
	b = _buffer(0.3)                                   # Small explosion
	_noise(b, 0.0, 0.25, 0.4, 0.35)
	_tone(b, 0.0, 0.22, 260.0, 70.0, Wave.SQUARE, 0.08)
	_add("pop", b, 0.04)
	b = _buffer(0.8)                                   # Large explosion
	_noise(b, 0.0, 0.7, 0.55, 0.18)
	_tone(b, 0.0, 0.6, 140.0, 35.0, Wave.SINE, 0.5)
	_tone(b, 0.05, 0.4, 420.0, 90.0, Wave.SAW, 0.08)
	_add("boom", b, 0.12)
	b = _buffer(0.5)                                   # Bullets cancelled into gems
	for i in 6:
		_tone(b, i * 0.04, 0.2, 1200.0 * pow(1.12, i), 1200.0 * pow(1.12, i), Wave.SINE, 0.07)
	_noise(b, 0.0, 0.3, 0.1, 0.8)
	_add("cancel", b, 0.2)
	b = _buffer(1.6)                                   # Warning siren, two cycles
	for i in 2:
		_tone(b, i * 0.8, 0.4, 440.0, 660.0, Wave.SQUARE, 0.09)
		_tone(b, i * 0.8 + 0.4, 0.4, 660.0, 440.0, Wave.SQUARE, 0.09)
	_add("warning", b, 1.0)
	b = _buffer(1.0)                                   # Boss phase broken
	_noise(b, 0.0, 0.6, 0.5, 0.2)
	_tone(b, 0.0, 0.5, 110.0, 40.0, Wave.SINE, 0.45)
	_tone(b, 0.15, 0.7, 880.0, 880.0, Wave.TRIANGLE, 0.1)
	_tone(b, 0.25, 0.7, 1320.0, 1320.0, Wave.SINE, 0.07)
	_add("phase", b, 0.4)
	b = _buffer(2.2)                                   # Boss destroyed: long rumble
	_noise(b, 0.0, 2.0, 0.6, 0.1)
	_tone(b, 0.0, 2.0, 90.0, 25.0, Wave.SINE, 0.5)
	for i in 4:
		_noise(b, 0.2 + i * 0.3, 0.4, 0.35, 0.4)
	_add("boss_death", b, 1.0)
	b = _buffer(0.08)                                  # Enemy bullet volley (very soft)
	_tone(b, 0.0, 0.07, 700.0, 500.0, Wave.SINE, 0.05)
	_add("volley", b, 0.12)

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
	b = _buffer(0.9)                                   # Stage clear / new best
	for i in 6:
		_tone(b, i * 0.07, 0.4, 660.0 * pow(1.122, i), 660.0 * pow(1.122, i), Wave.SQUARE, 0.05)
		_tone(b, i * 0.07, 0.4, 660.0 * pow(1.122, i), 660.0 * pow(1.122, i), Wave.SINE, 0.1)
	_add("clear", b, 0.5)
	b = _buffer(0.06)                                  # Score tally tick
	_tone(b, 0.0, 0.05, 1500.0, 1500.0, Wave.SQUARE, 0.04)
	_add("tally", b, 0.04)

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
