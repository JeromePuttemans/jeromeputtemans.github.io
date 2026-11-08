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
#   plays (rate limiting): ten Gatlings firing together still sound like a
#   rhythm, not like noise. A small random pitch jitter avoids the
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

## Plays a sound by name. pitch_jitter = random pitch variation (+/-).
func play(sound: String, pitch_jitter: float = 0.05, volume_offset_db: float = 0.0) -> void:
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
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
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

	b = _buf(0.07)                                     # Gatling shot
	_tone(b, 0.0, 0.05, 900.0, 420.0, Wave.SQUARE, 0.22)
	_noise(b, 0.0, 0.04, 0.18, 0.5)
	_add("gun", b, 0.045)

	b = _buf(0.30)                                     # Railgun crack
	_noise(b, 0.0, 0.10, 0.40, 0.9)
	_tone(b, 0.0, 0.22, 2400.0, 160.0, Wave.SAW, 0.22)
	_tone(b, 0.0, 0.18, 140.0, 70.0, Wave.SINE, 0.35)
	_add("rail", b, 0.06)

	b = _buf(0.20)                                     # Mortar launch thump
	_tone(b, 0.0, 0.18, 150.0, 55.0, Wave.SINE, 0.55)
	_noise(b, 0.0, 0.08, 0.22, 0.25)
	_add("mortar", b, 0.05)

	b = _buf(0.50)                                     # Shell explosion
	_noise(b, 0.0, 0.45, 0.60, 0.10)
	_tone(b, 0.0, 0.35, 95.0, 32.0, Wave.SINE, 0.55)
	_add("boom", b, 0.06)

	b = _buf(0.04)                                     # Bullet impact tick
	_tone(b, 0.0, 0.03, 420.0, 260.0, Wave.SQUARE, 0.10)
	_add("hit", b, 0.05)

	b = _buf(0.07)                                     # Armor deflect "clank"
	_tone(b, 0.0, 0.06, 1500.0, 1250.0, Wave.TRIANGLE, 0.16)
	_tone(b, 0.0, 0.05, 2300.0, 2100.0, Wave.SINE, 0.08)
	_add("clank", b, 0.07)

	b = _buf(0.11)                                     # Enemy pop
	_tone(b, 0.0, 0.09, 480.0, 1150.0, Wave.TRIANGLE, 0.30)
	_noise(b, 0.0, 0.03, 0.12, 0.6)
	_add("kill", b, 0.03)

	b = _buf(0.20)                                     # Coin chime
	_tone(b, 0.0, 0.07, 988.0, 988.0, Wave.SQUARE, 0.14)
	_tone(b, 0.06, 0.13, 1319.0, 1319.0, Wave.SQUARE, 0.14)
	_add("coin", b, 0.05)

	b = _buf(0.16)                                     # Tower placed
	_tone(b, 0.0, 0.13, 230.0, 105.0, Wave.SINE, 0.55)
	_noise(b, 0.0, 0.07, 0.25, 0.3)
	_add("place", b, 0.05)

	b = _buf(0.34)                                     # Upgrade arpeggio
	var notes_up: Array[float] = [523.0, 659.0, 784.0, 1047.0]
	for i in notes_up.size():
		_tone(b, i * 0.06, 0.12, notes_up[i], notes_up[i], Wave.TRIANGLE, 0.26)
	_add("upgrade", b, 0.1)

	b = _buf(0.20)                                     # Sell (descending coins)
	_tone(b, 0.0, 0.07, 1319.0, 1319.0, Wave.SQUARE, 0.13)
	_tone(b, 0.06, 0.13, 988.0, 988.0, Wave.SQUARE, 0.13)
	_add("sell", b, 0.1)

	b = _buf(0.45)                                     # Enemy reached the base
	_tone(b, 0.0, 0.40, 240.0, 70.0, Wave.SAW, 0.32)
	_noise(b, 0.0, 0.20, 0.18, 0.2)
	_add("leak", b, 0.12)

	b = _buf(0.55)                                     # Wave start horn
	_tone(b, 0.0, 0.16, 392.0, 392.0, Wave.SQUARE, 0.16)
	_tone(b, 0.0, 0.16, 392.0, 392.0, Wave.TRIANGLE, 0.2)
	_tone(b, 0.16, 0.36, 523.0, 523.0, Wave.SQUARE, 0.16)
	_tone(b, 0.16, 0.36, 523.0, 523.0, Wave.TRIANGLE, 0.2)
	_add("wave", b, 0.3)

	b = _buf(0.55)                                     # Wave cleared jingle
	var notes_clear: Array[float] = [523.0, 659.0, 784.0, 1047.0, 1319.0]
	for i in notes_clear.size():
		_tone(b, i * 0.07, 0.16, notes_clear[i], notes_clear[i], Wave.TRIANGLE, 0.24)
	_add("clear", b, 0.3)

	b = _buf(0.20)                                     # Error buzz
	_tone(b, 0.0, 0.10, 170.0, 160.0, Wave.SQUARE, 0.16)
	_tone(b, 0.07, 0.11, 125.0, 120.0, Wave.SQUARE, 0.16)
	_add("error", b, 0.15)

	b = _buf(0.03)                                     # UI click
	_tone(b, 0.0, 0.025, 1300.0, 900.0, Wave.SINE, 0.22)
	_add("click", b, 0.04)

	b = _buf(1.20)                                     # Defeat
	_tone(b, 0.0, 0.30, 392.0, 370.0, Wave.SAW, 0.2)
	_tone(b, 0.30, 0.30, 330.0, 311.0, Wave.SAW, 0.2)
	_tone(b, 0.60, 0.60, 262.0, 196.0, Wave.SAW, 0.22)
	_add("defeat", b, 1.0)

	b = _buf(1.10)                                     # Victory fanfare
	var notes_win: Array[float] = [523.0, 659.0, 784.0]
	for i in notes_win.size():
		_tone(b, i * 0.12, 0.14, notes_win[i], notes_win[i], Wave.SQUARE, 0.14)
	_tone(b, 0.36, 0.70, 1047.0, 1047.0, Wave.TRIANGLE, 0.3)
	_tone(b, 0.36, 0.70, 784.0, 784.0, Wave.TRIANGLE, 0.18)
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
