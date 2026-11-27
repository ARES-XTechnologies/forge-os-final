class_name GameCard
extends Control
## A game in the library: official Steam cover art inside a liquid-glass frame.
## Motion: drops in with a bounce, swells on focus with a light sweep, squashes when
## pressed, and ripples sideways when a neighbour gains focus.

const ART_SHADER := preload("res://shaders/card_art.gdshader")

var game: Dictionary = {}
var kind := "game"            # game | all_games
var focused := false
var dim_others := 0.0         # set by the row: how much to dim when not focused
var fade := 1.0               # scroll-edge fade, set by grids

var _body: Control
var _glass: GlassPanel
var _art: ColorRect
var _art_mat: ShaderMaterial
var _name: Label
var _badge: Icon
var _progress: Control
var _extra: Control

var s_scale: Spring
var s_lift: Spring
var s_focus: Spring
var s_press: Spring
var s_nudge: Spring
var s_appear: Spring
var s_dim: Spring
var _shine := -1.0
var _appear_delay := 0.0
var _has_art := false
var _uninstalled := false
var _missing := false
const INSET := 7.0

static func make(g: Dictionary, card_size: Vector2) -> GameCard:
	var c := GameCard.new()
	c.game = g
	c.size = card_size
	c.custom_minimum_size = card_size
	return c

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	Config.changed.connect(func(k): if k == "library.badges": refresh_badges())
	s_scale = Spring.preset(1.0, &"bouncy")
	s_lift = Spring.preset(0.0, &"bouncy")
	s_focus = Spring.preset(0.0, &"snappy")
	s_press = Spring.preset(0.0, &"press")
	s_nudge = Spring.preset(0.0, &"jelly")
	s_appear = Spring.preset(0.0, &"bouncy")
	s_dim = Spring.preset(0.0, &"smooth")

	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_glass = GlassPanel.new()
	_glass.radius = 26.0
	_glass.bevel = 16.0
	_glass.edge_bend = 20.0
	_glass.shadow = 0.75
	_body.add_child(_glass)

	_art = ColorRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_mat = ShaderMaterial.new()
	_art_mat.shader = ART_SHADER
	_art.material = _art_mat
	_body.add_child(_art)
	var h := hash(game.get("name", kind))
	_art_mat.set_shader_parameter("fallback_a", Color.from_hsv(fmod(abs(h) / 1000.0, 1.0), 0.55, 0.32))
	_art_mat.set_shader_parameter("fallback_b", Color.from_hsv(fmod(abs(h) / 1000.0 + 0.12, 1.0), 0.6, 0.5))

	_name = Tokens.label("", 22, 600)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.add_child(_name)

	_badge = Icon.make("star_filled", 22, Tokens.GOLD)
	_badge.visible = false
	_body.add_child(_badge)

	_progress = Control.new()
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.draw.connect(_draw_progress)
	_body.add_child(_progress)

	if kind == "all_games":
		_extra = _build_all_games()
		_body.add_child(_extra)
		_art.visible = false
	else:
		Art.art_ready.connect(_on_art)
		_refresh_art()
	_layout()
	resized.connect(_layout)
	refresh_badges()

func _build_all_games() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Icon.make("grid", 54, Tokens.INK)
	ic.name = "icon"
	c.add_child(ic)
	var l := Tokens.label("All games", 24, 600)
	l.name = "label"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l)
	var n := Tokens.label("%d in library" % SteamLib.games.size(), 17, 400, Tokens.INK_DIM)
	n.name = "count"
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(n)
	return c

func _layout() -> void:
	_body.size = size
	_body.pivot_offset = Vector2(size.x * 0.5, size.y * 0.62)
	_glass.size = size
	_art.position = Vector2(INSET, INSET)
	_art.size = size - Vector2(INSET, INSET) * 2.0
	_art_mat.set_shader_parameter("size", _art.size)
	_art_mat.set_shader_parameter("radius", 26.0 - INSET + 1.0)
	_name.position = Vector2(18, 0)
	_name.size = Vector2(size.x - 36, size.y)
	_badge.position = Vector2(size.x - 40, 18)
	_progress.position = Vector2(20, size.y - 34)
	_progress.size = Vector2(size.x - 40, 12)
	if _extra:
		_extra.size = size
		var ic: Control = _extra.get_node("icon")
		ic.position = Vector2((size.x - 54) * 0.5, size.y * 0.5 - 70)
		for n in ["label", "count"]:
			var l: Label = _extra.get_node(n)
			l.size = Vector2(size.x, 30)
			l.position = Vector2(0, size.y * 0.5 + (4 if n == "label" else 40))

func _refresh_art() -> void:
	var appid: int = game.get("appid", 0)
	var tex := Art.get_tex(appid, "portrait")
	if tex:
		_art_mat.set_shader_parameter("art", tex)
		_art_mat.set_shader_parameter("art_size", Vector2(tex.get_size()))
		_art_mat.set_shader_parameter("has_art", true)
		_has_art = true
		_name.visible = false
	else:
		_art_mat.set_shader_parameter("has_art", false)
		_name.text = game.get("name", "")
		_name.visible = true
		# Without a cover, try the wide header art scaled into the card.
		var hdr := Art.get_tex(appid, "header")
		if hdr and Art.is_missing(appid, "portrait"):
			_art_mat.set_shader_parameter("art", hdr)
			_art_mat.set_shader_parameter("art_size", Vector2(hdr.get_size()))
			_art_mat.set_shader_parameter("has_art", true)
			_art_mat.set_shader_parameter("zoom", 1.0)

func _on_art(appid: int, k: String) -> void:
	if appid == game.get("appid", -1) and (k == "portrait" or k == "header"):
		var had := _has_art
		_refresh_art()
		if _has_art and not had:
			# Art arriving gets a tiny pop so it feels alive rather than a flash.
			s_scale.kick(0.6)

func refresh_badges() -> void:
	if kind != "game":
		return
	var favs: Array = Config.get_v("library.favorites")
	_badge.visible = favs.has(game.get("appid", 0))
	_progress.visible = game.get("updating", false)
	_progress.queue_redraw()
	var not_installed: bool = not game.get("installed", true) and not game.get("updating", false) and not game.get("missing", false)
	if not_installed and _get_badge2() == null:
		var dl := Icon.make("update", 26, Tokens.INK)
		dl.name = "dl_badge"
		_body.add_child(dl)
		dl.position = Vector2(size.x - 46, size.y - 46)
	_uninstalled = not_installed
	_missing = game.get("missing", false)
	var old := _body.get_node_or_null("src_badge")
	if old:
		old.queue_free()
	if Config.get_b("library.badges") and kind == "game":
		_body.add_child(_make_badge(SteamLib.source_short(game), game))

## Small glass pill in the top-left corner saying where the game comes from.
func _make_badge(text: String, g: Dictionary) -> Control:
	var col: Color = {"steam": Color("9fc8ff"), "epic": Color("e6e9ff"), "gog": Color("c6a6ff"), "local": Color("8fffd0"), "usb": Color("ffd38a"), "retro": Color("ff9a5c")}.get(str(g.get("source", "steam")), Tokens.INK)
	var font := Tokens.font(800)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 20.0
	var b := Control.new()
	b.name = "src_badge"
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.position = Vector2(16, 16)
	b.size = Vector2(w, 24)
	b.draw.connect(func():
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		sb.anti_aliasing = true
		sb.bg_color = Color(0.03, 0.04, 0.08, 0.62)
		sb.border_color = Color(col, 0.55)
		sb.set_border_width_all(1)
		b.draw_style_box(sb, Rect2(Vector2.ZERO, b.size))
		b.draw_string(font, Vector2(10, 17), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col))
	return b

func _get_badge2() -> Node:
	return _body.get_node_or_null("dl_badge")

func _draw_progress() -> void:
	var w := _progress.size.x
	var r := Rect2(Vector2.ZERO, Vector2(w, 10))
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(5)
	sb.anti_aliasing = true
	sb.bg_color = Color(0, 0, 0, 0.55)
	_progress.draw_style_box(sb, r.grow(3))
	sb.bg_color = Tokens.ACCENT
	var p: float = game.get("progress", 0.0)
	if p > 0.0:
		_progress.draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(maxf(10.0, w * p), 10)))

# ------------------------------------------------------------------ animation API
func set_focused(f: bool, silent := false) -> void:
	if f == focused:
		return
	focused = f
	s_scale.target = 1.10 if f else 1.0
	s_lift.target = -14.0 if f else 0.0
	s_focus.target = 1.0 if f else 0.0
	if f and get_parent():
		get_parent().move_child(self, -1)   # draw on top of neighbours while it swells
	if f and not silent:
		s_scale.kick(1.6)
		_shine = 0.0

func nudge(impulse: float) -> void:
	s_nudge.kick(impulse)

func press() -> void:
	s_press.snap(0.0)
	s_press.kick(-10.0)
	s_scale.kick(-3.0)

## Drop-in entrance. `delay` in seconds, `from` is the offset it falls from.
func appear(delay: float, from := 90.0) -> void:
	set_meta("appear_from", from)
	s_appear.snap(1.0)
	modulate.a = 0.0
	_appear_delay = delay
	if delay <= 0.0:
		s_appear.target = 0.0

func _process(dt: float) -> void:
	if _appear_delay > 0.0:
		_appear_delay -= dt
		if _appear_delay > 0.0:
			return
		s_appear.target = 0.0
	var ap := s_appear.step(dt)
	var sc := s_scale.step(dt)
	var lift := s_lift.step(dt)
	var fo := clampf(s_focus.step(dt), 0.0, 1.3)
	var pr := s_press.step(dt)
	var nx := s_nudge.step(dt)
	s_dim.target = 0.0 if focused else dim_others
	var dm := s_dim.step(dt)
	var from: float = get_meta("appear_from", 90.0)
	var appear_y := ap * from
	modulate.a = clampf(1.0 - maxf(ap, 0.0) * 1.3, 0.0, 1.0)
	_body.position = Vector2(nx, lift + appear_y)
	# Squash & stretch: pressing widens and flattens slightly, then rebounds.
	_body.scale = Vector2(sc - pr * 0.05, sc + pr * 0.05)
	_glass.focus = fo
	_glass.press = absf(pr)
	var extra := 0.28 if _uninstalled else (0.45 if _missing else 0.0)
	_art_mat.set_shader_parameter("dim", clampf(dm + extra, 0.0, 0.7))
	_art_mat.set_shader_parameter("saturation", 1.0 - clampf(dm + extra, 0.0, 0.7) * 0.6)
	if _shine >= 0.0:
		_shine += dt * 1.25 * Config.anim_speed()
		_art_mat.set_shader_parameter("shine", _shine)
		_glass.shine = _shine
		if _shine > 1.25:
			_shine = -1.0
			_art_mat.set_shader_parameter("shine", -1.0)
			_glass.shine = -1.0
	_body.modulate.a = fade
