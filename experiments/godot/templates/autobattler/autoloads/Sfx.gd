# =============================================================================
# Sfx.gd — Autoload (Singleton): procedural sound effects, no audio files
# =============================================================================
# Every sound is synthesized once at startup into an AudioStreamWAV (16-bit
# mono, 22 050 Hz) from oscillators gliding between two frequencies
# (_tone) and low-passed noise (_noise). A pool of players is used
# round-robin, with a minimum gap per sound and a small pitch jitter so a
# battle full of hits never turns into a machine gun.
# =============================================================================

extends Node

const MIX_RATE: int = 22050
const POOL_SIZE: int = 18
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
	_build_shop_sounds()
	_build_battle_sounds()

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

func toggle_mute() -> void:
	muted = not muted

func _build_shop_sounds() -> void:
	var b: PackedFloat32Array = _buffer(0.16)          # Buy: coin
	_tone(b, 0.0, 0.07, 1046.0, 1046.0, Wave.SQUARE, 0.08)
	_tone(b, 0.06, 0.1, 1568.0, 1568.0, Wave.SQUARE, 0.08)
	_add("buy", b, 0.05)
	b = _buffer(0.2)                                   # Sell
	_tone(b, 0.0, 0.18, 784.0, 392.0, Wave.TRIANGLE, 0.2)
	_add("sell", b, 0.05)
	b = _buffer(0.28)                                  # Reroll: shuffle
	for i in 4:
		_noise(b, i * 0.05, 0.05, 0.18, 0.6)
	_tone(b, 0.0, 0.25, 500.0, 900.0, Wave.SINE, 0.1)
	_add("reroll", b, 0.1)
	b = _buffer(0.5)                                   # Level up
	var notes: Array[float] = [392.0, 523.0, 659.0, 784.0]
	for i in notes.size():
		_tone(b, i * 0.07, 0.2, notes[i], notes[i], Wave.TRIANGLE, 0.2)
	_add("level", b, 0.2)
	b = _buffer(0.8)                                   # Merge: star up
	for i in 5:
		_tone(b, i * 0.06, 0.4, 659.0 * pow(1.19, i), 659.0 * pow(1.19, i), Wave.SINE, 0.16)
	_noise(b, 0.0, 0.2, 0.15, 0.7)
	_add("merge", b, 0.2)
	b = _buffer(0.08)                                  # Place on the board
	_tone(b, 0.0, 0.07, 300.0, 220.0, Wave.SINE, 0.3)
	_noise(b, 0.0, 0.04, 0.1, 0.4)
	_add("place", b, 0.04)
	b = _buffer(0.15)                                  # Refused
	_tone(b, 0.0, 0.12, 170.0, 150.0, Wave.SQUARE, 0.1)
	_add("deny", b, 0.15)
	b = _buffer(0.04)                                  # UI click
	_tone(b, 0.0, 0.03, 1300.0, 900.0, Wave.SINE, 0.18)
	_add("ui", b, 0.04)

func _build_battle_sounds() -> void:
	var b: PackedFloat32Array = _buffer(0.6)           # Battle starts: horn
	_tone(b, 0.0, 0.55, 220.0, 233.0, Wave.SAW, 0.14)
	_tone(b, 0.0, 0.55, 330.0, 349.0, Wave.SAW, 0.1)
	_add("battle", b, 0.5)
	b = _buffer(0.1)                                   # Melee hit
	_noise(b, 0.0, 0.08, 0.3, 0.5)
	_tone(b, 0.0, 0.07, 240.0, 140.0, Wave.SQUARE, 0.08)
	_add("hit", b, 0.035)
	b = _buffer(0.18)                                  # Critical hit
	_noise(b, 0.0, 0.12, 0.4, 0.6)
	_tone(b, 0.0, 0.15, 900.0, 1400.0, Wave.TRIANGLE, 0.14)
	_add("crit", b, 0.06)
	b = _buffer(0.12)                                  # Arrow
	_noise(b, 0.0, 0.1, 0.12, 0.9)
	_tone(b, 0.0, 0.09, 1400.0, 700.0, Wave.SINE, 0.07)
	_add("arrow", b, 0.05)
	b = _buffer(0.4)                                   # Spell
	_tone(b, 0.0, 0.35, 440.0, 1320.0, Wave.SINE, 0.16)
	_tone(b, 0.0, 0.35, 660.0, 1980.0, Wave.TRIANGLE, 0.06)
	_add("spell", b, 0.1)
	b = _buffer(0.45)                                  # Area spell, slam
	_noise(b, 0.0, 0.4, 0.45, 0.2)
	_tone(b, 0.0, 0.4, 160.0, 50.0, Wave.SINE, 0.4)
	_add("boom", b, 0.12)
	b = _buffer(0.35)                                  # Heal
	_tone(b, 0.0, 0.3, 660.0, 990.0, Wave.SINE, 0.16)
	_tone(b, 0.08, 0.25, 880.0, 1320.0, Wave.SINE, 0.1)
	_add("heal", b, 0.1)
	b = _buffer(0.3)                                   # Shield
	_tone(b, 0.0, 0.28, 520.0, 520.0, Wave.TRIANGLE, 0.18)
	_tone(b, 0.0, 0.28, 780.0, 780.0, Wave.SINE, 0.1)
	_add("shield", b, 0.1)
	b = _buffer(0.35)                                  # Unit defeated
	_noise(b, 0.0, 0.3, 0.3, 0.3)
	_tone(b, 0.0, 0.3, 300.0, 80.0, Wave.SAW, 0.12)
	_add("death", b, 0.06)
	b = _buffer(0.9)                                   # Battle won
	var win: Array[float] = [523.0, 659.0, 784.0, 1047.0]
	for i in win.size():
		_tone(b, i * 0.1, 0.45, win[i], win[i], Wave.SQUARE, 0.08)
		_tone(b, i * 0.1, 0.45, win[i], win[i], Wave.SINE, 0.14)
	_add("win", b, 0.5)
	b = _buffer(0.9)                                   # Battle lost
	_tone(b, 0.0, 0.4, 392.0, 370.0, Wave.SAW, 0.14)
	_tone(b, 0.35, 0.5, 294.0, 220.0, Wave.SAW, 0.14)
	_add("lose", b, 0.5)

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
