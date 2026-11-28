class_name DownloadsOverlay
extends Overlay
## Downloads: every game installing or updating, with live progress, speed and time left.

var _card: GlassPanel
var _box: Control
var _rows: Array = []
var _empty: Label
var _btn: PillButton
var _fill := {}      # appid -> Spring

func build() -> void:
	from_offset = Vector2(0, 80)
	_card = GlassPanel.new()
	_card.name = "content"
	_card.radius = 44
	_card.body_dim = 0.95
	_card.ingame = shell.ingame if shell else false
	_card.size = Vector2(1100, 720)
	add_child(_card)
	var t := Tokens.label("Downloads", 44, 700)
	t.position = Vector2(52, 40)
	_card.add_child(t)
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.position = Vector2(52, 130)
	_card.add_child(_box)
	_empty = Tokens.label("Nothing downloading right now.", 24, 500, Tokens.INK_DIM)
	_empty.position = Vector2(52, 140)
	_card.add_child(_empty)
	_btn = PillButton.make("Open Steam downloads", "steam", 64, 22)
	_btn.nested = true
	_btn.position = Vector2(52, 620)
	_btn.pressed.connect(func():
		SteamLib.open_downloads()
		close())
	_card.add_child(_btn)
	_btn.set_focused(true)
	var note := Tokens.label("Pause, resume and download order are in Steam's downloads window.", 17, 500, Tokens.INK_FAINT)
	note.position = Vector2(_btn.size.x + 80, 642)
	_card.add_child(note)
	Downloads.changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	_empty.visible = Downloads.items.is_empty()
	var y := 0.0
	for it in Downloads.items.slice(0, 4):
		var row := Control.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.position = Vector2(0, y)
		row.size = Vector2(996, 106)
		var id: int = it.appid
		if not _fill.has(id):
			_fill[id] = Spring.preset(0.0, &"smooth")
		(_fill[id] as Spring).target = it.progress
		var art := TextureRect.new()
		art.texture = Art.get_tex(id, "header")
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.size = Vector2(176, 82)
		art.position = Vector2(0, 6)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(art)
		var n := Tokens.label(str(it.name), 24, 600)
		n.position = Vector2(200, 4)
		row.add_child(n)
		var info := "%s  ·  %s" % [Downloads.fmt_speed(it.speed), Downloads.fmt_eta(it.eta)] if it.total > 0 else Downloads.fmt_speed(it.speed)
		var d := Tokens.label(info, 18, 500, Tokens.INK_DIM)
		d.position = Vector2(200, 40)
		row.add_child(d)
		var pct := Tokens.label("%d%%" % int(it.progress * 100.0), 22, 700, Tokens.ACCENT)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		Tokens.fit(pct, Vector2(120, 30))
		pct.position = Vector2(876, 4)
		row.add_child(pct)
		var bar := Control.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.position = Vector2(200, 76)
		bar.size = Vector2(796, 12)
		bar.draw.connect(func():
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(6)
			sb.anti_aliasing = true
			sb.bg_color = Color(1, 1, 1, 0.12)
			bar.draw_style_box(sb, Rect2(Vector2.ZERO, bar.size))
			var f: float = clampf((_fill[id] as Spring).value, 0.0, 1.0)
			sb.bg_color = Tokens.ACCENT
			bar.draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(maxf(12.0, bar.size.x * f), 12))))
		row.add_child(bar)
		row.set_meta("bar", bar)
		_box.add_child(row)
		_rows.append(row)
		y += 118.0

func nav_action(a: StringName) -> bool:
	match a:
		&"accept": _btn.press()
		&"back", &"guide": close()
	return true

func hints() -> Array:
	return [["A", "Open Steam downloads"], ["B", "Back"]]

func animate(o: float, dt: float) -> void:
	super.animate(o, dt)
	for id in _fill:
		(_fill[id] as Spring).step(dt)
	for r in _rows:
		(r.get_meta("bar") as Control).queue_redraw()
