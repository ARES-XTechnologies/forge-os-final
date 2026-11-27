class_name Toasts
extends Control
## Premium notifications: glass cards that drop in at the top right with a bounce,
## a glowing icon orb (or a picture), a title and a line of detail, an optional progress
## bar, and a light that sweeps once across the card. They stack and slide away on their own.
## Over a running game they become smoked glass so they're readable on any scene.

var ingame := false:
	set(v):
		ingame = v
		for it in _items:
			(it.panel as GlassPanel).ingame = v
var _items: Array = []   # {panel, in, life, slot, total, title, body, progress_node}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Shellbus.notify_requested.connect(show_data)

func show_toast(text: String, icon := "info", color := Tokens.ACCENT) -> void:
	show_data({"title": text, "icon": icon, "color": color})

func show_data(d: Dictionary) -> void:
	var title := str(d.get("title", ""))
	var body := str(d.get("body", ""))
	var color: Color = d.get("color", Tokens.ACCENT)
	var w := 470.0
	var h := 92.0 if body != "" else 70.0
	# Long messages (like a reason a drive won't open) get a wider card and two lines.
	var long_title := title.length() > 36
	if long_title:
		w = 660.0
		h = 118.0 if body != "" else 96.0
	var p := GlassPanel.new()
	p.radius = 30
	p.focus = 0.4
	p.focus_color = color
	p.body_dim = 0.8
	p.ingame = ingame
	p.size = Vector2(w, h)
	# icon orb or picture
	var orb := Control.new()
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.position = Vector2(16, (h - 52) * 0.5)
	orb.size = Vector2(52, 52)
	var tex: Texture2D = d.get("image", null)
	var url := str(d.get("image_url", ""))
	if tex == null and d.has("appid"):
		tex = Art.get_tex(int(d.appid), "portrait")
	orb.draw.connect(func():
		var t2: Texture2D = tex
		if t2 == null and url != "":
			t2 = Art.get_url_tex(url)
		var c := orb.size * 0.5
		orb.draw_circle(c, 26.0, Color(color, 0.22))
		orb.draw_arc(c, 25.0, 0, TAU, 48, Color(color, 0.9), 2.0, true)
		if t2:
			var r := Rect2(Vector2(6, 6), Vector2(40, 40))
			orb.draw_texture_rect(t2, r, false)
		else:
			pass)
	p.add_child(orb)
	if tex == null and url == "":
		var ic := Icon.make(str(d.get("icon", "info")), 26, color.lightened(0.25))
		ic.position = orb.position + Vector2(13, 13)
		p.add_child(ic)
	var tl := Tokens.label(title, 21 if not long_title else 19, 700)
	tl.position = Vector2(84, 18 if body != "" else 22)
	tl.size = Vector2(w - 104, 28)
	tl.clip_text = true
	if long_title:
		tl.position.y = 14
		tl.clip_text = false
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.max_lines_visible = 2
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tl.size = Vector2(w - 104, 56)
	p.add_child(tl)
	if body != "":
		var bl := Tokens.label(body, 17, 500, Tokens.INK_DIM)
		bl.position = Vector2(84, 50 if not long_title else 76)
		bl.size = Vector2(w - 104, 24)
		bl.clip_text = true
		p.add_child(bl)
	add_child(p)
	var s := Spring.preset(1.0, &"bouncy")
	s.target = 0.0
	var slot := Spring.preset(110.0, &"snappy")
	var life: float = d.get("duration", 4.5 if not long_title else 7.0)
	_items.push_front({"panel": p, "in": s, "life": life, "slot": slot, "shine": 0.0, "orb": orb})
	Sfx.play(str(d.get("sound", "notify")), 1.0, -4.0)
	Sfx.haptic(0.2, 0.0, 40)
	while _items.size() > 4:
		_items[-1].life = minf(_items[-1].life, 0.05)
		break

func _process(dt: float) -> void:
	var y := 150.0 if not ingame else 60.0
	for i in range(_items.size() - 1, -1, -1):
		var it: Dictionary = _items[i]
		it.life -= dt
		if it.life <= 0.0:
			it["in"].target = 1.4
		if it.life < -0.8:
			it.panel.queue_free()
			_items.remove_at(i)
	for it in _items:
		var p: GlassPanel = it.panel
		var v: float = it["in"].step(dt)
		it.slot.target = y
		var sy: float = it.slot.step(dt)
		p.position = Vector2(size.x - Tokens.SAFE_X * (0.5 if ingame else 1.0) - p.size.x + v * 90.0, sy - maxf(v, 0.0) * 40.0)
		p.modulate.a = clampf(1.0 - absf(v), 0.0, 1.0)
		it.shine += dt * 0.9
		p.shine = it.shine if it.shine < 1.3 else -1.0
		(it.orb as Control).queue_redraw()
		y += p.size.y + 14.0
