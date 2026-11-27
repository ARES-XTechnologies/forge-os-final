class_name SettingRow
extends Control
## One row in Settings / Quick menu.
## kinds: "toggle" "choice" "slider" "action" "info" "header"
## Values bind to a Config key, or to custom get/set callables.

var kind := "action"
var title := ""
var sub := ""
var icon_name := ""
var key := ""                 # Config key
var getter: Callable
var setter: Callable
var options: Array = []       # choice: [[value, "Label"], ...]
var vmin := 0.0
var vmax := 1.0
var vstep := 0.1
var fmt: Callable             # slider/info value formatter
var on_press: Callable
var focused := false
var enabled := true
var row_height := 84.0

var _title: Label
var _sub: Label
var _icon: Icon
var _value: Label
var _value_old: Label
var _knob: Spring
var _fill: Spring
var _slide: Spring
var _pop: Spring
var _focus_s: Spring

static func toggle(t: String, k: String, ic := "", s := "") -> SettingRow:
	var r := SettingRow.new(); r.kind = "toggle"; r.title = t; r.key = k; r.icon_name = ic; r.sub = s; return r

static func choice(t: String, k: String, opts: Array, ic := "", s := "") -> SettingRow:
	var r := SettingRow.new(); r.kind = "choice"; r.title = t; r.key = k; r.options = opts; r.icon_name = ic; r.sub = s; return r

static func slider(t: String, k: String, mn: float, mx: float, st: float, f: Callable = Callable(), ic := "", s := "") -> SettingRow:
	var r := SettingRow.new(); r.kind = "slider"; r.title = t; r.key = k; r.vmin = mn; r.vmax = mx; r.vstep = st; r.fmt = f; r.icon_name = ic; r.sub = s; return r

static func action(t: String, cb: Callable, ic := "", s := "", value_fmt: Callable = Callable()) -> SettingRow:
	var r := SettingRow.new(); r.kind = "action"; r.title = t; r.on_press = cb; r.icon_name = ic; r.sub = s; r.fmt = value_fmt; return r

static func info(t: String, value_fmt: Callable, ic := "") -> SettingRow:
	var r := SettingRow.new(); r.kind = "info"; r.title = t; r.fmt = value_fmt; r.icon_name = ic; return r

static func header(t: String) -> SettingRow:
	var r := SettingRow.new(); r.kind = "header"; r.title = t; r.row_height = 64.0; r.enabled = false; return r

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_knob = Spring.preset(0.0, &"bouncy")
	_fill = Spring.preset(0.0, &"snappy")
	_slide = Spring.preset(0.0, &"snappy")
	_pop = Spring.preset(1.0, &"jelly")
	_focus_s = Spring.preset(0.0, &"snappy")
	if kind == "header":
		_title = Tokens.label(title.to_upper(), 16, 700, Tokens.INK_FAINT)
		add_child(_title)
		size.y = row_height
		return
	var tx := 28.0
	if icon_name != "":
		_icon = Icon.make(icon_name, 28, Tokens.INK_DIM)
		add_child(_icon)
		tx = 76.0
	_title = Tokens.label(title, 25, 500, Tokens.INK_DIM)
	_title.position = Vector2(tx, 0)
	add_child(_title)
	if sub != "":
		_sub = Tokens.label(sub, 17, 400, Tokens.INK_FAINT)
		_sub.position = Vector2(tx, 0)
		add_child(_sub)
		row_height = 98.0
	_value = Tokens.label("", 23, 500, Tokens.INK_DIM)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_value)
	_value_old = Tokens.label("", 23, 500, Tokens.INK_DIM)
	_value_old.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_value_old)
	size.y = row_height
	_knob.snap(1.0 if _get_b() else 0.0)
	_fill.snap(_norm())
	refresh()

func _read():
	if getter.is_valid():
		return getter.call()
	if key != "":
		return Config.get_v(key)
	return null

func _write(v) -> void:
	if setter.is_valid():
		setter.call(v)
	elif key != "":
		Config.set_v(key, v)

func _get_b() -> bool:
	var v = _read()
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
		return v != 0
	return false

func _norm() -> float:
	if kind != "slider":
		return 0.0
	var v = _read()
	return 0.0 if v == null else clampf((float(v) - vmin) / maxf(vmax - vmin, 0.0001), 0.0, 1.0)

func refresh() -> void:
	if kind == "header" or _value == null:
		return
	match kind:
		"toggle":
			_value.text = ""
			_knob.target = 1.0 if _get_b() else 0.0
		"choice":
			_value.text = _choice_label()
		"slider":
			var v = _read()
			_value.text = fmt.call(v) if fmt.is_valid() else ("%.0f%%" % (_norm() * 100.0))
			_fill.target = _norm()
		"action", "info":
			_value.text = str(fmt.call()) if fmt.is_valid() else ""
	queue_redraw()

func _choice_label() -> String:
	var v = _read()
	for o in options:
		if o[0] == v or (typeof(o[0]) in [TYPE_INT, TYPE_FLOAT] and typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_equal_approx(float(o[0]), float(v))):
			return o[1]
	return str(v) if v != null else "—"

func _choice_index() -> int:
	var v = _read()
	for i in options.size():
		var o = options[i][0]
		if o == v or (typeof(o) in [TYPE_INT, TYPE_FLOAT] and typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_equal_approx(float(o), float(v))):
			return i
	return 0

func set_focused(f: bool) -> void:
	focused = f
	_focus_s.target = 1.0 if f else 0.0

## Returns true when the row used the action.
func handle(a: StringName) -> bool:
	if not enabled:
		return false
	match kind:
		"toggle":
			if a == &"accept" or a == &"left" or a == &"right":
				var nv := not _get_b()
				if a == &"left": nv = false
				if a == &"right": nv = true
				if nv == _get_b() and a != &"accept":
					Sfx.play("edge")
					return true
				_write(nv)
				Sfx.play("toggle_on" if nv else "toggle_off")
				Sfx.haptic(0.3, 0.1, 35)
				_knob.kick(4.0 if nv else -4.0)
				refresh()
				return true
		"choice":
			if a == &"left" or a == &"right" or a == &"accept":
				if options.is_empty():
					return true
				var d := -1 if a == &"left" else 1
				var i := _choice_index() + d
				if a == &"accept":
					i = posmod(i, options.size())
				if i < 0 or i >= options.size():
					Sfx.play("edge")
					_slide.kick(-d * 300.0)
					return true
				_value_old.text = _value.text
				_write(options[i][0])
				_slide.snap(d * 1.0)
				_slide.target = 0.0
				Sfx.focus_tick(i)
				refresh()
				return true
		"slider":
			if a == &"left" or a == &"right":
				var v := float(_read())
				var nv2 := clampf(v + (vstep if a == &"right" else -vstep), vmin, vmax)
				nv2 = snappedf(nv2, vstep)
				if is_equal_approx(nv2, v):
					Sfx.play("edge")
					return true
				_write(nv2 if typeof(_read()) == TYPE_FLOAT else int(nv2))
				Sfx.play("tick", 0.8 + _norm() * 0.8)
				Sfx.haptic(0.12, 0.0, 15)
				refresh()
				return true
		"action":
			if a == &"accept":
				_pop.kick(-3.0)
				Sfx.confirm()
				if on_press.is_valid():
					on_press.call()
				refresh()
				return true
	return false

func _process(dt: float) -> void:
	if kind == "header":
		_title.position = Vector2(28, row_height - 30)
		return
	var k := _knob.step(dt)
	var fl := _fill.step(dt)
	var sl := _slide.step(dt)
	var fo := _focus_s.step(dt)
	var pop := _pop.step(dt)
	var ink := Tokens.INK.lerp(Tokens.INK_DIM, 1.0 - clampf(fo, 0.0, 1.0))
	if not enabled:
		ink = Tokens.INK_FAINT
	_title.add_theme_color_override("font_color", ink)
	if _icon:
		_icon.color = ink
		_icon.position = Vector2(30, (row_height - 28) * 0.5)
	var ty := (row_height - 30) * 0.5 if _sub == null else 18.0
	_title.position.y = ty
	if _sub:
		_sub.position.y = 54.0
	var right := size.x - 30.0
	var cw := _choice_w()
	match kind:
		"choice":
			_value.size = Vector2(cw, 30)
			_value.position = Vector2(right - cw - 40 + sl * 70.0, (row_height - 30) * 0.5)
			_value.modulate.a = 1.0 - absf(sl)
			_value_old.size = _value.size
			_value_old.position = Vector2(right - cw - 40 - signf(sl) * (1.0 - absf(sl)) * 70.0, _value.position.y)
			_value_old.modulate.a = absf(sl) if absf(sl) > 0.02 else 0.0
		"slider":
			_value.size = Vector2(110, 30)
			_value.position = Vector2(right - 110, (row_height - 30) * 0.5)
		_:
			_value.size = Vector2(520, 30)
			_value.position = Vector2(right - 520 - (34 if kind == "action" else 0), (row_height - 30) * 0.5)
	_value.add_theme_color_override("font_color", Tokens.INK if fo > 0.5 else Tokens.INK_DIM)
	scale = Vector2(pop, pop)
	pivot_offset = size * 0.5
	set_meta("_k", k)
	set_meta("_f", fl)
	set_meta("_fo", fo)
	queue_redraw()

func _choice_w() -> float:
	return clampf(size.x * 0.34, 170.0, 320.0)

func _slider_w() -> float:
	return clampf(size.x * 0.3, 140.0, 300.0)

func _draw() -> void:
	if kind == "header":
		return
	var right := size.x - 30.0
	var cy := row_height * 0.5
	var fo: float = get_meta("_fo", 0.0)
	match kind:
		"toggle":
			var k: float = get_meta("_k", 0.0)
			var tw := 76.0
			var th := 40.0
			var r := Rect2(Vector2(right - tw, cy - th * 0.5), Vector2(tw, th))
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(20)
			sb.anti_aliasing = true
			sb.bg_color = Color(1, 1, 1, 0.12).lerp(Tokens.ACCENT, clampf(k, 0.0, 1.0) * 0.9)
			sb.border_color = Color(1, 1, 1, 0.18)
			sb.set_border_width_all(1)
			draw_style_box(sb, r)
			var kx := lerpf(r.position.x + 20.0, r.end.x - 20.0, k)
			var stretch := clampf(absf(_knob.velocity) * 0.8, 0.0, 10.0)
			var kb := StyleBoxFlat.new()
			kb.set_corner_radius_all(16)
			kb.anti_aliasing = true
			kb.bg_color = Color.WHITE
			kb.shadow_color = Color(0, 0, 0, 0.35)
			kb.shadow_size = 6
			draw_style_box(kb, Rect2(Vector2(kx - 16 - stretch * 0.5, cy - 16), Vector2(32 + stretch, 32)))
		"choice":
			var c := Color(1, 1, 1, 0.25 + 0.6 * fo)
			var lx := right - _choice_w() - 40 - 10
			draw_polyline(PackedVector2Array([Vector2(lx, cy - 9), Vector2(lx - 8, cy), Vector2(lx, cy + 9)]), c, 2.5, true)
			draw_polyline(PackedVector2Array([Vector2(right + 2, cy - 9), Vector2(right + 10, cy), Vector2(right + 2, cy + 9)]), c, 2.5, true)
		"slider":
			var f: float = get_meta("_f", 0.0)
			var w := _slider_w()
			var x0 := right - 130.0 - w
			var bar := Rect2(Vector2(x0, cy - 5), Vector2(w, 10))
			var sb2 := StyleBoxFlat.new()
			sb2.set_corner_radius_all(5)
			sb2.anti_aliasing = true
			sb2.bg_color = Color(1, 1, 1, 0.14)
			draw_style_box(sb2, bar)
			sb2.bg_color = Tokens.ACCENT.lerp(Color.WHITE, 0.15)
			draw_style_box(sb2, Rect2(bar.position, Vector2(maxf(10.0, w * clampf(f, 0.0, 1.0)), 10)))
			draw_circle(Vector2(x0 + w * clampf(f, 0.0, 1.0), cy), 11.0 + 3.0 * fo, Color.WHITE)
		"action":
			if on_press.is_valid():
				var c2 := Color(1, 1, 1, 0.3 + 0.6 * fo)
				draw_polyline(PackedVector2Array([Vector2(right - 6, cy - 9), Vector2(right + 2, cy), Vector2(right - 6, cy + 9)]), c2, 2.5, true)
