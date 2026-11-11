# =============================================================================
# Sfx.gd — Autoload (Singleton): procedural sound, no audio files
# =============================================================================
# Every sound is synthesized once at startup into an AudioStreamWAV (16-bit
# mono, 22 050 Hz) from oscillators gliding between two frequencies
# (_tone) and low-passed noise (_noise). A pool of players is used in turn,
# with a minimum gap per sound and a small pitch jitter so repeated sounds
# (steps, clock ticks) never sound mechanical.
# AMBIENCE: a seamless 4 s wind loop on its own player, louder while the
# player falls (set_wind), and a soft random bell every 9 to 16 s.
# =============================================================================

extends Node

const MIX_RATE: int = 22050
const POOL_SIZE: int = 16
const VOLUME_DB: float = -8.0
const WIND_DB: float = -20.0
const BELLS: Array[float] = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]

enum Wave { SINE, SQUARE, TRIANGLE, SAW }

var muted: bool = false
var _streams: Dictionary = {}
var _min_gap: Dictionary = {}
var _last_play: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _wind: AudioStreamPlayer = null
var _wind_target: float = WIND_DB
var _bell_timer: float = 6.0
var ambience: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	muted = bool(SaveManager.get_setting("muted", false))
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_build_body()
	_build_world()
	_build_ui()
	_build_wind()

func _process(delta: float) -> void:
	if _wind == null:
		return
	var target: float = -80.0 if (muted or not ambience) else _wind_target
	_wind.volume_db = move_toward(_wind.volume_db, target, delta * 30.0)
	if ambience and not muted:
		_bell_timer -= delta
		if _bell_timer <= 0.0:
			_bell_timer = randf_range(9.0, 16.0)
			play("bell", BELLS[randi() % BELLS.size()] / 659.25, 0.0, -10.0)

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
	player.pitch_scale = maxf(pitch * (1.0 + randf_range(-jitter, jitter)), 0.05)
	player.volume_db = VOLUME_DB + volume_offset_db
	player.play()

func set_muted(value: bool) -> void:
	muted = value
	SaveManager.set_setting("muted", value)

## 0 = calm breeze, 1 = rushing air (falling into the void).
func set_wind(intensity: float) -> void:
	_wind_target = lerpf(WIND_DB, -4.0, clampf(intensity, 0.0, 1.0))
	if _wind != null:
		_wind.pitch_scale = lerpf(1.0, 1.6, clampf(intensity, 0.0, 1.0))

func _build_body() -> void:
	var b: PackedFloat32Array = _buffer(0.09)          # Step on stone: dull knock
	_noise(b, 0.0, 0.06, 0.32, 0.2)
	_tone(b, 0.0, 0.07, 120.0, 80.0, Wave.SINE, 0.22)
	_add("step_stone", b, 0.12)
	b = _buffer(0.11)                                  # Step on grass: soft swish
	_noise(b, 0.0, 0.1, 0.22, 0.45)
	_tone(b, 0.0, 0.05, 140.0, 100.0, Wave.SINE, 0.1)
	_add("step_grass", b, 0.12)
	b = _buffer(0.32)                                  # Step on a shadow: hollow glassy note
	_tone(b, 0.0, 0.3, 196.0, 190.0, Wave.SINE, 0.2)
	_tone(b, 0.0, 0.22, 587.0, 587.0, Wave.SINE, 0.06)
	_tone(b, 0.0, 0.12, 1174.0, 1174.0, Wave.TRIANGLE, 0.025)
	_noise(b, 0.0, 0.04, 0.08, 0.3)
	_add("step_shadow", b, 0.12)
	b = _buffer(0.2)                                   # Jump: airy push
	_noise(b, 0.0, 0.16, 0.2, 0.35)
	_tone(b, 0.0, 0.14, 260.0, 420.0, Wave.SINE, 0.1)
	_add("jump", b, 0.08)
	b = _buffer(0.16)                                  # Landing: thud
	_noise(b, 0.0, 0.12, 0.42, 0.18)
	_tone(b, 0.0, 0.12, 110.0, 55.0, Wave.SINE, 0.34)
	_add("land", b, 0.08)
	b = _buffer(1.0)                                   # Fall: falling whistle
	_noise(b, 0.0, 0.95, 0.25, 0.5)
	_tone(b, 0.0, 0.95, 700.0, 140.0, Wave.SINE, 0.12)
	_add("fall", b, 0.5)
	b = _buffer(0.7)                                   # Respawn: rising shimmer
	for i in 5:
		var f: float = 523.25 * pow(1.2, i)
		_tone(b, i * 0.06, 0.4, f, f, Wave.SINE, 0.09)
	_add("respawn", b, 0.3)

func _build_world() -> void:
	var b: PackedFloat32Array = _buffer(0.03)          # Clock tick (each quarter hour)
	_tone(b, 0.0, 0.012, 2600.0, 1800.0, Wave.SQUARE, 0.06)
	_noise(b, 0.0, 0.02, 0.15, 0.9)
	_add("tick", b, 0.02)
	b = _buffer(0.9)                                   # Sun shard: bell (pitch rises in a streak)
	_tone(b, 0.0, 0.85, 1318.5, 1318.5, Wave.SINE, 0.18)
	_tone(b, 0.0, 0.5, 2637.0, 2637.0, Wave.SINE, 0.05)
	_tone(b, 0.0, 0.3, 3951.0, 3951.0, Wave.SINE, 0.025)
	_add("shard", b, 0.05)
	b = _buffer(1.8)                                   # Seal: rising bell arpeggio
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5, 1318.5]
	for i in notes.size():
		_tone(b, i * 0.12, 1.2, notes[i], notes[i], Wave.SINE, 0.14)
		_tone(b, i * 0.12, 0.6, notes[i] * 2.0, notes[i] * 2.0, Wave.TRIANGLE, 0.03)
	_add("seal", b, 0.5)
	b = _buffer(2.4)                                   # Seal set in its socket: deep gong
	_tone(b, 0.0, 2.3, 98.0, 97.0, Wave.SINE, 0.3)
	_tone(b, 0.0, 1.8, 196.0, 195.0, Wave.SINE, 0.14)
	_tone(b, 0.0, 1.2, 293.7, 293.0, Wave.SINE, 0.08)
	_tone(b, 0.0, 0.6, 587.0, 587.0, Wave.TRIANGLE, 0.03)
	_noise(b, 0.0, 0.08, 0.2, 0.3)
	_add("socket", b, 0.6)
	b = _buffer(1.2)                                   # Stone grinding (gnomon rising)
	_noise(b, 0.0, 1.15, 0.45, 0.08)
	_tone(b, 0.0, 1.15, 55.0, 52.0, Wave.SAW, 0.1)
	_tone(b, 0.0, 1.15, 41.0, 40.0, Wave.SINE, 0.25)
	_add("rumble", b, 0.4)
	b = _buffer(1.0)                                   # Light column: warp shimmer
	for i in 4:
		_tone(b, i * 0.05, 0.9, 330.0 * (i + 1), 660.0 * (i + 1), Wave.SINE, 0.07)
	_noise(b, 0.0, 0.8, 0.12, 0.6)
	_add("beam", b, 0.5)
	b = _buffer(1.4)                                   # Ambient bell
	_tone(b, 0.0, 1.35, 659.25, 659.25, Wave.SINE, 0.14)
	_tone(b, 0.0, 0.9, 1318.5, 1318.5, Wave.SINE, 0.03)
	_add("bell", b, 0.5)
	b = _buffer(2.6)                                   # Ending: slow major chord
	var chord: Array[float] = [261.63, 329.63, 392.0, 523.25, 659.25]
	for i in chord.size():
		_tone(b, i * 0.18, 2.2, chord[i], chord[i], Wave.SINE, 0.11)
	_add("ending", b, 1.0)

func _build_ui() -> void:
	var b: PackedFloat32Array = _buffer(0.05)          # Button
	_tone(b, 0.0, 0.04, 1200.0, 900.0, Wave.SINE, 0.16)
	_add("ui", b, 0.04)
	b = _buffer(0.04)                                  # Focus move
	_tone(b, 0.0, 0.03, 800.0, 800.0, Wave.SINE, 0.07)
	_add("ui_move", b, 0.03)
	b = _buffer(0.5)                                   # Tip: two soft notes
	_tone(b, 0.0, 0.3, 880.0, 880.0, Wave.SINE, 0.1)
	_tone(b, 0.12, 0.35, 1318.5, 1318.5, Wave.SINE, 0.08)
	_add("tip", b, 0.3)
	b = _buffer(0.9)                                   # Island name: low chime
	_tone(b, 0.0, 0.8, 392.0, 392.0, Wave.SINE, 0.12)
	_tone(b, 0.0, 0.8, 587.33, 587.33, Wave.SINE, 0.07)
	_add("island", b, 0.4)

## Seamless wind: low-passed noise with a slow swell, its last 0.5 s
## cross-faded into its first 0.5 s.
func _build_wind() -> void:
	var length: int = 4 * MIX_RATE
	var fade: int = MIX_RATE / 2
	var raw := PackedFloat32Array()
	raw.resize(length + fade)
	var low: float = 0.0
	var lower: float = 0.0
	for i in raw.size():
		low += 0.05 * (randf_range(-1.0, 1.0) - low)
		lower += 0.02 * (low - lower)
		var swell: float = 0.6 + 0.4 * sin(TAU * float(i) / float(length))
		raw[i] = (low * 0.5 + lower * 2.5) * swell
	var b := PackedFloat32Array()
	b.resize(length)
	for i in length:
		b[i] = raw[i]
		if i < fade:
			var k: float = float(i) / float(fade)
			b[i] = raw[i] * k + raw[length + i] * (1.0 - k)
	_add("wind", b, 0.0)
	var wav: AudioStreamWAV = _streams["wind"] as AudioStreamWAV
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = length
	_wind = AudioStreamPlayer.new()
	_wind.stream = wav
	_wind.volume_db = -80.0
	add_child(_wind)
	_wind.play()

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
