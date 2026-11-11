# =============================================================================
# Sfx.gd — Autoload (Singleton): synthesized sound and boogie-woogie music
# =============================================================================
# Mondrian loved boogie-woogie: the game plays a walking bass that speeds up
# with the level, and every cleared line plays a piano chord of the bar in
# progress, so clearing lines plays along with the music.
#
# SYNTHESIS (once at startup, 16-bit mono 22 050 Hz):
#   piano   a C4 note: four harmonics with exponential decay and a short
#           hammer noise; every other note is this sample re-pitched
#           (pitch_scale = 2 ^ (semitones / 12))
#   bass    the same recipe at C2, rounder
#   effects clicks, thuds and swishes from gliding oscillators and noise
# MUSIC: a 12-bar blues in C (I I I I IV IV I I V IV I V), eight swung
#   eighth notes per bar (long-short, 2:1) on the classic boogie pattern
#   0 4 7 9 10 9 7 4 from the bar's root, a soft hi-hat on the off-beats.
#   Tempo: music_bpm + music_bpm_per_level x (level - 1), at most music_bpm_max.
# =============================================================================

extends Node

const MIX_RATE: int = 22050
const POOL_SIZE: int = 20
const VOLUME_DB: float = -7.0
const MUSIC_DB: float = -13.0
const PROGRESSION: Array[int] = [0, 0, 0, 0, 5, 5, 0, 0, 7, 5, 0, 7]
const PATTERN: Array[int] = [0, 4, 7, 9, 10, 9, 7, 4]
const DOMINANT: Array[int] = [0, 4, 7, 10]

enum Wave { SINE, SQUARE, TRIANGLE, SAW }

var muted: bool = false
var music_on: bool = true
var playing_music: bool = false
var bpm: float = 112.0
var beat_pulse: float = 0.0          # 1 on each beat, decays: the frame breathes with it

var _streams: Dictionary = {}
var _min_gap: Dictionary = {}
var _last_play: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _music_players: Array[AudioStreamPlayer] = []
var _next_music: int = 0
var _step: int = 0
var _bar: int = 0
var _step_time: float = 0.0
var _queue: Array[Dictionary] = []   # delayed notes {t, sound, pitch, db}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	muted = bool(SaveManager.get_setting("muted", false))
	music_on = bool(SaveManager.get_setting("music", true))
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_music_players.append(p)
	_build_instruments()
	_build_effects()

# --- public -----------------------------------------------------------------------

func play(sound: String, pitch: float = 1.0, jitter: float = 0.04, volume_offset_db: float = 0.0) -> void:
	if muted or not _streams.has(sound):
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_play.get(sound, -100000)) < int(float(_min_gap.get(sound, 0.0)) * 1000.0):
		return
	_last_play[sound] = now
	var p: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	p.stream = _streams[sound] as AudioStreamWAV
	p.pitch_scale = maxf(pitch * (1.0 + randf_range(-jitter, jitter)), 0.05)
	p.volume_db = VOLUME_DB + volume_offset_db
	p.play()

## Piano note, in semitones from C4.
func piano(semitone: int, volume_offset_db: float = 0.0, delay: float = 0.0) -> void:
	if delay > 0.0:
		_queue.append({t = delay, sound = "piano", pitch = pow(2.0, semitone / 12.0), db = volume_offset_db})
	else:
		play("piano", pow(2.0, semitone / 12.0), 0.0, volume_offset_db)

## Chord of the bar the music is in (dominant seventh), `voices` notes from
## the root, `octave` octaves up. Used for cleared lines.
func bar_chord(voices: int, octave: int, volume_offset_db: float = 0.0) -> void:
	var root: int = PROGRESSION[_bar % PROGRESSION.size()]
	for i in mini(voices, 6):
		var note: int = root + DOMINANT[i % 4] + 12 * (octave + floori(i / 4.0))
		piano(note, volume_offset_db - i * 1.5, i * 0.025)

## Rising arpeggio of the bar's chord (flat areas, records).
func arpeggio(count: int, start_octave: int, spacing: float, volume_offset_db: float = 0.0) -> void:
	var root: int = PROGRESSION[_bar % PROGRESSION.size()]
	for i in count:
		piano(root + DOMINANT[i % 4] + 12 * (start_octave + floori(i / 4.0)), volume_offset_db, i * spacing)

func set_muted(value: bool) -> void:
	muted = value
	SaveManager.set_setting("muted", value)

func set_music(value: bool) -> void:
	music_on = value
	SaveManager.set_setting("music", value)

func start_music(level: int) -> void:
	playing_music = true
	set_level(level)
	_step = 0
	_bar = 0
	_step_time = 0.0

func stop_music() -> void:
	playing_music = false

## Resumes after a pause, where the music was.
func resume_music() -> void:
	playing_music = true

func set_level(level: int) -> void:
	bpm = minf(ConfigManager.get_float("music_bpm", 112.0) + ConfigManager.get_float("music_bpm_per_level", 6.0) * (level - 1), ConfigManager.get_float("music_bpm_max", 172.0))

# --- sequencer ---------------------------------------------------------------------

func _process(delta: float) -> void:
	beat_pulse = maxf(beat_pulse - delta * 3.0, 0.0)
	for i in range(_queue.size() - 1, -1, -1):
		_queue[i]["t"] = float(_queue[i]["t"]) - delta
		if float(_queue[i]["t"]) <= 0.0:
			var q: Dictionary = _queue[i]
			_queue.remove_at(i)
			play(str(q["sound"]), float(q["pitch"]), 0.0, float(q["db"]))
	if not playing_music:
		return
	_step_time -= delta
	while _step_time <= 0.0:
		_play_step()
		var beat: float = 60.0 / bpm
		_step_time += beat * (2.0 / 3.0 if _step % 2 == 0 else 1.0 / 3.0)
		_step += 1
		if _step >= PATTERN.size():
			_step = 0
			_bar = (_bar + 1) % PROGRESSION.size()

func _play_step() -> void:
	if _step % 2 == 0:
		beat_pulse = 1.0
	if muted or not music_on:
		return
	var root: int = PROGRESSION[_bar]
	var p: AudioStreamPlayer = _music_players[_next_music]
	_next_music = (_next_music + 1) % _music_players.size()
	p.stream = _streams["bass"] as AudioStreamWAV
	p.pitch_scale = pow(2.0, (root + PATTERN[_step]) / 12.0)
	p.volume_db = MUSIC_DB + (1.5 if _step % 2 == 0 else -1.5)
	p.play()
	if _step % 2 == 1:
		play("hat", 1.0, 0.08, MUSIC_DB - VOLUME_DB - 9.0)

# --- instruments and effects -------------------------------------------------------

func _build_instruments() -> void:
	_add("piano", _string_note(261.63, 1.4, [1.0, 0.45, 0.22, 0.09], 3.2), 0.0)
	_add("bass", _string_note(65.41, 0.9, [1.0, 0.6, 0.25, 0.1], 4.5), 0.0)

## A struck string: harmonics of f0, each decaying faster than the one below.
func _string_note(f0: float, duration: float, harmonics: Array, decay: float) -> PackedFloat32Array:
	var b: PackedFloat32Array = _buffer(duration)
	var n: int = b.size()
	for i in n:
		var t: float = float(i) / MIX_RATE
		var attack: float = minf(t / 0.003, 1.0)
		var v: float = 0.0
		for k in harmonics.size():
			v += sin(TAU * f0 * (k + 1) * t) * float(harmonics[k]) * exp(-t * decay * (1.0 + k * 0.6))
		b[i] = v * attack * 0.32
	_noise(b, 0.0, 0.012, 0.18, 0.6)
	return b

func _build_effects() -> void:
	var b: PackedFloat32Array = _buffer(0.03)          # Move: wooden tick
	_tone(b, 0.0, 0.025, 1500.0, 1100.0, Wave.TRIANGLE, 0.14)
	_add("move", b, 0.02)
	b = _buffer(0.06)                                  # Rotate: higher double tick
	_tone(b, 0.0, 0.025, 1900.0, 1700.0, Wave.TRIANGLE, 0.12)
	_tone(b, 0.025, 0.03, 2400.0, 2200.0, Wave.SINE, 0.1)
	_add("rotate", b, 0.03)
	b = _buffer(0.12)                                  # Lock: soft wooden thock
	_noise(b, 0.0, 0.06, 0.3, 0.25)
	_tone(b, 0.0, 0.1, 240.0, 150.0, Wave.SINE, 0.3)
	_add("lock", b, 0.05)
	b = _buffer(0.22)                                  # Hard drop: thump with a whoosh
	_noise(b, 0.0, 0.18, 0.35, 0.35)
	_tone(b, 0.0, 0.2, 160.0, 60.0, Wave.SINE, 0.42)
	_add("drop", b, 0.05)
	b = _buffer(0.2)                                   # Hold: paper swish
	_noise(b, 0.0, 0.18, 0.22, 0.55)
	_tone(b, 0.0, 0.16, 500.0, 900.0, Wave.SINE, 0.06)
	_add("hold", b, 0.1)
	b = _buffer(0.05)                                  # Hi-hat
	_noise(b, 0.0, 0.04, 0.35, 0.95)
	_add("hat", b, 0.0)
	b = _buffer(0.35)                                  # Line wipe: rising brush
	_noise(b, 0.0, 0.32, 0.25, 0.5)
	_tone(b, 0.0, 0.3, 400.0, 1200.0, Wave.SINE, 0.06)
	_add("wipe", b, 0.05)
	b = _buffer(0.45)                                  # Grey line rising: low grind
	_noise(b, 0.0, 0.4, 0.3, 0.12)
	_tone(b, 0.0, 0.4, 70.0, 110.0, Wave.SAW, 0.12)
	_tone(b, 0.0, 0.3, 140.0, 90.0, Wave.SINE, 0.25)
	_add("rise", b, 0.2)
	b = _buffer(0.6)                                   # Game over: falling slide
	_tone(b, 0.0, 0.55, 520.0, 130.0, Wave.TRIANGLE, 0.18)
	_noise(b, 0.0, 0.2, 0.15, 0.3)
	_add("over", b, 0.3)
	b = _buffer(0.05)                                  # UI button
	_tone(b, 0.0, 0.04, 1200.0, 900.0, Wave.SINE, 0.16)
	_add("ui", b, 0.03)
	b = _buffer(0.04)                                  # UI focus
	_tone(b, 0.0, 0.03, 800.0, 800.0, Wave.SINE, 0.07)
	_add("ui_move", b, 0.02)

func _buffer(duration: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(duration * MIX_RATE))
	return b

func _tone(b: PackedFloat32Array, start: float, duration: float, f0: float, f1: float, wave: Wave, volume: float) -> void:
	var first: int = int(start * MIX_RATE)
	var count: int = mini(int(duration * MIX_RATE), b.size() - first)
	var phase: float = 0.0
	var attack: float = 0.003 * MIX_RATE
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
