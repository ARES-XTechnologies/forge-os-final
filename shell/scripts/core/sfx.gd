extends Node
## Procedural UI sound design with switchable sound themes. Every sound is synthesised
## at startup: no audio files, no licensing, tiny footprint. Also drives controller haptics.
##
## Themes: crystal (default), soft, glass, retro, minimal

const RATE := 44100
const THEMES := [["crystal", "Crystal"], ["soft", "Soft"], ["glass", "Glass"], ["retro", "Retro"], ["minimal", "Minimal"]]

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last_tick_ms := 0
var _theme := ""
# theme parameters
var _fm := 1.0          # frequency multiplier
var _dm := 1.0          # decay multiplier (bigger = shorter)
var _gain := 1.0
var _wave := "sine"     # sine | square | bell

func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_build_theme()
	Config.changed.connect(func(k): if k == "feedback.sound_theme": _build_theme())
	# The long intro sounds are heavy to synthesise: do it off the main thread.
	_task = WorkerThreadPool.add_task(func():
		var s := {"intro_swell": _make_intro_swell(), "intro_chime": _make_chime(), "intro_boom": _make_boom()}
		_store.call_deferred(s))

var _task := -1

## Quitting while the intro sounds were still being made crashed the engine on exit.
func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

func _store(s: Dictionary) -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)     # collect the finished task
		_task = -1
	for k in s:
		_streams[k] = s[k]

func _build_theme() -> void:
	var t := Config.get_s("feedback.sound_theme")
	if t == _theme:
		return
	_theme = t
	match t:
		"soft": _fm = 0.6; _dm = 0.7; _gain = 0.9; _wave = "sine"
		"glass": _fm = 1.5; _dm = 0.8; _gain = 0.8; _wave = "bell"
		"retro": _fm = 0.8; _dm = 1.2; _gain = 0.45; _wave = "square"
		"minimal": _fm = 1.2; _dm = 2.0; _gain = 0.45; _wave = "sine"
		_: _fm = 1.0; _dm = 1.0; _gain = 1.0; _wave = "sine"
	_streams["tick"] = _make_tick()
	_streams["select"] = _make_pop(520.0, 980.0, 0.11)
	_streams["back"] = _make_pop(760.0, 420.0, 0.10)
	_streams["toggle_on"] = _make_pop(700.0, 1250.0, 0.07)
	_streams["toggle_off"] = _make_pop(900.0, 520.0, 0.07)
	_streams["open"] = _make_whoosh(0.26, true)
	_streams["close"] = _make_whoosh(0.20, false)
	_streams["tab"] = _make_tab()
	_streams["launch"] = _make_launch()
	_streams["error"] = _make_error()
	_streams["edge"] = _make_edge()
	_streams["key"] = _make_key()
	_streams["shutter"] = _make_shutter()
	_streams["notify"] = _make_notify()
	_streams["achievement"] = _make_achievement()
	_streams["wake"] = _make_launch(true)

## Play a named sound. `pitch` lets callers vary ticks so long scrolls feel musical.
func play(name: String, pitch := 1.0, gain_db := 0.0) -> void:
	if not Config.get_b("feedback.sounds") or not _streams.has(name):
		return
	if name == "tick":
		var now := Time.get_ticks_msec()
		if now - _last_tick_ms < 28:
			return
		_last_tick_ms = now
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(maxf(Config.get_f("feedback.volume"), 0.001)) + gain_db
	p.play()

## Short haptic pulse on every connected controller.
func haptic(weak: float, strong: float, ms: int) -> void:
	if not Config.get_b("feedback.haptics"):
		return
	var k := Config.get_f("feedback.haptic_strength")
	for id in Input.get_connected_joypads():
		Input.start_joy_vibration(id, clampf(weak * k, 0, 1), clampf(strong * k, 0, 1), ms / 1000.0)

func focus_tick(index := 0) -> void:
	# A gentle pentatonic walk so scrolling through a row "plays" a little melody.
	var scale := [1.0, 1.122, 1.26, 1.498, 1.682]
	play("tick", scale[posmod(index, scale.size())] * 0.92)
	haptic(0.22, 0.0, 22)

func confirm() -> void:
	play("select")
	haptic(0.35, 0.25, 45)

func back() -> void:
	play("back")
	haptic(0.2, 0.0, 30)

# ------------------------------------------------------------------ synthesis
func _osc(ph: float) -> float:
	match _wave:
		"square":
			return 0.6 if sin(ph) >= 0.0 else -0.6
		"bell":
			return sin(ph) * 0.6 + sin(ph * 2.76) * 0.25 + sin(ph * 5.4) * 0.1
	return sin(ph)

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * _gain, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w

func _buf(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(seconds * RATE))
	return a

func _make_tick() -> AudioStreamWAV:
	var s := _buf(0.05)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var env := exp(-t * 120.0 * _dm) * minf(1.0, t * 3000.0)
		ph += TAU * 2100.0 * _fm / RATE
		s[i] = (_osc(ph) * 0.55 + sin(ph * 2.01) * 0.12) * env * 0.5
	return _wav(s)

func _make_pop(f0: float, f1: float, dur: float) -> AudioStreamWAV:
	var s := _buf(dur + 0.06)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var k := clampf(t / dur, 0.0, 1.0)
		var f := lerpf(f0, f1, 1.0 - pow(1.0 - k, 3.0)) * _fm
		ph += TAU * f / RATE
		var env := exp(-t * 34.0 * _dm) * minf(1.0, t * 900.0)
		s[i] = (_osc(ph) * 0.7 + sin(ph * 2.0) * 0.18 + sin(ph * 3.0) * 0.05) * env * 0.55
	return _wav(s)

func _make_whoosh(dur: float, rising: bool) -> AudioStreamWAV:
	var s := _buf(dur)
	var lp := 0.0
	var lp2 := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in s.size():
		var t := float(i) / dur / RATE
		var cutoff := (lerpf(0.02, 0.22, t) if rising else lerpf(0.22, 0.02, t)) * clampf(_fm, 0.5, 1.4)
		var n := rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * cutoff
		lp2 += (lp - lp2) * cutoff
		var env := sin(PI * t) * sin(PI * t)
		s[i] = lp2 * env * (0.6 if _theme == "minimal" else 1.4)
	return _wav(s)

func _make_tab() -> AudioStreamWAV:
	var s := _buf(0.12)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		ph += TAU * (1320.0 + 300.0 * exp(-t * 40.0)) * _fm / RATE
		var env := exp(-t * 45.0 * _dm) * minf(1.0, t * 1500.0)
		s[i] = (_osc(ph) * 0.5 + sin(ph * 1.5) * 0.2) * env * 0.4
	return _wav(s)

func _make_launch(soft := false) -> AudioStreamWAV:
	var s := _buf(1.1)
	var notes := [523.25, 659.25, 783.99, 1046.5] if not soft else [392.0, 523.25, 659.25, 783.99]
	for n in notes.size():
		var start := int(n * (0.07 if not soft else 0.11) * RATE)
		var ph := 0.0
		for i in range(start, s.size()):
			var t := float(i - start) / RATE
			ph += TAU * notes[n] * _fm / RATE
			var env := exp(-t * 4.5 * _dm) * minf(1.0, t * 400.0)
			s[i] += (_osc(ph) * 0.6 + sin(ph * 2.0) * 0.15 + sin(ph * 3.01) * 0.06) * env * 0.18
	return _wav(s)

func _make_error() -> AudioStreamWAV:
	var s := _buf(0.3)
	for b in 2:
		var start := int(b * 0.12 * RATE)
		var ph := 0.0
		for i in range(start, mini(s.size(), start + int(0.1 * RATE))):
			var t := float(i - start) / RATE
			ph += TAU * 220.0 * _fm / RATE
			s[i] += (_osc(ph) + 0.3 * sin(ph * 3.0)) * exp(-t * 30.0) * 0.35
	return _wav(s)

func _make_edge() -> AudioStreamWAV:
	# Soft "thud" when hitting the end of a row: tells you there's nothing further.
	var s := _buf(0.09)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		ph += TAU * (180.0 + 120.0 * exp(-t * 60.0)) / RATE
		s[i] = sin(ph) * exp(-t * 45.0) * minf(1.0, t * 2000.0) * 0.5
	return _wav(s)

func _make_key() -> AudioStreamWAV:
	var s := _buf(0.035)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		ph += TAU * 3200.0 * _fm / RATE
		s[i] = (_osc(ph) * 0.3 + rng.randf_range(-0.2, 0.2)) * exp(-t * 160.0) * 0.5
	return _wav(s)

func _make_shutter() -> AudioStreamWAV:
	# Two quick clicks with a breath of noise: a camera shutter.
	var s := _buf(0.16)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for b in 2:
		var start := int(b * 0.07 * RATE)
		for i in range(start, mini(s.size(), start + int(0.06 * RATE))):
			var t := float(i - start) / RATE
			s[i] += (rng.randf_range(-1.0, 1.0) * 0.5 + sin(TAU * 1800.0 * _fm * t) * 0.3) * exp(-t * 90.0) * 0.5
	return _wav(s)

func _make_notify() -> AudioStreamWAV:
	var s := _buf(0.5)
	var notes := [880.0, 1318.5]
	for n in 2:
		var start := int(n * 0.09 * RATE)
		var ph := 0.0
		for i in range(start, s.size()):
			var t := float(i - start) / RATE
			ph += TAU * notes[n] * _fm / RATE
			s[i] += (_osc(ph) * 0.6 + sin(ph * 2.0) * 0.12) * exp(-t * 9.0 * _dm) * minf(1.0, t * 600.0) * 0.22
	return _wav(s)

func _make_achievement() -> AudioStreamWAV:
	# Rising sparkle arpeggio ending on a bright chord.
	var s := _buf(1.4)
	var notes := [659.25, 783.99, 987.77, 1318.5, 1567.98]
	for n in notes.size():
		var start := int(n * 0.055 * RATE)
		var ph := 0.0
		for i in range(start, s.size()):
			var t := float(i - start) / RATE
			ph += TAU * notes[n] * _fm / RATE
			s[i] += (_osc(ph) * 0.55 + sin(ph * 2.0) * 0.12 + sin(ph * 4.01) * 0.04) * exp(-t * 3.2 * _dm) * minf(1.0, t * 500.0) * 0.14
	return _wav(s)

func _make_intro_swell() -> AudioStreamWAV:
	# Warm pad: stacked detuned sines with a slow bloom, the bed under the particle intro.
	var dur := 5.2
	var s := _buf(dur)
	var chord := [110.0, 164.81, 220.0, 277.18, 329.63, 440.0]
	var phases := []
	for c in chord:
		phases.append([0.0, 0.0])
	for i in s.size():
		var t := float(i) / RATE
		var env := smoothstep(0.0, 2.4, t) * (1.0 - smoothstep(3.8, dur, t))
		var v := 0.0
		for c in chord.size():
			var f: float = chord[c]
			phases[c][0] += TAU * f / RATE
			phases[c][1] += TAU * f * 1.004 / RATE
			var w := 1.0 / (1.0 + c * 0.6)
			v += (sin(phases[c][0]) + sin(phases[c][1])) * w
		var shimmer := sin(TAU * 1760.0 * t) * sin(TAU * 0.7 * t) * 0.04 * smoothstep(1.5, 3.0, t)
		s[i] = (v * 0.07 + shimmer) * env
	return _wav_raw(s)

func _make_chime() -> AudioStreamWAV:
	# Bell with inharmonic partials: the moment the particles lock into the logo.
	var s := _buf(3.0)
	var partials := [[880.0, 1.0, 2.2], [1760.0 * 1.003, 0.45, 3.0], [2640.0 * 0.997, 0.25, 4.0], [3960.0, 0.12, 6.0], [440.0, 0.35, 1.5]]
	for p in partials:
		var ph := 0.0
		for i in s.size():
			var t := float(i) / RATE
			ph += TAU * p[0] / RATE
			s[i] += sin(ph) * p[1] * exp(-t * p[2]) * minf(1.0, t * 800.0) * 0.16
	return _wav_raw(s)

func _make_boom() -> AudioStreamWAV:
	var s := _buf(1.6)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		ph += TAU * (42.0 + 40.0 * exp(-t * 8.0)) / RATE
		s[i] = sin(ph) * exp(-t * 2.8) * minf(1.0, t * 300.0) * 0.6
	return _wav_raw(s)

## Intro sounds ignore the theme gain (they're built on a worker thread).
func _wav_raw(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
