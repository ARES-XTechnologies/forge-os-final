class_name AchievementsOverlay
extends Overlay
## One game's Steam achievements: a progress ring, then a grid of glass tiles — unlocked
## ones newest first with their date, locked ones sorted by how rare they are.

var game: Dictionary
var preset: Dictionary = {}       # for previews / tests
var _data: Dictionary = {}
var _grid: Control
var _tiles: Array = []
var _focus := 0
var _scroll: Spring
var _ring: Control
var _ring_v: Spring
var _title: Label
var _sub: Label
const COLS := 4
const TILE := Vector2(380, 132)

func build() -> void:
	covers_screen = true
	from_offset = Vector2(0, 90)
	var c := Control.new()
	c.name = "content"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(1640, 880)
	c.clip_contents = false
	add_child(c)
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.size = Vector2(130, 130)
	_ring.draw.connect(_draw_ring)
	c.add_child(_ring)
	_ring_v = Spring.preset(0.0, &"glide")
	_title = Tokens.label(str(game.get("name", "")), 46, 700)
	_title.position = Vector2(160, 10)
	c.add_child(_title)
	_sub = Tokens.label("Loading achievements…", 22, 500, Tokens.INK_DIM)
	_sub.position = Vector2(162, 72)
	c.add_child(_sub)
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.position = Vector2(0, 180)
	c.add_child(_grid)
	_scroll = Spring.make(0.0, 230.0, 27.0)
	Art.url_ready.connect(func(_u): for t in _tiles: (t.get_meta("icon") as Control).queue_redraw())
	if not preset.is_empty():
		_apply(preset)
	elif not SteamWeb.has_key():
		_sub.text = "Add your Steam Web API key in Settings › Library to see achievements."
	else:
		SteamWeb.achievements(int(game.appid), _apply)

func _apply(d: Dictionary) -> void:
	_data = d
	if d.is_empty():
		_sub.text = "This game has no Steam achievements."
		return
	var pct := float(d.unlocked) / maxf(1.0, float(d.total))
	_ring_v.target = pct
	_sub.text = "%d of %d unlocked  ·  %d%%" % [d.unlocked, d.total, int(pct * 100.0)]
	var i := 0
	for a in d.list:
		var t := _tile(a)
		t.position = Vector2((i % COLS) * (TILE.x + 22), (i / COLS) * (TILE.y + 22))
		t.set_meta("delay", (i % COLS) * 0.03 + (i / COLS) * 0.05)
		t.set_meta("appear", Spring.preset(1.0, &"bouncy"))
		_grid.add_child(t)
		_tiles.append(t)
		i += 1
	_apply_focus()

func _tile(a: Dictionary) -> GlassPanel:
	var t := GlassPanel.new()
	t.radius = 24
	t.bevel = 14
	t.size = TILE
	t.focus_color = Tokens.GOLD if a.achieved else Tokens.ACCENT
	t.body_dim = 0.35
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(16, 18)
	icon.size = Vector2(96, 96)
	var url: String = a.icon if a.achieved else a.icon_gray
	icon.draw.connect(func():
		var tex := Art.get_url_tex(url)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(16)
		sb.anti_aliasing = true
		sb.bg_color = Color(Tokens.GOLD, 0.25) if a.achieved else Color(1, 1, 1, 0.08)
		icon.draw_style_box(sb, Rect2(Vector2.ZERO, icon.size))
		if tex:
			icon.draw_texture_rect(tex, Rect2(Vector2(6, 6), Vector2(84, 84)), false, Color(1, 1, 1, 1.0 if a.achieved else 0.55))
		else:
			var f := Tokens.font(700)
			icon.draw_string(f, Vector2(30, 62), "★" if a.achieved else "☆", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Tokens.GOLD if a.achieved else Tokens.INK_FAINT))
	t.add_child(icon)
	t.set_meta("icon", icon)
	var hidden: bool = a.hidden and not a.achieved
	var n := Tokens.label("Hidden achievement" if hidden else str(a.name), 21, 700, Tokens.INK if a.achieved else Tokens.INK_DIM)
	n.position = Vector2(128, 16)
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Tokens.fit(n, Vector2(236, 28))
	t.add_child(n)
	var desc := Tokens.label("Keep playing to reveal it." if hidden else str(a.desc), 15, 500, Tokens.INK_FAINT)
	desc.position = Vector2(128, 46)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.clip_text = true
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Tokens.fit(desc, Vector2(236, 44))
	t.add_child(desc)
	var meta := ""
	if a.achieved and a.time > 0:
		var dt := Time.get_datetime_dict_from_unix_time(a.time)
		meta = "Unlocked %02d/%02d/%d" % [dt.day, dt.month, dt.year]
	if a.percent >= 0.0:
		meta += ("  ·  " if meta != "" else "") + ("%.1f%% of players" % a.percent)
	var m := Tokens.label(meta, 14, 600, Tokens.GOLD if (a.percent >= 0.0 and a.percent < 5.0) else Tokens.INK_FAINT)
	m.position = Vector2(128, 98)
	m.clip_text = true
	m.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Tokens.fit(m, Vector2(236, 22))
	t.add_child(m)
	return t

func _apply_focus() -> void:
	for i in _tiles.size():
		(_tiles[i] as GlassPanel).focus = 1.0 if i == _focus else 0.0
	_scroll.target = -maxf(0.0, (_focus / COLS) - 2) * (TILE.y + 22)

func nav_action(a: StringName) -> bool:
	var n := _focus
	match a:
		&"left": n -= 1
		&"right": n += 1
		&"up": n -= COLS
		&"down": n += COLS
		&"back":
			close()
			return true
		_:
			return true
	if _tiles.is_empty() or n < 0 or n >= _tiles.size() or (a in [&"left", &"right"] and n / COLS != _focus / COLS):
		Sfx.play("edge")
		return true
	_focus = n
	_apply_focus()
	Sfx.focus_tick(_focus)
	return true

func hints() -> Array:
	return [["B", "Back"]]

func _content_base() -> Vector2:
	return Vector2((size.x - 1640) * 0.5, 100)

func _draw_ring() -> void:
	var v := clampf(_ring_v.value, 0.0, 1.0)
	var c := Vector2(65, 65)
	_ring.draw_arc(c, 56, 0, TAU, 64, Color(1, 1, 1, 0.12), 10.0, true)
	if v > 0.001:
		_ring.draw_arc(c, 56, -PI / 2, -PI / 2 + TAU * v, 64, Tokens.GOLD, 10.0, true)
	var f := Tokens.font(700)
	var txt := "%d%%" % int(v * 100.0)
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_ring.draw_string(f, Vector2(65 - w * 0.5, 76), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Tokens.INK)

func animate(o: float, dt: float) -> void:
	super.animate(o, dt)
	_ring_v.step(dt)
	_ring.queue_redraw()
	_grid.position.y = 180 + _scroll.step(dt)
	for t in _tiles:
		var d: float = t.get_meta("delay")
		if d > 0.0:
			t.set_meta("delay", d - dt)
		else:
			(t.get_meta("appear") as Spring).target = 0.0
		var ap: float = (t.get_meta("appear") as Spring).step(dt)
		var y: float = _grid.position.y + t.position.y
		t.modulate.a = clampf(1.0 - maxf(ap, 0.0) * 1.3, 0.0, 1.0) * clampf((y + TILE.y - 140.0) / 90.0, 0.0, 1.0) * clampf((880.0 - y) / 120.0, 0.0, 1.0)
		(t as GlassPanel).pivot_offset = TILE * 0.5
		(t as GlassPanel).scale = Vector2.ONE * (1.0 - maxf(ap, 0.0) * 0.1)
