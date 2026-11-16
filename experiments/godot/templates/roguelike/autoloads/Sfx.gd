# =============================================================================
# Sfx.gd (Autoload, Singleton): procedural sound effects, no audio files.
# =============================================================================
# SYNTHESIS:
#   Every sound is generated once at startup into an AudioStreamWAV (16-bit
#   mono PCM, 22 050 Hz). A sound is a sum of "voices" written into a float
#   buffer:
#     _tone():  oscillator (sine / square / triangle / saw) whose frequency
#                glides exponentially from f0 to f1, with an attack + decay
#                envelope.
#     _noise(): white noise through a one-pole low-pass filter, for impacts,
#                explosions and gunshots.
#   The buffer is then clipped and converted to 16-bit PCM bytes.
#
# PLAYBACK:
#   A pool of AudioStreamPlayer nodes is used round-robin, so overlapping
#   sounds never cut each other. Each sound has a minimum gap between two
#   plays (rate limiting): a held movement key or several enemies dying in the same
#   turn never turn into noise. A small random pitch jitter avoids the
#   "machine-gun effect" of identical repeated samples.
# =============================================================================

extends Node

signal mute_changed(is_muted: bool)

const MIX_RATE:  int = 22050
const POOL_SIZE: int = 16

enum Wave { SINE, SQUARE, TRIANGLE, SAW }

var muted: bool = false

var _streams:   Dictionary = {}   # name -> AudioStreamWAV
var _min_gap:   Dictionary = {}   # name -> seconds between two plays
var _last_play: Dictionary = {}   # name -> msec timestamp
var _players:   Array[AudioStreamPlayer] = []
var _next:      int   = 0
var _volume_db: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # UI clicks must sound while paused
	_volume_db = ConfigManager.get_float("sfx_volume_db", 0.0)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build_library()

## Plays a sound by name. pitch_jitter = random pitch variation (+/-);
## pitch = base pitch (the elan chime rises with each stack).
func play(sound: String, pitch_jitter: float = 0.05, volume_offset_db: float = 0.0, pitch: float = 1.0) -> void:
	if muted or not _streams.has(sound):
		return
	var now: int = Time.get_ticks_msec()
	var gap_ms: int = int(float(_min_gap.get(sound, 0.03)) * 1000.0)
	if now - int(_last_play.get(sound, -100000)) < gap_ms:
		return
	_last_play[sound] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream      = _streams[sound] as AudioStreamWAV
	p.pitch_scale = pitch + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db   = _volume_db + volume_offset_db
	p.play()

func toggle_mute() -> void:
	muted = not muted
	if muted:
		for p in _players:
			p.stop()
	mute_changed.emit(muted)

# ---------------------------------------------------------------------------
# Sound library: each entry mixes a few voices
# ---------------------------------------------------------------------------

func _build_library() -> void:
	var b: PackedFloat32Array

	b = _buf(0.05)                                     # Footstep
	_noise(b, 0.0, 0.04, 0.12, 0.15)
	_tone(b, 0.0, 0.04, 120.0, 80.0, Wave.SINE, 0.12)
	_add("step", b, 0.05)

	b = _buf(0.08)                                     # Wall bump
	_tone(b, 0.0, 0.07, 90.0, 60.0, Wave.SINE, 0.3)
	_add("bump", b, 0.15)

	b = _buf(0.14)                                     # Player hits an enemy
	_noise(b, 0.0, 0.08, 0.35, 0.5)
	_tone(b, 0.0, 0.10, 220.0, 110.0, Wave.SQUARE, 0.16)
	_add("hit", b, 0.03)

	b = _buf(0.26)                                     # Critical hit
	_noise(b, 0.0, 0.10, 0.45, 0.7)
	_tone(b, 0.0, 0.12, 260.0, 120.0, Wave.SQUARE, 0.18)
	_tone(b, 0.04, 0.20, 1400.0, 1700.0, Wave.TRIANGLE, 0.16)
	_add("crit", b, 0.05)

	b = _buf(0.30)                                     # Player gets hurt
	_tone(b, 0.0, 0.26, 260.0, 90.0, Wave.SAW, 0.26)
	_noise(b, 0.0, 0.10, 0.25, 0.3)
	_add("hurt", b, 0.06)

	b = _buf(0.22)                                     # Enemy dies
	_noise(b, 0.0, 0.16, 0.3, 0.35)
	_tone(b, 0.0, 0.18, 420.0, 70.0, Wave.SQUARE, 0.16)
	_add("kill", b, 0.04)

	b = _buf(0.20)                                     # Enemy notices you
	_tone(b, 0.0, 0.07, 660.0, 660.0, Wave.SQUARE, 0.12)
	_tone(b, 0.07, 0.12, 990.0, 990.0, Wave.SQUARE, 0.12)
	_add("alert", b, 0.12)

	b = _buf(0.9)                                      # Boss notices you
	_tone(b, 0.0, 0.85, 110.0, 82.0, Wave.SAW, 0.3)
	_tone(b, 0.0, 0.85, 55.0, 41.0, Wave.SINE, 0.4)
	_add("boss", b, 1.0)

	b = _buf(0.16)                                     # Arrow shot
	_noise(b, 0.0, 0.14, 0.22, 0.9)
	_tone(b, 0.0, 0.12, 1800.0, 700.0, Wave.SINE, 0.1)
	_add("shoot", b, 0.05)

	b = _buf(0.20)                                     # Pickup chime
	_tone(b, 0.0, 0.07, 880.0, 880.0, Wave.TRIANGLE, 0.2)
	_tone(b, 0.06, 0.13, 1320.0, 1320.0, Wave.TRIANGLE, 0.2)
	_add("pickup", b, 0.05)

	b = _buf(0.36)                                     # Permanent upgrade
	var notes_up: Array[float] = [523.0, 659.0, 784.0, 1047.0]
	for i in notes_up.size():
		_tone(b, i * 0.07, 0.14, notes_up[i], notes_up[i], Wave.TRIANGLE, 0.24)
	_add("upgrade", b, 0.1)

	b = _buf(0.40)                                     # Potion: bubbly rising gulps
	for i in 4:
		_tone(b, i * 0.08, 0.09, 300.0 + i * 90.0, 520.0 + i * 120.0, Wave.SINE, 0.28)
	_add("potion", b, 0.1)

	b = _buf(0.34)                                     # Eating: crunchy bursts
	for i in 3:
		_noise(b, i * 0.1, 0.07, 0.3, 0.45)
	_add("eat", b, 0.1)

	b = _buf(0.7)                                      # Thunder scroll
	_noise(b, 0.0, 0.12, 0.6, 1.0)
	_noise(b, 0.05, 0.6, 0.45, 0.08)
	_tone(b, 0.0, 0.5, 80.0, 40.0, Wave.SINE, 0.4)
	_add("thunder", b, 0.2)

	b = _buf(0.35)                                     # Blink: sweep up
	_tone(b, 0.0, 0.32, 300.0, 2400.0, Wave.SINE, 0.25)
	_tone(b, 0.0, 0.32, 450.0, 3600.0, Wave.TRIANGLE, 0.08)
	_add("blink", b, 0.2)

	b = _buf(0.30)                                     # Map: paper rustle
	_noise(b, 0.0, 0.12, 0.2, 0.8)
	_noise(b, 0.14, 0.12, 0.2, 0.8)
	_add("map", b, 0.2)

	b = _buf(0.75)                                     # Level up fanfare
	var notes_lv: Array[float] = [523.0, 659.0, 784.0, 1047.0, 1319.0]
	for i in notes_lv.size():
		_tone(b, i * 0.08, 0.22, notes_lv[i], notes_lv[i], Wave.SQUARE, 0.12)
		_tone(b, i * 0.08, 0.22, notes_lv[i], notes_lv[i], Wave.TRIANGLE, 0.16)
	_add("levelup", b, 0.3)

	b = _buf(0.7)                                      # Stairs: descending steps
	var notes_down: Array[float] = [784.0, 659.0, 523.0, 392.0]
	for i in notes_down.size():
		_tone(b, i * 0.12, 0.2, notes_down[i], notes_down[i], Wave.TRIANGLE, 0.22)
		_noise(b, i * 0.12, 0.04, 0.12, 0.2)
	_add("stairs", b, 0.3)

	b = _buf(0.20)                                     # Error buzz
	_tone(b, 0.0, 0.10, 170.0, 160.0, Wave.SQUARE, 0.14)
	_tone(b, 0.07, 0.11, 125.0, 120.0, Wave.SQUARE, 0.14)
	_add("error", b, 0.15)

	b = _buf(0.34)                                     # Jingling keys (far: played quieter)
	var notes_key: Array[float] = [2637.0, 3136.0, 2794.0, 3520.0, 2960.0]
	for i in notes_key.size():
		_tone(b, i * 0.045 + randf() * 0.01, 0.12, notes_key[i], notes_key[i] * 0.97, Wave.TRIANGLE, 0.12)
		_tone(b, i * 0.045, 0.05, notes_key[i] * 1.5, notes_key[i] * 1.5, Wave.SINE, 0.05)
	_add("jingle", b, 0.3)

	b = _buf(0.30)                                     # Thief panics: fast jingle + squeak
	for i in 6:
		_tone(b, i * 0.03, 0.06, 2900.0 + (i % 2) * 500.0, 2800.0, Wave.TRIANGLE, 0.1)
	_tone(b, 0.0, 0.14, 900.0, 1500.0, Wave.SQUARE, 0.08)
	_add("panic", b, 0.3)

	b = _buf(0.50)                                     # Thief out of breath
	for i in 2:
		_noise(b, i * 0.24, 0.18, 0.18, 0.25)
	_add("pant", b, 0.4)

	b = _buf(0.55)                                     # Key: bright arpeggio + metal
	var notes_k: Array[float] = [1047.0, 1319.0, 1568.0, 2093.0]
	for i in notes_k.size():
		_tone(b, i * 0.06, 0.3, notes_k[i], notes_k[i], Wave.TRIANGLE, 0.2)
	_tone(b, 0.0, 0.4, 3520.0, 3400.0, Wave.SINE, 0.06)
	_add("key", b, 0.15)

	b = _buf(0.80)                                     # Grille opens: clunk + rising rattle
	_noise(b, 0.0, 0.08, 0.5, 0.35)
	_tone(b, 0.0, 0.12, 140.0, 90.0, Wave.SQUARE, 0.2)
	for i in 8:
		_noise(b, 0.12 + i * 0.06, 0.04, 0.16, 0.7)
		_tone(b, 0.12 + i * 0.06, 0.05, 600.0 + i * 70.0, 560.0 + i * 70.0, Wave.SQUARE, 0.04)
	_tone(b, 0.55, 0.25, 784.0, 1568.0, Wave.TRIANGLE, 0.14)
	_add("unlock", b, 0.4)

	b = _buf(0.22)                                     # Grille locked: metal rattle
	for i in 3:
		_noise(b, i * 0.05, 0.05, 0.28, 0.8)
		_tone(b, i * 0.05, 0.05, 420.0, 380.0, Wave.SQUARE, 0.08)
	_add("locked", b, 0.2)

	b = _buf(0.14)                                     # Dagger throw: whoosh
	_noise(b, 0.0, 0.12, 0.3, 0.9)
	_tone(b, 0.0, 0.1, 900.0, 2200.0, Wave.SINE, 0.08)
	_add("throw", b, 0.06)

	b = _buf(0.32)                                     # Barrel breaks: wood crack + debris
	_noise(b, 0.0, 0.06, 0.6, 0.6)
	_tone(b, 0.0, 0.08, 180.0, 90.0, Wave.SQUARE, 0.18)
	for i in 4:
		_noise(b, 0.08 + i * 0.05, 0.04, 0.2, 0.4)
	_add("barrel", b, 0.08)

	b = _buf(0.24)                                     # Slime splits: wet blob
	_tone(b, 0.0, 0.2, 180.0, 520.0, Wave.SINE, 0.3)
	_tone(b, 0.06, 0.16, 140.0, 380.0, Wave.SINE, 0.2)
	_add("split", b, 0.08)

	b = _buf(0.20)                                     # Bones crushed
	for i in 4:
		_noise(b, i * 0.035, 0.03, 0.35, 0.9)
	_add("crush", b, 0.1)

	b = _buf(0.60)                                     # Skeleton rises: rattle + low swell
	for i in 7:
		_noise(b, i * 0.06, 0.03, 0.22, 0.85)
	_tone(b, 0.0, 0.55, 98.0, 147.0, Wave.SAW, 0.16)
	_add("rise", b, 0.3)

	b = _buf(0.22)                                     # Dash: airy whoosh, rising
	_noise(b, 0.0, 0.2, 0.35, 0.55)
	_tone(b, 0.0, 0.18, 300.0, 900.0, Wave.SINE, 0.12)
	_add("dash", b, 0.1)

	b = _buf(0.16)                                     # Knockback: short shove
	_noise(b, 0.0, 0.1, 0.3, 0.3)
	_tone(b, 0.0, 0.1, 160.0, 90.0, Wave.SINE, 0.22)
	_add("knock", b, 0.06)

	b = _buf(0.40)                                     # Impact against a wall: crunch + thud
	_noise(b, 0.0, 0.08, 0.7, 0.7)
	_tone(b, 0.0, 0.3, 110.0, 45.0, Wave.SINE, 0.5)
	for i in 3:
		_noise(b, 0.08 + i * 0.05, 0.05, 0.22, 0.5)
	_add("impact", b, 0.08)

	b = _buf(0.36)                                     # Stunned: little bird chirps
	for i in 3:
		_tone(b, i * 0.1, 0.08, 1800.0 + i * 200.0, 2400.0 + i * 200.0, Wave.SINE, 0.08)
	_add("stun", b, 0.2)

	b = _buf(0.40)                                     # Wind-up: rising growl
	_tone(b, 0.0, 0.38, 70.0, 140.0, Wave.SAW, 0.2)
	_noise(b, 0.0, 0.3, 0.12, 0.15)
	_add("windup", b, 0.15)

	b = _buf(0.28)                                     # Archer takes aim: bowstring creak
	_tone(b, 0.0, 0.26, 520.0, 760.0, Wave.TRIANGLE, 0.08)
	_noise(b, 0.0, 0.24, 0.08, 0.9)
	_add("aim", b, 0.15)

	b = _buf(0.50)                                     # Heavy blow lands: boom + rubble
	_noise(b, 0.0, 0.12, 0.8, 0.5)
	_tone(b, 0.0, 0.42, 90.0, 35.0, Wave.SINE, 0.6)
	for i in 4:
		_noise(b, 0.1 + i * 0.07, 0.05, 0.2, 0.5)
	_add("slam", b, 0.1)

	b = _buf(0.30)                                     # Interrupted: metallic clang
	_tone(b, 0.0, 0.28, 1250.0, 1180.0, Wave.TRIANGLE, 0.2)
	_tone(b, 0.0, 0.2, 1870.0, 1800.0, Wave.SINE, 0.1)
	_noise(b, 0.0, 0.04, 0.3, 0.9)
	_add("interrupt", b, 0.15)

	b = _buf(0.50)                                     # Fuse lit: crackling hiss
	_noise(b, 0.0, 0.48, 0.2, 0.95)
	for i in 6:
		_noise(b, i * 0.07, 0.02, 0.25, 1.0)
	_add("fuse", b, 0.2)

	b = _buf(0.16)                                     # Kicked keg: wooden thump
	_tone(b, 0.0, 0.12, 200.0, 120.0, Wave.TRIANGLE, 0.3)
	_noise(b, 0.0, 0.06, 0.25, 0.5)
	_add("kick", b, 0.08)

	b = _buf(1.0)                                      # Explosion: blast + rumble
	_noise(b, 0.0, 0.12, 1.0, 0.9)
	_noise(b, 0.05, 0.9, 0.6, 0.06)
	_tone(b, 0.0, 0.7, 70.0, 28.0, Wave.SINE, 0.6)
	_add("explode", b, 0.1)

	b = _buf(0.24)                                     # Elan: bright chime (pitched up per stack)
	_tone(b, 0.0, 0.2, 880.0, 880.0, Wave.TRIANGLE, 0.18)
	_tone(b, 0.03, 0.2, 1320.0, 1320.0, Wave.SINE, 0.12)
	_add("elan", b, 0.05)

	b = _buf(0.03)                                     # UI click
	_tone(b, 0.0, 0.025, 1300.0, 900.0, Wave.SINE, 0.2)
	_add("click", b, 0.04)

	b = _buf(1.3)                                      # Death
	_tone(b, 0.0, 0.35, 392.0, 370.0, Wave.SAW, 0.2)
	_tone(b, 0.35, 0.35, 311.0, 294.0, Wave.SAW, 0.2)
	_tone(b, 0.70, 0.60, 233.0, 160.0, Wave.SAW, 0.22)
	_add("death", b, 1.0)

	b = _buf(1.2)                                      # Victory
	var notes_win: Array[float] = [523.0, 659.0, 784.0]
	for i in notes_win.size():
		_tone(b, i * 0.12, 0.14, notes_win[i], notes_win[i], Wave.SQUARE, 0.14)
	_tone(b, 0.36, 0.8, 1047.0, 1047.0, Wave.TRIANGLE, 0.3)
	_tone(b, 0.36, 0.8, 784.0, 784.0, Wave.TRIANGLE, 0.18)
	_add("victory", b, 1.0)

# ---------------------------------------------------------------------------
# Synthesis helpers
# ---------------------------------------------------------------------------

func _buf(duration: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(duration * MIX_RATE))
	return b

## Adds an oscillator voice: frequency glides exponentially f0 -> f1.
## Envelope: 5 ms linear attack, then (1 - x)^2 decay to silence.
func _tone(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float,
		wave: Wave, vol: float) -> void:
	var i0: int = int(start * MIX_RATE)
	var n: int = mini(int(dur * MIX_RATE), b.size() - i0)
	var phase: float = 0.0
	var attack: float = 0.005 * MIX_RATE
	# Exponential glide as a per-sample multiplier: one pow() per voice instead
	# of one per sample (startup time matters in the Web export).
	var freq: float = f0
	var glide: float = pow(f1 / f0, 1.0 / float(maxi(n, 1)))
	for i in n:
		var x: float = float(i) / float(n)
		freq *= glide
		phase = fmod(phase + freq / MIX_RATE, 1.0)
		var s: float = 0.0
		match wave:
			Wave.SINE:     s = sin(phase * TAU)
			Wave.SQUARE:   s = 1.0 if phase < 0.5 else -1.0
			Wave.TRIANGLE: s = 4.0 * absf(phase - 0.5) - 1.0
			Wave.SAW:      s = 2.0 * phase - 1.0
		var env: float = minf(float(i) / attack, 1.0) * (1.0 - x) * (1.0 - x)
		b[i0 + i] += s * env * vol

## Adds low-passed white noise. cutoff in 0..1 (1 = unfiltered).
func _noise(b: PackedFloat32Array, start: float, dur: float, vol: float, cutoff: float) -> void:
	var i0: int = int(start * MIX_RATE)
	var n: int = mini(int(dur * MIX_RATE), b.size() - i0)
	var y: float = 0.0
	for i in n:
		var x: float = float(i) / float(n)
		y += cutoff * (randf_range(-1.0, 1.0) - y)
		b[i0 + i] += y * (1.0 - x) * (1.0 - x) * vol

func _add(sound: String, b: PackedFloat32Array, min_gap: float) -> void:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format   = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo   = false
	wav.data     = bytes
	_streams[sound] = wav
	_min_gap[sound] = min_gap
