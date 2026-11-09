extends Node

# SfxManager: procedural sound effects, no audio files (built by game_manager).
#
# SYNTHESIS: every sound is generated once at startup into an AudioStreamWAV
#   (16-bit mono PCM, 22 050 Hz) as a sum of voices written into a float
#   buffer: _tone() is an oscillator whose frequency glides from f0 to f1
#   with a short attack and a quadratic decay; _noise() is low-passed white
#   noise for impacts and explosions.
# PLAYBACK: a pool of AudioStreamPlayer nodes used round-robin, a minimum gap
#   per sound (ten shots a second must not turn into noise), and a small
#   random pitch jitter against the "machine-gun" effect.
# Volume: audio.master_volume x audio.sfx_volume from settings.json.

const MIX_RATE: int = 22050
const POOL_SIZE: int = 16
const BASE_DB: float = -6.0

enum Wave { SINE, SQUARE, TRIANGLE, SAW }

var _streams: Dictionary = {}     # name -> AudioStreamWAV
var _min_gap: Dictionary = {}     # name -> seconds between two plays
var _last_play: Dictionary = {}   # name -> msec timestamp
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _volume_db: float = BASE_DB

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("sfx")
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_build_combat_sounds()
	_build_ui_sounds()

func set_volume(linear: float) -> void:
	_volume_db = BASE_DB + linear_to_db(maxf(linear, 0.001))

## Plays a sound by name, with a random pitch variation of +/- pitch_jitter.
func play(sound: String, pitch_jitter: float = 0.05, volume_offset_db: float = 0.0) -> void:
	if not _streams.has(sound):
		return
	var now: int = Time.get_ticks_msec()
	var gap_ms: int = int(float(_min_gap.get(sound, 0.03)) * 1000.0)
	if now - int(_last_play.get(sound, -100000)) < gap_ms:
		return
	_last_play[sound] = now
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = _streams[sound] as AudioStreamWAV
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.volume_db = _volume_db + volume_offset_db
	player.play()

# ---------------------------------------------------------------------------
# Sound library
# ---------------------------------------------------------------------------

func _build_combat_sounds() -> void:
	var b: PackedFloat32Array = _buffer(0.05)            # Player shot: soft and short
	_tone(b, 0.0, 0.045, 1500.0, 700.0, Wave.TRIANGLE, 0.16)
	_add("shoot", b, 0.07)
	b = _buffer(0.08)                                    # Bullet hits an enemy
	_noise(b, 0.0, 0.06, 0.3, 0.6)
	_tone(b, 0.0, 0.07, 420.0, 260.0, Wave.SQUARE, 0.08)
	_add("hit", b, 0.03)
	b = _buffer(0.26)                                    # Small enemy explodes
	_noise(b, 0.0, 0.22, 0.42, 0.35)
	_tone(b, 0.0, 0.2, 520.0, 70.0, Wave.SQUARE, 0.12)
	_add("kill", b, 0.04)
	b = _buffer(0.7)                                     # Big enemy explodes
	_noise(b, 0.0, 0.6, 0.55, 0.18)
	_tone(b, 0.0, 0.6, 140.0, 38.0, Wave.SINE, 0.5)
	_add("kill_big", b, 0.2)
	b = _buffer(0.4)                                     # Hull hit
	_tone(b, 0.0, 0.36, 320.0, 70.0, Wave.SAW, 0.3)
	_noise(b, 0.0, 0.18, 0.4, 0.45)
	_add("hurt", b, 0.2)
	b = _buffer(0.45)                                    # Purge: rising whoosh
	_tone(b, 0.0, 0.4, 220.0, 1900.0, Wave.SINE, 0.24)
	_noise(b, 0.0, 0.4, 0.22, 0.9)
	_add("purge", b, 0.2)
	b = _buffer(0.55)                                    # Charger aims (telegraph)
	_tone(b, 0.0, 0.5, 260.0, 1100.0, Wave.SAW, 0.07)
	_add("charge", b, 0.25)
	b = _buffer(0.12)                                    # Enemy shot
	_tone(b, 0.0, 0.1, 760.0, 380.0, Wave.SINE, 0.16)
	_add("enemy_shot", b, 0.06)

func _build_ui_sounds() -> void:
	var b: PackedFloat32Array = _buffer(0.07)            # Void proximity beep
	_tone(b, 0.0, 0.06, 880.0, 860.0, Wave.SQUARE, 0.09)
	_add("warn", b, 0.08)
	b = _buffer(0.3)                                     # Pickup chime
	for i in 3:
		_tone(b, i * 0.06, 0.12, 660.0 * pow(1.26, i), 660.0 * pow(1.26, i), Wave.TRIANGLE, 0.22)
	_add("pickup", b, 0.1)
	b = _buffer(0.7)                                     # New sector
	_tone(b, 0.0, 0.3, 392.0, 392.0, Wave.TRIANGLE, 0.22)
	_tone(b, 0.18, 0.5, 587.0, 587.0, Wave.TRIANGLE, 0.22)
	_tone(b, 0.0, 0.6, 98.0, 92.0, Wave.SINE, 0.3)
	_add("sector", b, 0.5)
	b = _buffer(0.5)                                     # Run starts
	var notes: Array[float] = [330.0, 440.0, 554.0, 659.0]
	for i in notes.size():
		_tone(b, i * 0.07, 0.16, notes[i], notes[i], Wave.SQUARE, 0.08)
	_add("start", b, 0.3)
	b = _buffer(1.3)                                     # Game over
	_tone(b, 0.0, 0.4, 392.0, 370.0, Wave.SAW, 0.18)
	_tone(b, 0.4, 0.4, 311.0, 294.0, Wave.SAW, 0.18)
	_tone(b, 0.8, 0.5, 233.0, 150.0, Wave.SAW, 0.2)
	_add("gameover", b, 1.0)
	b = _buffer(0.04)                                    # UI click
	_tone(b, 0.0, 0.03, 1300.0, 900.0, Wave.SINE, 0.2)
	_add("click", b, 0.04)

# ---------------------------------------------------------------------------
# Synthesis helpers
# ---------------------------------------------------------------------------

func _buffer(duration: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(duration * MIX_RATE))
	return b

## Oscillator voice: frequency glides exponentially from f0 to f1.
func _tone(b: PackedFloat32Array, start: float, duration: float, f0: float, f1: float,
		wave: Wave, volume: float) -> void:
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
		var sample: float = _wave_sample(wave, phase)
		var envelope: float = minf(float(i) / attack, 1.0) * (1.0 - x) * (1.0 - x)
		b[first + i] += sample * envelope * volume

func _wave_sample(wave: Wave, phase: float) -> float:
	match wave:
		Wave.SQUARE:
			return 1.0 if phase < 0.5 else -1.0
		Wave.TRIANGLE:
			return 4.0 * absf(phase - 0.5) - 1.0
		Wave.SAW:
			return 2.0 * phase - 1.0
	return sin(phase * TAU)

## Low-passed white noise; cutoff in 0..1 (1 = unfiltered).
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
