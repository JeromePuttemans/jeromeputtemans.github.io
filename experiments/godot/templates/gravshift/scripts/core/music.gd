extends Node

# Music: a procedural two-layer loop, generated at startup (no audio file).
#
# SONG: 8 bars at 126 BPM in A minor, chords Am F C G played twice
#   (15.2 s). Two layers of the same length loop side by side:
#   CALM   a pad of detuned saws through a soft low-pass, a triangle bass on
#          beats 1 and 3, faint off-beat hats. Always on.
#   DRIVE  kick on every beat, clap on 2 and 4, eighth-note hats, a plucked
#          saw bass pumping root and octave, and (bars 5 to 8) a square
#          arpeggio. Its volume follows `intensity` (0..1): silent on the
#          title, louder as bullets and enemies fill the arena, full on a
#          boss.
# GENERATION: every distinct bar is synthesised once into a float buffer,
#   a few thousand samples per frame (the title screen keeps running), then
#   converted to 16-bit PCM; the loops are the bars concatenated natively.
# MUFFLE: while the game is paused or between sectors the music is muffled.
#   On desktop the layers play on a "Music" bus whose low-pass filter is
#   switched on. The web build plays sounds as Web Audio samples, where a
#   bus added at runtime silences every sound and bus effects do not run:
#   there the layers stay on Master and muffling lowers their volume.

const RATE: int = 22050
const BPM: float = 126.0
const BARS: int = 8
const CHUNK: int = 6000
const CHORDS: Array = [[57, 60, 64], [53, 57, 60], [55, 60, 64], [55, 59, 62]]
const ROOTS: Array[int] = [45, 41, 48, 43]
const PROGRESSION: Array[int] = [0, 1, 2, 3, 0, 1, 2, 3]
const MUFFLE_DB: float = -9.0

var muted: bool = false
var ready_to_play: bool = false
var intensity: float = 0.0
var volume_db: float = -15.0

var _calm: AudioStreamPlayer = null
var _drive: AudioStreamPlayer = null
var _level: float = 0.0
var _bus: int = -1
var _muffled: bool = false
var _use_bus: bool = true
var _bar_len: int = 0
var _beat: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_beat = 60.0 / BPM
	_bar_len = int(RATE * _beat * 4.0)
	_use_bus = not OS.has_feature("web")
	if _use_bus:
		_setup_bus()
	_calm = _player()
	_drive = _player()
	_generate()

func _player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music" if _use_bus else "Master"
	add_child(p)
	return p

func _setup_bus() -> void:
	_bus = AudioServer.get_bus_index("Music")
	if _bus < 0:
		_bus = AudioServer.bus_count
		AudioServer.add_bus(_bus)
		AudioServer.set_bus_name(_bus, "Music")
		AudioServer.set_bus_send(_bus, "Master")
		var filter := AudioEffectLowPassFilter.new()
		filter.cutoff_hz = 700.0
		AudioServer.add_bus_effect(_bus, filter)
	AudioServer.set_bus_effect_enabled(_bus, 0, false)

func set_muffled(on: bool) -> void:
	if on == _muffled:
		return
	_muffled = on
	if _use_bus and _bus >= 0:
		AudioServer.set_bus_effect_enabled(_bus, 0, on)

func _process(delta: float) -> void:
	if not ready_to_play:
		return
	_level = move_toward(_level, clampf(intensity, 0.0, 1.0), delta * 0.6)
	var base: float = -80.0 if muted else volume_db + (MUFFLE_DB if _muffled and not _use_bus else 0.0)
	_calm.volume_db = base
	_drive.volume_db = base + linear_to_db(maxf(_level, 0.0005))

# =============================================================================
# GENERATION
# =============================================================================

func _generate() -> void:
	var calm_bars: Array[PackedByteArray] = []
	for c in CHORDS.size():
		var buf: PackedFloat32Array = _empty_bar()
		await _pad(buf, CHORDS[c] as Array)
		_bass_notes(buf, ROOTS[c])
		_soft_hats(buf)
		calm_bars.append(await _bytes(buf))
	var drive_bars: Array[PackedByteArray] = []
	for variation in 2:
		for c in CHORDS.size():
			var buf2: PackedFloat32Array = _empty_bar()
			_drums(buf2)
			await get_tree().process_frame
			await _bassline(buf2, ROOTS[c])
			if variation == 1:
				await _arp(buf2, CHORDS[c] as Array)
			drive_bars.append(await _bytes(buf2))
	var calm_data := PackedByteArray()
	var drive_data := PackedByteArray()
	for b in BARS:
		var c2: int = PROGRESSION[b]
		calm_data.append_array(calm_bars[c2])
		drive_data.append_array(drive_bars[c2 + (4 if b >= 4 else 0)])
	_calm.stream = _wav(calm_data)
	_drive.stream = _wav(drive_data)
	_calm.volume_db = -80.0
	_drive.volume_db = -80.0
	_calm.play()
	_drive.play()
	ready_to_play = true

func _empty_bar() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(_bar_len)
	return b

func _freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)

## Pad: two detuned saws per chord note, one-pole low-pass, soft swell.
func _pad(buf: PackedFloat32Array, chord: Array) -> void:
	var steps := PackedFloat32Array()
	var phases := PackedFloat32Array()
	for m in chord:
		var f: float = _freq(int(m))
		steps.append(f * 0.996 / RATE)
		steps.append(f * 1.004 / RATE)
		phases.append(randf())
		phases.append(randf())
	var voices: int = steps.size()
	var a: float = 1.0 - exp(-TAU * 1000.0 / RATE)
	var attack: float = 0.15 * RATE
	var release: float = 0.35 * RATE
	var n: int = buf.size()
	var lp: float = 0.0
	var i: int = 0
	while i < n:
		var end: int = mini(i + CHUNK, n)
		for s in range(i, end):
			var sum: float = 0.0
			for k in voices:
				var ph: float = phases[k] + steps[k]
				if ph >= 1.0:
					ph -= 1.0
				phases[k] = ph
				sum += ph
			var saw: float = 2.0 * sum / voices - 1.0
			lp += a * (saw - lp)
			var env: float = minf(s / attack, 1.0) * minf((n - s) / release, 1.0)
			buf[s] += lp * env * 0.5
		i = end
		await get_tree().process_frame

## Calm bass: triangle notes on beats 1 and 3.
func _bass_notes(buf: PackedFloat32Array, root: int) -> void:
	var f: float = _freq(root)
	for beat in [0, 2]:
		var start: int = int(beat * _beat * RATE)
		var count: int = int(_beat * 1.9 * RATE)
		var ph: float = 0.0
		for s in count:
			if start + s >= buf.size():
				break
			ph = fmod(ph + f / RATE, 1.0)
			var tri: float = 4.0 * absf(ph - 0.5) - 1.0
			var t: float = float(s) / count
			buf[start + s] += tri * minf(s / 200.0, 1.0) * (1.0 - t) * 0.22

func _soft_hats(buf: PackedFloat32Array) -> void:
	for k in 4:
		_hat(buf, int((k + 0.5) * _beat * RATE), 0.03, 0.035)

func _drums(buf: PackedFloat32Array) -> void:
	for k in 4:
		_kick(buf, int(k * _beat * RATE))
	for k in [1, 3]:
		_clap(buf, int(k * _beat * RATE))
	for k in 8:
		_hat(buf, int(k * _beat * 0.5 * RATE), 0.035, 0.09 if k % 2 == 1 else 0.05)

func _kick(buf: PackedFloat32Array, start: int) -> void:
	var count: int = int(0.28 * RATE)
	var ph: float = 0.0
	for s in count:
		if start + s >= buf.size():
			break
		var t: float = float(s) / RATE
		var f: float = 45.0 + 110.0 * exp(-t * 32.0)
		ph += f / RATE
		buf[start + s] += sin(ph * TAU) * exp(-t * 11.0) * 0.6

func _clap(buf: PackedFloat32Array, start: int) -> void:
	var count: int = int(0.16 * RATE)
	var lp: float = 0.0
	for s in count:
		if start + s >= buf.size():
			break
		var t: float = float(s) / RATE
		var noise: float = randf_range(-1.0, 1.0)
		lp += 0.35 * (noise - lp)
		var burst: float = 1.0 if t > 0.02 else (0.6 + 0.4 * absf(sin(t * 470.0)))
		buf[start + s] += (noise - lp) * exp(-t * 26.0) * burst * 0.3

func _hat(buf: PackedFloat32Array, start: int, length: float, volume: float) -> void:
	var count: int = int(length * RATE)
	var lp: float = 0.0
	for s in count:
		if start + s >= buf.size():
			break
		var noise: float = randf_range(-1.0, 1.0)
		lp += 0.5 * (noise - lp)
		var x: float = float(s) / count
		buf[start + s] += (noise - lp) * (1.0 - x) * (1.0 - x) * volume

## Drive bass: eighth notes, root and octave in turn, plucked low-pass.
func _bassline(buf: PackedFloat32Array, root: int) -> void:
	var eighth: int = int(_beat * 0.5 * RATE)
	for k in 8:
		var f: float = _freq(root + (12 if k % 2 == 1 else 0))
		var start: int = k * eighth
		var count: int = int(eighth * 0.92)
		var ph: float = 0.0
		var lp: float = 0.0
		for s in count:
			var t: float = float(s) / RATE
			ph += f / RATE
			if ph >= 1.0:
				ph -= 1.0
			var cutoff: float = 260.0 + 1700.0 * exp(-t * 22.0)
			lp += (1.0 - exp(-TAU * cutoff / RATE)) * ((2.0 * ph - 1.0) - lp)
			var x: float = float(s) / count
			buf[start + s] += lp * minf(s / 60.0, 1.0) * (1.0 - x * x) * 0.32
		if k % 4 == 3:
			await get_tree().process_frame

## Arpeggio: sixteenth notes over the chord, an octave up, short square blips.
func _arp(buf: PackedFloat32Array, chord: Array) -> void:
	var sixteenth: int = int(_beat * 0.25 * RATE)
	var order: Array[int] = [0, 1, 2, 1]
	for k in 16:
		var f: float = _freq(int(chord[order[k % 4]]) + 12)
		var start: int = k * sixteenth
		var count: int = int(sixteenth * 0.9)
		var ph: float = 0.0
		var lp: float = 0.0
		for s in count:
			ph += f / RATE
			if ph >= 1.0:
				ph -= 1.0
			lp += 0.25 * ((1.0 if ph < 0.5 else -1.0) - lp)
			var t: float = float(s) / RATE
			buf[start + s] += lp * exp(-t * 28.0) * 0.07
		if k % 8 == 7:
			await get_tree().process_frame

func _bytes(buf: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(buf.size() * 2)
	var i: int = 0
	while i < buf.size():
		var end: int = mini(i + CHUNK * 2, buf.size())
		for s in range(i, end):
			out.encode_s16(s * 2, int(clampf(buf[s], -1.0, 1.0) * 32767.0))
		i = end
		await get_tree().process_frame
	return out

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = data.size() / 2
	return wav
