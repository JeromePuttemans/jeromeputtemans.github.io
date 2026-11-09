# =============================================================================
# Sfx.gd — Autoload (Singleton): procedural sound effects, no audio files
# =============================================================================
# SYNTHESIS: every sound is generated once at startup into an AudioStreamWAV
#   (16-bit mono, 22 050 Hz) as a sum of voices: _tone() is an oscillator
#   gliding from f0 to f1 with a short attack and a quadratic decay; _noise()
#   is low-passed white noise.
# PLAYBACK: a pool of players used round-robin, a minimum gap per sound and a
#   random pitch jitter. play_click() raises the pitch with the overheat
#   gauge, so a fast clicking burst climbs like a scale.
# =============================================================================

extends Node

const MIX_RATE: int = 22050
const POOL_SIZE: int = 14
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
	_build_game_sounds()
	_build_event_sounds()

func play(sound: String, pitch: float = 1.0, jitter: float = 0.04, volume_offset_db: float = 0.0) -> void:
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

## Crystal strike: pitch rises with the overheat gauge (one octave at full).
func play_click(heat: float, critical: bool) -> void:
	play("crit" if critical else "click", pow(2.0, heat), 0.03, 0.0)

func toggle_mute() -> void:
	muted = not muted

# ---------------------------------------------------------------------------
# Library
# ---------------------------------------------------------------------------

func _build_game_sounds() -> void:
	var b: PackedFloat32Array = _buffer(0.18)          # Crystal strike: glassy ping
	_tone(b, 0.0, 0.16, 1320.0, 1300.0, Wave.SINE, 0.22)
	_tone(b, 0.0, 0.10, 2640.0, 2600.0, Wave.SINE, 0.08)
	_noise(b, 0.0, 0.02, 0.12, 0.8)
	_add("click", b, 0.025)
	b = _buffer(0.45)                                  # Critical strike
	for i in 3:
		_tone(b, i * 0.04, 0.35, 1320.0 * pow(1.5, i), 1320.0 * pow(1.5, i), Wave.SINE, 0.16)
	_noise(b, 0.0, 0.05, 0.2, 0.7)
	_add("crit", b, 0.05)
	b = _buffer(0.14)                                  # Producer bought
	_tone(b, 0.0, 0.06, 880.0, 880.0, Wave.TRIANGLE, 0.22)
	_tone(b, 0.05, 0.08, 1320.0, 1320.0, Wave.TRIANGLE, 0.22)
	_add("buy", b, 0.04)
	b = _buffer(0.12)                                  # Not enough shards
	_tone(b, 0.0, 0.1, 180.0, 150.0, Wave.SQUARE, 0.1)
	_add("deny", b, 0.15)
	b = _buffer(0.5)                                   # Upgrade bought
	var notes: Array[float] = [660.0, 830.0, 990.0, 1320.0]
	for i in notes.size():
		_tone(b, i * 0.06, 0.2, notes[i], notes[i], Wave.TRIANGLE, 0.2)
	_add("upgrade", b, 0.1)
	b = _buffer(0.8)                                   # Milestone reached
	var fanfare: Array[float] = [523.0, 659.0, 784.0, 1047.0]
	for i in fanfare.size():
		_tone(b, i * 0.09, 0.4, fanfare[i], fanfare[i], Wave.SQUARE, 0.07)
		_tone(b, i * 0.09, 0.4, fanfare[i], fanfare[i], Wave.SINE, 0.16)
	_add("milestone", b, 0.3)

func _build_event_sounds() -> void:
	var b: PackedFloat32Array = _buffer(0.7)           # Overheat starts
	_tone(b, 0.0, 0.6, 220.0, 880.0, Wave.SAW, 0.12)
	_tone(b, 0.0, 0.6, 330.0, 1320.0, Wave.SINE, 0.16)
	_add("frenzy_start", b, 0.5)
	b = _buffer(0.5)                                   # Overheat ends
	_tone(b, 0.0, 0.45, 660.0, 220.0, Wave.SINE, 0.16)
	_noise(b, 0.0, 0.4, 0.12, 0.2)
	_add("frenzy_end", b, 0.5)
	b = _buffer(0.9)                                   # Meteor appears
	_noise(b, 0.0, 0.85, 0.2, 0.08)
	_tone(b, 0.0, 0.8, 1800.0, 600.0, Wave.SINE, 0.08)
	_add("meteor", b, 0.5)
	b = _buffer(0.7)                                   # Meteor caught
	for i in 6:
		_tone(b, i * 0.05, 0.25, 1046.0 * pow(1.122, i), 1046.0 * pow(1.122, i), Wave.TRIANGLE, 0.14)
	_noise(b, 0.0, 0.1, 0.25, 0.6)
	_add("meteor_catch", b, 0.3)
	b = _buffer(1.6)                                   # Crystallization
	var chord: Array[float] = [261.6, 329.6, 392.0, 523.3, 659.3]
	for i in chord.size():
		_tone(b, i * 0.05, 1.4, chord[i], chord[i], Wave.SINE, 0.14)
		_tone(b, i * 0.05, 1.4, chord[i] * 2.0, chord[i] * 2.0, Wave.TRIANGLE, 0.04)
	_add("prestige", b, 1.0)
	b = _buffer(0.6)                                   # Offline gains collected
	for i in 4:
		_tone(b, i * 0.07, 0.25, 784.0 * pow(1.26, i), 784.0 * pow(1.26, i), Wave.SINE, 0.18)
	_add("collect", b, 0.3)
	b = _buffer(0.04)                                  # UI click
	_tone(b, 0.0, 0.03, 1300.0, 900.0, Wave.SINE, 0.18)
	_add("ui", b, 0.04)

# ---------------------------------------------------------------------------
# Synthesis helpers
# ---------------------------------------------------------------------------

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
		b[first + i] += _wave_sample(wave, phase) * envelope * volume

func _wave_sample(wave: Wave, phase: float) -> float:
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
