class_name TopBar
extends Control
## Clock, the liquid tab pill, and system status.
## The tab indicator is a lens of glass whose leading edge moves faster than its
## trailing edge, so it stretches like a drop of liquid as it slides between tabs.

const TABS := ["Home", "Library", "Media", "Settings"]

var _clock: Label
var _date: Label
var _pill: GlassPanel
var _lens: GlassPanel
var _tab_labels: Array[Label] = []
var _tab_x: Array[float] = []
var _tab_w: Array[float] = []
var _edge_l: Spring
var _edge_r: Spring
var _lens_squash: Spring
var current := 0
var _status: HBoxContainer
var _net_icon: Icon
var _pad_icon: Icon
var _pad_count: Label
var _bt_icon: Icon
var _net_t := 0.0
var _clock_s: Spring

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock = Tokens.label("", 56, 250)
	add_child(_clock)
	_date = Tokens.label("", 18, 500, Tokens.INK_FAINT)
	add_child(_date)
	_clock_s = Spring.preset(1.0, &"jelly")

	_pill = GlassPanel.new()
	_pill.radius = 36
	_pill.bevel = 20
	_pill.edge_bend = 22
	_pill.shadow = 0.4
	add_child(_pill)
	_lens = GlassPanel.new()
	_lens.radius = 28
	_lens.bevel = 16
	_lens.edge_bend = 16
	_lens.magnify = 0.06
	_lens.shadow = 0.25
	_lens.tint_boost = 0.12
	_lens.focus = 0.35
	_lens.nested = true
	_pill.add_child(_lens)
	var x := 10.0
	var font := Tokens.font(500)
	for t in TABS:
		var l := Tokens.label(t, 25, 500, Tokens.INK_DIM)
		_pill.add_child(l)
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x + 52.0
		l.position = Vector2(x + 26.0, 17)
		_tab_labels.append(l)
		_tab_x.append(x)
		_tab_w.append(w)
		x += w
	_pill.size = Vector2(x + 10.0, 72)
	_edge_l = Spring.make(_tab_x[0], 620.0, 36.0)
	_edge_r = Spring.make(_tab_x[0] + _tab_w[0], 620.0, 36.0)
	_lens_squash = Spring.preset(0.0, &"jelly")

	_status = HBoxContainer.new()
	_status.add_theme_constant_override("separation", 22)
	_status.alignment = BoxContainer.ALIGNMENT_END
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)
	_pad_count = Tokens.label("", 17, 600, Tokens.INK_DIM)
	_pad_icon = Icon.make("controller", 30, Tokens.INK_DIM)
	_bt_icon = Icon.make("bluetooth", 26, Tokens.INK_DIM)
	_net_icon = Icon.make("wifi", 28, Tokens.INK_DIM)
	var pad_box := HBoxContainer.new()
	pad_box.add_theme_constant_override("separation", 6)
	pad_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad_box.add_child(_pad_icon)
	pad_box.add_child(_pad_count)
	_status.add_child(pad_box)
	_status.add_child(_net_icon)
	Nav.device_changed.connect(_update_pads)
	_update_pads()
	_update_net()
	resized.connect(_layout)
	Config.changed.connect(func(k): if k.begins_with("appearance.clock"): _update_clock(true))
	_layout()
	set_tab(0, true)

func _layout() -> void:
	var cs := Config.get_f("appearance.clock_size")
	_clock.add_theme_font_size_override("font_size", int(56 * cs))
	_clock.position = Vector2(Tokens.SAFE_X, Tokens.SAFE_TOP - 8)
	_pill.position = Vector2((size.x - _pill.size.x) * 0.5, Tokens.SAFE_TOP)
	_status.position = Vector2(size.x - Tokens.SAFE_X - 200, Tokens.SAFE_TOP + 20)
	_status.size = Vector2(200, 32)

func set_tab(i: int, instant := false) -> void:
	var prev := current
	current = i
	var L := _tab_x[i] + 6.0
	var R := _tab_x[i] + _tab_w[i] - 6.0
	# Leading edge is stiff and fast, trailing edge lags: liquid stretch.
	var going_right := i > prev
	_edge_l.stiffness = 260.0 if going_right else 760.0
	_edge_l.damping = 24.0 if going_right else 38.0
	_edge_r.stiffness = 760.0 if going_right else 260.0
	_edge_r.damping = 38.0 if going_right else 24.0
	_edge_l.target = L
	_edge_r.target = R
	if instant:
		_edge_l.snap(L)
		_edge_r.snap(R)
	else:
		_lens_squash.kick(6.0)
	for k in _tab_labels.size():
		_tab_labels[k].add_theme_color_override("font_color", Tokens.INK if k == i else Tokens.INK_DIM)

func _update_pads() -> void:
	var n := Input.get_connected_joypads().size()
	_pad_icon.color = Tokens.INK if n > 0 else Tokens.INK_FAINT
	_pad_count.text = str(n) if n > 1 else ""

func _update_net() -> void:
	Sys.net_status(func(st: Dictionary):
		if st.wired:
			_net_icon.icon = "ethernet"
			_net_icon.color = Tokens.INK
		elif st.wifi_ssid != "":
			_net_icon.icon = "wifi"
			_net_icon.value = 1.0
			_net_icon.color = Tokens.INK
		else:
			_net_icon.icon = "wifi_off"
			_net_icon.color = Tokens.INK_FAINT)

var _last_clock := ""
func _update_clock(force := false) -> void:
	var t := Time.get_datetime_dict_from_system()
	var h: int = t.hour
	var text := ""
	if Config.get_b("appearance.clock_24h"):
		text = "%02d:%02d" % [h, t.minute]
	else:
		text = "%d:%02d" % [12 if h % 12 == 0 else h % 12, t.minute]
	if Config.get_b("appearance.clock_seconds"):
		text += ":%02d" % t.second
	if text != _last_clock or force:
		if _last_clock != "" and not force:
			_clock_s.kick(0.35)
		_last_clock = text
		_clock.text = text
		_layout()
	_clock.add_theme_color_override("font_color", Tokens.clock_color())
	var days := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	_date.text = "%s %d %s" % [days[t.weekday], t.day, months[t.month - 1]]
	_date.position = Vector2(Tokens.SAFE_X + 4, _clock.position.y + _clock.get_minimum_size().y - 4)

func _process(dt: float) -> void:
	_update_clock()
	var cs := _clock_s.step(dt)
	_clock.pivot_offset = Vector2(0, _clock.size.y * 0.5)
	_clock.scale = Vector2(cs, cs)
	var l := _edge_l.step(dt)
	var r := _edge_r.step(dt)
	var sq := _lens_squash.step(dt)
	var w := maxf(r - l, 40.0)
	var h := 56.0 - clampf(sq, -4.0, 6.0) * 1.2
	_lens.position = Vector2(l, (72.0 - h) * 0.5)
	_lens.size = Vector2(w, h)
	_lens.radius = h * 0.5
	_net_t += dt
	if _net_t > 8.0:
		_net_t = 0.0
		_update_net()

# ------------------------------------------------------------------ mouse
signal tab_clicked(i: int)

## Click a tab name to switch to it.
func _input(e: InputEvent) -> void:
	if not visible or not (e is InputEventMouseButton) or not e.pressed or e.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = _pill.get_global_transform().affine_inverse() * e.global_position
	if not Rect2(Vector2.ZERO, _pill.size).has_point(p):
		return
	for i in _tab_x.size():
		if p.x >= _tab_x[i] and p.x < _tab_x[i] + _tab_w[i]:
			tab_clicked.emit(i)
			get_viewport().set_input_as_handled()
			return
