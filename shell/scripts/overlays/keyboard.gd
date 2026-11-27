class_name Keyboard
extends Overlay
## On-screen keyboard for controllers. A single glass lens glides between keys on a
## spring (and stretches when it travels far), so typing feels fluid instead of grid-snappy.
## Shortcuts: X backspace · Y space · LT/RT move cursor · ☰ done · B close

var title := "Type"
var text := ""
var secret := false
var on_done: Callable
var on_change: Callable

const LETTERS := [
	["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
	["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
	["a", "s", "d", "f", "g", "h", "j", "k", "l", "'"],
	["⇧", "z", "x", "c", "v", "b", "n", "m", "-", "⌫"],
	["?123", "space", "@", ".", "Done"],
]
const SYMBOLS := [
	["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"],
	["/", "\\", "_", "=", "+", "[", "]", "{", "}", "|"],
	[";", ":", "\"", ",", "<", ">", "?", "~", "`", "'"],
	["ABC", "€", "£", "¥", "₹", "°", "•", "…", "-", "⌫"],
	["ABC", "space", ".com", ".", "Done"],
]
const UNIT := 104.0
const KEY_H := 78.0
const GAP := 10.0

var _panel: GlassPanel
var _field: GlassPanel
var _field_text: Label
var _caret: ColorRect
var _keys_root: Control
var _lens: GlassPanel
var _rows: Array = []        # Array of rows; each row: Array of {label, rect, node}
var _r := 1
var _c := 0
var _shift := false
var _symbols := false
var _lens_pos: Spring2
var _lens_size: Spring2
var _blink := 0.0
var _pop: Spring

func build() -> void:
	from_offset = Vector2(0, 340)
	open_scale = 1.0
	_panel = GlassPanel.new()
	_panel.name = "content"
	_panel.radius = 44
	_panel.shadow = 1.0
	_panel.body_dim = 0.9
	_panel.glow_scale = 0.75
	add_child(_panel)
	var t := Tokens.label(title, 22, 600, Tokens.INK_DIM)
	t.position = Vector2(40, 30)
	_panel.add_child(t)
	_field = GlassPanel.new()
	_field.radius = 26
	_field.tint_boost = -0.04
	_field.nested = true
	_field.position = Vector2(34, 70)
	_panel.add_child(_field)
	_field_text = Tokens.label("", 32, 500)
	_field_text.position = Vector2(28, 12)
	_field_text.clip_text = true
	_field.add_child(_field_text)
	_caret = ColorRect.new()
	_caret.color = Tokens.ACCENT
	_caret.size = Vector2(3, 38)
	_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(_caret)
	_keys_root = Control.new()
	_keys_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys_root.position = Vector2(34, 170)
	_panel.add_child(_keys_root)
	_lens = GlassPanel.new()
	_lens.radius = 20
	_lens.bevel = 14
	_lens.magnify = 0.08
	_lens.focus = 0.7
	_lens.tint_boost = 0.1
	_lens.shadow = 0.3
	_lens.nested = true
	_keys_root.add_child(_lens)
	_lens_pos = Spring2.preset(Vector2.ZERO, &"snappy")
	_lens_size = Spring2.preset(Vector2(UNIT, KEY_H), &"bouncy")
	_pop = Spring.preset(1.0, &"jelly")
	_build_keys()
	var w := 10 * UNIT + 9 * GAP
	_field.size = Vector2(w, 66)
	# The label clips its text, so it needs a real size; with none it showed nothing at all
	# and typed names / passwords looked like they weren't being entered.
	_field_text.size = Vector2(w - 56, 44)
	_panel.size = Vector2(w + 68, 170 + 5 * (KEY_H + GAP) + 30)
	_update_text()
	_move_lens(true)

func _content_base() -> Vector2:
	return Vector2((size.x - _panel.size.x) * 0.5, size.y - _panel.size.y - 100)

func _layout_rows() -> Array:
	return SYMBOLS if _symbols else LETTERS

func _build_keys() -> void:
	for row in _rows:
		for k in row:
			k.node.queue_free()
	_rows.clear()
	var layout := _layout_rows()
	var y := 0.0
	for ri in layout.size():
		var row: Array = layout[ri]
		var items := []
		var widths := []
		for k in row:
			widths.append(_key_units(k))
		var total := 0.0
		for wv in widths: total += wv * UNIT + (wv - 1) * GAP
		total += GAP * (row.size() - 1)
		var x := (10 * UNIT + 9 * GAP - total) * 0.5
		for i in row.size():
			var k: String = row[i]
			var w: float = widths[i] * UNIT + (widths[i] - 1) * GAP
			var node := Control.new()
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.position = Vector2(x, y)
			node.size = Vector2(w, KEY_H)
			node.draw.connect(_draw_key.bind(node))
			var l := Tokens.label(_display(k), 28 if k.length() == 1 else 22, 500)
			l.name = "l"
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.size = node.size
			node.add_child(l)
			_keys_root.add_child(node)
			items.append({"key": k, "rect": Rect2(node.position, node.size), "node": node})
			x += w + GAP
		_rows.append(items)
		y += KEY_H + GAP
	_keys_root.move_child(_lens, 0)
	_r = clampi(_r, 0, _rows.size() - 1)
	_c = clampi(_c, 0, _rows[_r].size() - 1)

func _key_units(k: String) -> float:
	match k:
		"space": return 4.0
		"Done": return 2.0
		"?123", "ABC", ".com": return 1.5 if k != ".com" else 1.0
	return 1.0

func _display(k: String) -> String:
	if k.length() == 1 and _shift:
		return k.to_upper()
	if k == "space":
		return "space"
	return k

func _draw_key(node: Control) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(18)
	sb.anti_aliasing = true
	sb.bg_color = Color(1, 1, 1, 0.06)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	node.draw_style_box(sb, Rect2(Vector2.ZERO, node.size))

func _cur() -> Dictionary:
	return _rows[_r][_c]

func _move_lens(instant := false) -> void:
	var rect: Rect2 = _cur().rect
	var d := rect.position.distance_to(_lens_pos.target)
	_lens_pos.target = rect.position
	_lens_size.target = rect.size
	if instant:
		_lens_pos.snap(rect.position)
		_lens_size.snap(rect.size)
	elif d > UNIT * 2.5:
		# long jumps stretch the lens a little
		_lens_size.kick(Vector2(d * 2.0, -60))
	for row in _rows:
		for k in row:
			(k.node.get_node("l") as Label).add_theme_color_override("font_color", Tokens.INK_DIM)
	(_cur().node.get_node("l") as Label).add_theme_color_override("font_color", Tokens.INK)

func _update_text() -> void:
	var shown := ("•".repeat(text.length())) if secret else text
	_field_text.text = shown
	if on_change.is_valid():
		on_change.call(text)

func _type(k: String) -> void:
	match k:
		"⌫":
			if text.length() > 0:
				text = text.substr(0, text.length() - 1)
			else:
				Sfx.play("edge")
		"⇧":
			_shift = not _shift
			_refresh_labels()
		"space":
			text += " "
		"?123":
			_symbols = true
			_build_keys()
		"ABC":
			_symbols = false
			_build_keys()
		"Done":
			_done()
			return
		_:
			var ch := k.to_upper() if (_shift and k.length() == 1) else k
			text += ch
			if _shift:
				_shift = false
				_refresh_labels()
	Sfx.play("key", randf_range(0.95, 1.08))
	Sfx.haptic(0.15, 0.0, 18)
	_pop.kick(-3.0)
	_update_text()
	_move_lens(true)

func _refresh_labels() -> void:
	for row in _rows:
		for k in row:
			(k.node.get_node("l") as Label).text = _display(k.key)

func _done() -> void:
	Sfx.confirm()
	var cb := on_done
	var t := text
	close()
	if cb.is_valid():
		cb.call(t)

## Physical keyboard: letters/numbers type, Backspace deletes, Enter finishes,
## Escape closes. Arrow keys still move around the on-screen keys.
func type_key(e: InputEventKey) -> bool:
	match e.keycode:
		KEY_BACKSPACE:
			_type("⌫")
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_done()
			return true
		KEY_ESCAPE:
			Sfx.back()
			close()
			return true
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_TAB:
			return false
	if e.unicode >= 32:
		text += char(e.unicode)
		Sfx.play("key", randf_range(0.95, 1.08))
		_pop.kick(-3.0)
		_update_text()
		return true
	return false

func nav_action(a: StringName) -> bool:
	match a:
		&"left", &"right":
			var n := _c + (1 if a == &"right" else -1)
			if n < 0: n = _rows[_r].size() - 1
			elif n >= _rows[_r].size(): n = 0
			_c = n
			_move_lens()
			Sfx.focus_tick(_c)
		&"up", &"down":
			var nr := _r + (1 if a == &"down" else -1)
			if nr < 0 or nr >= _rows.size():
				Sfx.play("edge")
				return true
			var cx := (_cur().rect as Rect2).get_center().x
			_r = nr
			var best := 0
			var bd := INF
			for i in _rows[_r].size():
				var dd := absf((_rows[_r][i].rect as Rect2).get_center().x - cx)
				if dd < bd:
					bd = dd
					best = i
			_c = best
			_move_lens()
			Sfx.focus_tick(_r + 3)
		&"accept":
			_type(_cur().key)
		&"alt":
			_type("⌫")
		&"menu":
			_type("space")
		&"start":
			_done()
		&"page_prev":
			_shift = not _shift
			_refresh_labels()
			Sfx.play("toggle_on")
		&"back":
			Sfx.back()
			close()
	return true

func hints() -> Array:
	return [["A", "Type"], ["X", "Delete"], ["Y", "Space"], ["☰", "Done"], ["B", "Close"]]

func animate(o: float, dt: float) -> void:
	super.animate(o, dt)
	var p := _lens_pos.step(dt)
	var s := _lens_size.step(dt)
	var pop := _pop.step(dt)
	var sz := Vector2(maxf(s.x, 40.0), maxf(s.y, 40.0))
	var target_size: Vector2 = _lens_size.target
	_lens.size = sz * Vector2(1.0, 1.0)
	_lens.position = p - (sz - target_size) * 0.5
	_lens.pivot_offset = sz * 0.5
	_lens.scale = Vector2(pop, pop)
	_blink += dt
	# (get_minimum_size() is 0 for a clipping label, so measure the text itself)
	var font := _field_text.get_theme_font("font")
	var fs := _field_text.get_theme_font_size("font_size")
	var tw := font.get_string_size(_field_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if font else 0.0
	_caret.position = Vector2(30 + minf(tw, _field.size.x - 60), 14)
	_caret.visible = fmod(_blink, 1.0) < 0.6
