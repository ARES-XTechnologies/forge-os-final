class_name Intro
extends Control
## The boot intro. Golden embers rise in a dark forge, swirl into a vortex, then snap
## into the FORGE emblem with a flash and a chime. The wordmark rises letter by letter,
## a light sweep crosses it, and everything bursts outward to reveal the console.
## Press A / Start / B to skip.

signal finished()       # the shell should start revealing now
signal done()           # intro fully gone

const N := 1500
const BG_SHADER := preload("res://shaders/intro_bg.gdshader")
const GOLD_SHADER := preload("res://shaders/gold_text.gdshader")

# timeline (seconds)
const T_SWIRL := 0.9
const T_CONVERGE := 2.35
const T_FLASH := 2.95
const T_WORD := 3.2
const T_OUT := 4.55
const T_END := 5.4

var _t := 0.0
var _bg: ColorRect
var _bg_mat: ShaderMaterial
var _mm: MultiMesh
var _mmi: MultiMeshInstance2D
var _buf := PackedFloat32Array()
var px := PackedFloat32Array(); var py := PackedFloat32Array()
var vx := PackedFloat32Array(); var vy := PackedFloat32Array()
var tx := PackedFloat32Array(); var ty := PackedFloat32Array()
var psize := PackedFloat32Array(); var phase := PackedFloat32Array()
var delay := PackedFloat32Array(); var heat := PackedFloat32Array()
var _center := Vector2.ZERO
var _flashed := false
var _burst := false
var _finished_sent := false
var _skipping := false
var _letters: Array[Label] = []
var _letter_springs: Array[Spring] = []
var _word: Control
var _tag: Label
var _sweep := -400.0
var _emblem_scale: Spring
var _fade: Spring
var _glow: Spring
var _flash: Spring
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 2026
	_emblem_scale = Spring.make(1.0, 140.0, 18.0)
	_fade = Spring.make(1.0, 60.0, 15.5)
	_glow = Spring.make(0.0, 30.0, 11.0)
	_flash = Spring.make(0.0, 90.0, 12.0)

	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = BG_SHADER
	_bg.material = _bg_mat
	add_child(_bg)

	# Particles: one draw call, additive soft dots.
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	_mm.mesh = quad
	_mm.instance_count = N
	_mmi = MultiMeshInstance2D.new()
	_mmi.multimesh = _mm
	_mmi.texture = _dot_texture()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_mmi.material = add
	add_child(_mmi)

	_build_word()
	Nav.push(self)
	Metrics.want(false)
	await get_tree().process_frame
	_center = size * Vector2(0.5, 0.44)
	_init_particles()
	# Hidden (but still drawn, so the GPU prepares its shaders) until the screen is ready.
	_mmi.modulate.a = 0.01

func _dot_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.18, Color(1, 1, 1, 0.85))
	g.add_point(0.45, Color(1, 1, 1, 0.22))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

# ------------------------------------------------------------------ emblem geometry
## The FORGE mark: a ring (the hearth), a rising triangle (the anvil spark)
## and a small diamond at the apex (the ember).
func _emblem_point(i: int) -> Vector2:
	var u := float(i) / N
	var R := 118.0
	if u < 0.46:
		var a := u / 0.46 * TAU + _rng.randf_range(-0.004, 0.004)
		var rr := R + _rng.randf_range(-2.5, 2.5)
		return Vector2(cos(a), sin(a)) * rr
	elif u < 0.86:
		var k := (u - 0.46) / 0.40
		var tri := [Vector2(0, -78), Vector2(68, 44), Vector2(-68, 44)]
		var e := int(k * 3.0) % 3
		var f := fmod(k * 3.0, 1.0)
		var p: Vector2 = (tri[e] as Vector2).lerp(tri[(e + 1) % 3], f)
		return p + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2))
	else:
		var k2 := (u - 0.86) / 0.14
		var dia := [Vector2(0, -26), Vector2(14, -4), Vector2(0, 18), Vector2(-14, -4)]
		var e2 := int(k2 * 4.0) % 4
		var f2 := fmod(k2 * 4.0, 1.0)
		return (dia[e2] as Vector2).lerp(dia[(e2 + 1) % 4], f2) + Vector2(0, -6)

func _init_particles() -> void:
	for arr in [px, py, vx, vy, tx, ty, psize, phase, delay, heat]:
		arr.resize(N)
	_buf.resize(N * 12)
	for i in N:
		px[i] = _rng.randf_range(0, size.x)
		py[i] = size.y + _rng.randf_range(0, size.y * 0.9)
		vx[i] = _rng.randf_range(-20, 20)
		vy[i] = _rng.randf_range(-160, -50)
		var tp := _emblem_point(i)
		tx[i] = tp.x
		ty[i] = tp.y
		var big := _rng.randf() < 0.06
		psize[i] = _rng.randf_range(22, 46) if big else _rng.randf_range(5.0, 12.0)
		phase[i] = _rng.randf() * TAU
		delay[i] = _rng.randf_range(0.0, 0.45)
		heat[i] = _rng.randf()

func _build_word() -> void:
	_word = Control.new()
	_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_word)
	var font := Tokens.font(300)
	var fs := 64
	var text := Tokens.OS_NAME
	var tracking := 30.0
	var x := 0.0
	for ch in text:
		var l := Label.new()
		l.text = ch
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", fs)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = GOLD_SHADER
		m.set_shader_parameter("offset_x", x)
		m.set_shader_parameter("height", fs * 1.25)
		l.material = m
		l.modulate.a = 0.0
		_word.add_child(l)
		l.position = Vector2(x, 0)
		_letters.append(l)
		_letter_springs.append(Spring.make(1.0, 260.0, 14.0))
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + tracking
	_word.size = Vector2(x - tracking, fs * 1.3)
	_tag = Tokens.label("by " + Tokens.STUDIO.to_upper(), 15, 500, Color(1.0, 0.85, 0.6, 0.0))
	_tag.add_theme_constant_override("outline_size", 0)
	add_child(_tag)

# ------------------------------------------------------------------ input
func nav_action(a: StringName) -> bool:
	if a in [&"accept", &"start", &"back"] and not _skipping and _t < T_OUT:
		_skipping = true
		_t = maxf(_t, T_OUT - 0.05)
		if not _flashed:
			_snap_to_emblem()
	return true

func _snap_to_emblem() -> void:
	_flashed = true
	for i in N:
		px[i] = _center.x + tx[i]
		py[i] = _center.y + ty[i]
		vx[i] = 0.0
		vy[i] = 0.0

# ------------------------------------------------------------------ simulation
var _start_ms := -1
const STEP := 1.0 / 60.0

## The timeline follows the real clock, simulated in fixed 60 Hz steps, so the intro
## is identical on every machine and never drifts if a frame hitches.
## The intro waits on a black screen until the monitor has finished switching modes
## (most go dark for 2–4 s when the console starts) and frames are coming smoothly.
## Before, the timeline ran during that blackout and the intro was over before it showed.
const HOLD_MIN := 2.5
const HOLD_MAX := 7.0
var _hold := 0.0
var _smooth := 0
var _go := false

func _process(frame_dt: float) -> void:
	if _center == Vector2.ZERO:
		return
	if not _go:
		_hold += frame_dt
		_smooth = (_smooth + 1) if frame_dt < 0.034 else 0
		if (_hold >= HOLD_MIN and _smooth >= 20) or _hold >= HOLD_MAX or _skipping:
			_go = true
			_mmi.modulate.a = 1.0
			if not _skipping:
				Sfx.play("intro_swell", 1.0, -2.0)
		else:
			return
	if _start_ms < 0:
		_start_ms = Time.get_ticks_msec()
	var target := (Time.get_ticks_msec() - _start_ms) / 1000.0
	if _skipping and target < _t:
		target = _t + STEP
	var steps := 0
	while _t < target and steps < 6:
		_step(STEP)
		steps += 1
	if _t < target - 0.25:
		# Fell far behind (very slow frame): jump the clock rather than fast-forwarding.
		_start_ms += int((target - _t) * 1000.0)
	_render(minf(frame_dt, 0.05))

## Development helper: jump straight to a point in the timeline.
func fast_forward(to: float) -> void:
	if _center == Vector2.ZERO:
		_center = size * Vector2(0.5, 0.44)
		_init_particles()
	while _t < to:
		_step(STEP)
	_start_ms = Time.get_ticks_msec() - int(_t * 1000.0)
	_render(STEP)

func _step(dt: float) -> void:
	_t += dt
	var t := _t

	# Lighting cues
	_glow.target = 0.0 if t > T_OUT else (0.35 if t < T_CONVERGE else 1.0)
	if t >= T_FLASH and not _flashed:
		_flashed = true
		_flash.kick(9.0)
		Sfx.play("intro_boom", 1.0, -3.0)
		Sfx.play("intro_chime", 1.0, -4.0)
		Sfx.haptic(0.6, 0.8, 220)
		_emblem_scale.kick(1.4)
	if t >= T_OUT and not _burst:
		_burst = true
		_emblem_scale.target = 1.35
		_fade.target = 0.0
		for i in N:
			var d := Vector2(px[i], py[i]) - _center
			var n := d.normalized() if d.length() > 1.0 else Vector2.RIGHT.rotated(phase[i])
			var sp := _rng.randf_range(250.0, 1100.0)
			vx[i] += n.x * sp
			vy[i] += n.y * sp - 60.0
		Sfx.play("open", 0.7, -6.0)
	if t >= T_OUT + 0.15 and not _finished_sent:
		_finished_sent = true
		finished.emit()

	var es := _emblem_scale.step(dt)
	var fade := clampf(_fade.step(dt), 0.0, 1.0)
	_glow.step(dt)
	_flash.step(dt)

	var swirl_w := smoothstep(T_SWIRL - 0.3, T_SWIRL + 0.8, t) * (1.0 - smoothstep(T_CONVERGE, T_CONVERGE + 0.4, t))
	var conv := t >= T_CONVERGE and t < T_OUT
	var c := _center

	for i in N:
		var x := px[i]
		var y := py[i]
		var ax := 0.0
		var ay := 0.0
		if not conv:
			# Embers: buoyancy + curl-ish turbulence
			var n1 := sin(y * 0.011 + t * 1.3 + phase[i]) + sin(x * 0.007 - t * 0.9)
			var n2 := cos(x * 0.012 + t * 1.1 + phase[i] * 0.5) + cos(y * 0.006 + t * 0.7)
			ax += n1 * 55.0
			ay += n2 * 30.0 - 40.0
			if swirl_w > 0.0:
				var rx := x - c.x
				var ry := y - c.y
				var r := sqrt(rx * rx + ry * ry) + 1.0
				var tang := 900.0 * swirl_w * (0.5 + heat[i])
				ax += (-ry / r) * tang - rx / r * 380.0 * swirl_w * clampf(r / 260.0, 0.3, 2.5)
				ay += (rx / r) * tang - ry / r * 380.0 * swirl_w * clampf(r / 260.0, 0.3, 2.5)
			vx[i] = (vx[i] + ax * dt) * (1.0 - 1.6 * dt)
			vy[i] = (vy[i] + ay * dt) * (1.0 - 1.6 * dt)
		else:
			# Converge: each particle springs to its spot on the emblem, slightly staggered.
			var lt := t - T_CONVERGE - delay[i]
			var k := 0.0 if lt < 0.0 else minf(1.0, lt * 2.6)
			var gx := c.x + tx[i] * es
			var gy := c.y + ty[i] * es
			var stiff := 95.0 * k * k
			var damp := 7.0 + 9.0 * k
			ax = (gx - x) * stiff - vx[i] * damp
			ay = (gy - y) * stiff - vy[i] * damp
			if lt < 0.0:
				# keep swirling until it's this particle's turn
				var rx2 := x - c.x
				var ry2 := y - c.y
				var r2 := sqrt(rx2 * rx2 + ry2 * ry2) + 1.0
				ax += (-ry2 / r2) * 700.0 - rx2 / r2 * 200.0
				ay += (rx2 / r2) * 700.0 - ry2 / r2 * 200.0
				vx[i] *= (1.0 - 1.2 * dt)
				vy[i] *= (1.0 - 1.2 * dt)
			vx[i] += ax * dt
			vy[i] += ay * dt
			if _flashed and k >= 1.0:
				# shimmer in place
				vx[i] += sin(t * 9.0 + phase[i]) * 4.0
				vy[i] += cos(t * 7.0 + phase[i] * 1.3) * 4.0
		if _burst:
			vx[i] *= (1.0 - 1.1 * dt)
			vy[i] *= (1.0 - 1.1 * dt)
		px[i] = x + vx[i] * dt
		py[i] = y + vy[i] * dt

func _render(dt: float) -> void:
	var t := _t
	var fade := clampf(_fade.value, 0.0, 1.0)
	var alpha_all := clampf(t / 0.6, 0.0, 1.0) * fade
	var gold := Color(1.0, 0.78, 0.38)
	var ember := Color(1.0, 0.48, 0.16)
	var pale := Color(1.0, 0.93, 0.76)
	for i in N:
		# Appearance
		var tw := 0.65 + 0.35 * sin(t * (3.0 + heat[i] * 5.0) + phase[i])
		var s := psize[i]
		var a := alpha_all * tw
		if s > 12.0:
			a *= 0.16 * (1.0 - (0.7 if _flashed else 0.0))
		elif _flashed and not _burst:
			a *= 1.0 + clampf(_flash.value, 0.0, 1.0) * 1.5
			s *= 0.9
		var col := ember.lerp(gold, heat[i]).lerp(pale, clampf(_flash.value, 0.0, 1.0) * 0.8)
		var o := i * 12
		_buf[o + 0] = s; _buf[o + 1] = 0.0; _buf[o + 2] = 0.0; _buf[o + 3] = px[i]
		_buf[o + 4] = 0.0; _buf[o + 5] = s; _buf[o + 6] = 0.0; _buf[o + 7] = py[i]
		_buf[o + 8] = col.r; _buf[o + 9] = col.g; _buf[o + 10] = col.b; _buf[o + 11] = clampf(a, 0.0, 1.0)
	_mm.buffer = _buf
	_bg_mat.set_shader_parameter("t", t)
	_bg_mat.set_shader_parameter("glow", clampf(_glow.value, 0.0, 1.2))
	_bg_mat.set_shader_parameter("flash", clampf(_flash.value, 0.0, 1.0))
	_bg_mat.set_shader_parameter("fade", fade)
	_bg_mat.set_shader_parameter("res", size)
	_bg_mat.set_shader_parameter("center", _center / size)
	_update_word(dt, t, fade)
	if t >= T_END:
		Nav.pop(self)
		done.emit()
		queue_free()

func _update_word(dt: float, t: float, fade: float) -> void:
	_word.position = Vector2(_center.x - _word.size.x * 0.5, _center.y + 168.0)
	for i in _letters.size():
		var l := _letters[i]
		var sp := _letter_springs[i]
		var start := T_WORD + i * 0.075
		if t >= start and sp.target == 1.0 and l.modulate.a == 0.0:
			sp.snap(1.0)
			sp.target = 0.0
			sp.kick(-0.5)
		var v := sp.step(dt)
		var vis := 0.0 if t < start else clampf((t - start) / 0.25, 0.0, 1.0)
		l.modulate.a = maxf(vis * fade, 0.0001) if t >= start else 0.0
		l.position.y = v * 46.0
		l.scale = Vector2.ONE * (1.0 + v * 0.12)
		(l.material as ShaderMaterial).set_shader_parameter("sweep", _sweep)
		(l.material as ShaderMaterial).set_shader_parameter("glow", clampf(_flash.value, 0.0, 1.0))
	if t > T_WORD + 0.45:
		_sweep += dt * 900.0
	_tag.position = Vector2(_center.x - _tag.size.x * 0.5, _center.y + 262.0)
	var ta := clampf((t - (T_WORD + 0.6)) / 0.5, 0.0, 1.0) * fade
	_tag.add_theme_color_override("font_color", Color(1.0, 0.86, 0.62, ta * 0.75))
