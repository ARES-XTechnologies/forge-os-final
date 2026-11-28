class_name RowList
extends Control
## Vertical list of SettingRows with a liquid-glass focus lens that glides between rows
## and a spring-driven scroll that keeps the focused row comfortably in view.

var rows: Array[SettingRow] = []
var index := 0
var active := false
var _content: Control
var _lens: GlassPanel
var _lens_y: Spring
var _lens_h: Spring
var _lens_a: Spring
var _scroll: Spring
var _clip: Control

func _init() -> void:
	# Mouse: click a row to choose it, wheel to move. Controller/keyboard work as before.
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(e: InputEvent) -> void:
	if not active:
		return
	if e is InputEventMouseButton and e.pressed:
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				move(-1)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				move(1)
				accept_event()
			MOUSE_BUTTON_LEFT:
				var y: float = e.position.y - _content.position.y
				for i in rows.size():
					var r := rows[i]
					if r.enabled and y >= r.position.y and y < r.position.y + r.row_height:
						if i != index:
							index = i
							_apply()
							Sfx.focus_tick(index)
						handle(&"accept")
						accept_event()
						return

func _ready() -> void:
	clip_contents = false
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_lens = GlassPanel.new()
	_lens.radius = 26
	_lens.bevel = 16
	_lens.edge_bend = 16
	_lens.shadow = 0.25
	_lens.tint_boost = 0.06
	_lens.focus = 0.4
	_lens.nested = true
	_content.add_child(_lens)
	_lens_y = Spring.preset(0.0, &"snappy")
	_lens_h = Spring.preset(84.0, &"bouncy")
	_lens_a = Spring.preset(0.0, &"smooth")
	_scroll = Spring.make(0.0, 240.0, 28.0)

func set_rows(list: Array) -> void:
	for r in rows:
		r.queue_free()
	rows.clear()
	var y := 0.0
	for r in list:
		var row: SettingRow = r
		_content.add_child(row)
		row.position = Vector2(0, y)
		row.size.x = size.x
		rows.append(row)
		y += row.size.y + 6.0
	_content.size = Vector2(size.x, y)
	# Start on the first row you can act on (not a status/info line).
	index = 0
	while index < rows.size() and (not rows[index].enabled or rows[index].kind == "info"):
		index += 1
	if index >= rows.size():
		index = 0
		while index < rows.size() and not rows[index].enabled:
			index += 1
	_scroll.snap(0.0)
	_apply(true)

func set_active(on: bool) -> void:
	active = on
	_lens_a.target = 1.0 if on else 0.0
	_apply()

func focused_row() -> SettingRow:
	return rows[index] if index < rows.size() else null

func _apply(instant := false) -> void:
	for i in rows.size():
		rows[i].set_focused(active and i == index)
	if index >= rows.size():
		return
	var r := rows[index]
	_lens_y.target = r.position.y
	_lens_h.target = r.row_height
	if instant:
		_lens_y.snap(r.position.y)
		_lens_h.snap(r.row_height)
	# keep focused row in the middle band of the view
	var view := size.y
	var want := _scroll.target
	var top := r.position.y + want
	if top < view * 0.22:
		want = view * 0.22 - r.position.y
	elif top + r.row_height > view * 0.78:
		want = view * 0.78 - r.position.y - r.row_height
	want = clampf(want, minf(0.0, view - _content.size.y - 20.0), 0.0)
	_scroll.target = want
	if instant:
		_scroll.snap(want)

func move(d: int) -> bool:
	var n := index + d
	while n >= 0 and n < rows.size() and not rows[n].enabled:
		n += d
	if n < 0 or n >= rows.size():
		Sfx.play("edge")
		_lens_y.kick(d * 180.0)
		return false
	index = n
	_apply()
	Sfx.focus_tick(index)
	return true

func handle(a: StringName) -> bool:
	match a:
		&"up": return move(-1)
		&"down": return move(1)
		&"page_prev": return move(-mini(6, index))
		&"page_next": return move(mini(6, rows.size() - 1 - index))
	var r := focused_row()
	if r and r.handle(a):
		for row in rows:
			if row != r:
				row.refresh()
		return true
	return false

func refresh_all() -> void:
	for r in rows:
		r.refresh()

func _process(dt: float) -> void:
	var sy := _scroll.step(dt)
	_content.position.y = sy
	var ly := _lens_y.step(dt)
	var lh := _lens_h.step(dt)
	_lens.position = Vector2(0, ly)
	_lens.size = Vector2(size.x, maxf(lh, 40.0))
	_lens.glass_opacity = clampf(_lens_a.step(dt), 0.0, 1.0)
	_lens.visible = _lens.glass_opacity > 0.01
	for r in rows:
		r.size.x = size.x
		var y := r.position.y + sy
		# fade rows near the clipped edges for a soft scroll mask
		# (measured from the row's middle, so a row never pokes out past the panel's edge)
		var mid := y + r.row_height * 0.5
		var a := clampf(minf(mid / 50.0, (size.y - mid) / 50.0), 0.0, 1.0)
		r.modulate.a = a
		r.visible = a > 0.0
