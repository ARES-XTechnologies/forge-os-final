class_name MediaViewer
extends Overlay
## Full-screen screenshot viewer. Left/right slides between shots on a spring.

var items: Array = []
var index := 0
var _a: TextureRect
var _b: TextureRect
var _slide: Spring
var _caption: Label
var _tex := {}

func build() -> void:
	from_offset = Vector2.ZERO
	open_scale = 0.9
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.82)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var c := Control.new()
	c.name = "content"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.clip_contents = true
	add_child(c)
	_a = _make_view(c)
	_b = _make_view(c)
	_caption = Tokens.label("", 22, 500, Tokens.INK_DIM)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_caption)
	_slide = Spring.preset(0.0, &"snappy")
	_show(index, 0)

func _make_view(parent: Control) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

func _content_base() -> Vector2:
	return Vector2(80, 70)

func _load(i: int) -> Texture2D:
	var p: String = items[i].path
	if _tex.has(p):
		return _tex[p]
	var img := Image.new()
	if img.load(p) != OK:
		return null
	_tex[p] = ImageTexture.create_from_image(img)
	return _tex[p]

func _show(i: int, dir: int) -> void:
	_b.texture = _a.texture
	_a.texture = _load(i)
	_slide.snap(float(dir))
	_slide.target = 0.0
	var it: Dictionary = items[i]
	var g: Dictionary = SteamLib.by_id.get(it.appid, {})
	var dt := Time.get_datetime_dict_from_unix_time(it.time)
	_caption.text = "%s   ·   %02d/%02d/%d %02d:%02d   ·   %d of %d" % [g.get("name", it.get("game", "Screenshot")), dt.day, dt.month, dt.year, dt.hour, dt.minute, i + 1, items.size()]

func nav_action(a: StringName) -> bool:
	match a:
		&"left", &"right":
			var d := 1 if a == &"right" else -1
			var n := index + d
			if n < 0 or n >= items.size():
				Sfx.play("edge")
				_slide.kick(-d * 1.5)
			else:
				index = n
				_show(index, d)
				Sfx.focus_tick(index)
		&"back", &"accept":
			close()
	return true

func hints() -> Array:
	return [["◀▶", "Browse"], ["B", "Close"]]

func animate(o: float, dt: float) -> void:
	var c := get_node("content") as Control
	c.size = size - Vector2(160, 200)
	super.animate(o, dt)
	var s := _slide.step(dt)
	_a.size = c.size
	_b.size = c.size
	_a.position = Vector2(s * c.size.x * 0.6, 0)
	_b.position = Vector2((s - signf(s)) * c.size.x * 0.6, 0) if absf(s) > 0.001 else Vector2(99999, 0)
	_a.modulate.a = 1.0 - absf(s) * 0.6
	_b.modulate.a = absf(s)
	Tokens.fit(_caption, Vector2(size.x, 30))
	_caption.position = Vector2(0, size.y - 100)
