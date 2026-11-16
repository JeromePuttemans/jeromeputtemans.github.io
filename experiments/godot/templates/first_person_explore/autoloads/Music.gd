# =============================================================================
# Music.gd: Autoload (Singleton) playing a sparse generative piano over a soft pad
# =============================================================================
# No audio file: one piano-like note (a sine with two harmonics, a quick
# attack and a long decay) is synthesized at startup and pitched to every
# degree of a C major pentatonic over two octaves; a pad of two slow sine
# chords (C and A minor, eight bars each) loops underneath.
# SEQUENCER: eighth notes at 84 beats per minute. On each step a note may
# sound, with a probability that grows with `intensity` (0 to 1, set by
# Main from the speed of the body, dashes, jumps and the hour moving): a
# still player hears a note now and then, a player in full flight hears a
# melody. Notes move by small steps along the scale, accents fall on the
# beat, and a rest follows every phrase of four notes.
# Muted with the sound effects (Sfx.muted). The players stay on the Master
# bus: in the browser, a separate bus was found to cut the sound.
# =============================================================================

extends Node

const MIX_RATE: int = 22050
const BPM: float = 84.0
const BASE_FREQUENCY: float = 261.63
const SCALE: Array[float] = [1.0, 1.1225, 1.2599, 1.4983, 1.6818, 2.0, 2.2449, 2.5198, 2.9966, 3.3636]
const PAD_DB: float = -24.0
const NOTE_DB: float = -15.0
const VOICES: int = 6

var playing: bool = false
var intensity: float = 0.0

var _note: AudioStreamWAV = null
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _pads: Array[AudioStreamPlayer] = []
var _step_time: float = 0.0
var _step: int = 0
var _degree: int = 4
var _phrase: int = 0
var _smoothed: float = 0.0
var _pad_level: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_note = _build_note()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.stream = _note
		add_child(p)
		_voices.append(p)
	for chord in [[130.81, 196.0, 329.63], [110.0, 164.81, 261.63]]:
		var pad := AudioStreamPlayer.new()
		pad.stream = _build_pad(chord as Array)
		pad.volume_db = -80.0
		add_child(pad)
		pad.play()
		_pads.append(pad)

func _process(delta: float) -> void:
	var audible: bool = playing and not Sfx.muted
	_smoothed = lerpf(_smoothed, intensity, 1.0 - exp(-2.0 * delta))
	_pad_level = move_toward(_pad_level, 1.0 if audible else 0.0, delta * 0.5)
	var bar: int = floori(_step / 8.0)
	var chord: int = floori(bar / 8.0) % 2
	for i in _pads.size():
		var target: float = _pad_level * (1.0 if i == chord else 0.0)
		var current: float = db_to_linear(_pads[i].volume_db) / db_to_linear(PAD_DB)
		current = move_toward(current, target, delta * 0.3)
		_pads[i].volume_db = linear_to_db(maxf(current, 0.0001)) + PAD_DB
	if not audible:
		return
	_step_time -= delta
	if _step_time > 0.0:
		return
	_step_time += 60.0 / BPM * 0.5
	_step += 1
	var on_beat: bool = _step % 2 == 0
	var chance: float = lerpf(0.07, 0.62, _smoothed) * (1.25 if on_beat else 0.7)
	if _phrase >= 4:
		_phrase = 0
		return
	if randf() < chance:
		var move: int = [-2, -1, -1, 1, 1, 2][randi() % 6]
		if chord == 1 and randf() < 0.3:
			move = -1
		_degree = clampi(_degree + move, 0, SCALE.size() - 1)
		_play_note(SCALE[_degree], (0.0 if on_beat else -4.0) + _smoothed * 2.0)
		_phrase += 1

func _play_note(ratio: float, gain_db: float) -> void:
	var p: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.pitch_scale = ratio
	p.volume_db = NOTE_DB + gain_db
	p.play()

## Piano-like note at BASE_FREQUENCY: fundamental, octave and twelfth,
## each fading at its own rate.
func _build_note() -> AudioStreamWAV:
	var duration: float = 2.6
	var count: int = int(duration * MIX_RATE)
	var b := PackedFloat32Array()
	b.resize(count)
	for i in count:
		var t: float = float(i) / MIX_RATE
		var attack: float = minf(t / 0.006, 1.0)
		var v: float = sin(TAU * BASE_FREQUENCY * t) * exp(-t * 1.6)
		v += 0.35 * sin(TAU * BASE_FREQUENCY * 2.0 * t) * exp(-t * 3.2)
		v += 0.12 * sin(TAU * BASE_FREQUENCY * 3.0 * t) * exp(-t * 5.0)
		b[i] = v * attack * 0.5 * (1.0 - smoothstep(duration - 0.3, duration, t))
	return _to_wav(b, false)

## Four seconds of a slow chord, each tone swelling at its own rate,
## seamless (whole numbers of periods for the swells).
func _build_pad(chord: Array) -> AudioStreamWAV:
	var duration: float = 4.0
	var count: int = int(duration * MIX_RATE)
	var b := PackedFloat32Array()
	b.resize(count)
	for i in count:
		var t: float = float(i) / MIX_RATE
		var v: float = 0.0
		for k in chord.size():
			var f: float = round(float(chord[k]) * duration) / duration
			var swell: float = 0.65 + 0.35 * sin(TAU * t * float(k + 1) / duration + k)
			v += sin(TAU * f * t) * swell
		b[i] = v * 0.18
	return _to_wav(b, true)

func _to_wav(b: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = b.size()
	return wav
