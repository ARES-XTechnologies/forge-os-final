class_name LaunchOverlay
extends Control
## The moment between pressing Play and the game appearing.
## The cover lifts out of the row into the centre, a glass ring orbits it, and the
## world dims. When the game window takes over, everything zooms past the camera.

var shell: Shell
var game: Dictionary = {}
var _open: Spring
var _zoom: Spring
var _t := 0.0
var _active := false
var _card: GlassPanel
var _art: ColorRect
var _art_mat: ShaderMaterial
var _title: Label
var _status: Label
var _ring: Control
var _from := Vector2.ZERO
var _pos: Spring2

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_open = Spring.preset(0.0, &"bouncy")
	_zoom = Spring.preset(1.0, &"smooth")
	_pos = Spring2.preset(Vector2.ZERO, &"bouncy")
	_card = GlassPanel.new()
	_card.radius = 34
	_card.size = Vector2(300, 450)
	_card.shadow = 0.9
	_card.focus = 0.8
	_card.focus_color = Tokens.GOLD
	add_child(_card)
	_art = ColorRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_mat = ShaderMaterial.new()
	_art_mat.shader = preload("res://shaders/card_art.gdshader")
	_art.material = _art_mat
	_art.position = Vector2(9, 9)
	_art.size = Vector2(282, 432)
	_art_mat.set_shader_parameter("size", _art.size)
	_art_mat.set_shader_parameter("radius", 26.0)
	_card.add_child(_art)
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_title = Tokens.label("", 34, 700)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_status = Tokens.label("", 20, 500, Tokens.INK_DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)
	visible = false

func start(g: Dictionary, from_card: Control) -> void:
	game = g
	_active = true
	visible = true
	_t = 0.0
	_title.text = g.name
	_status.text = "Starting…"
	var tex := Art.get_tex(g.appid, "portrait")
	_art_mat.set_shader_parameter("has_art", tex != null)
	if tex:
		_art_mat.set_shader_parameter("art", tex)
		_art_mat.set_shader_parameter("art_size", Vector2(tex.get_size()))
	var center := size * 0.5 - _card.size * 0.5 - Vector2(0, 40)
	if from_card:
		_pos.snap(from_card.global_position - global_position + (from_card.size - _card.size) * 0.5)
	else:
		_pos.snap(center + Vector2(0, 120))
	_pos.target = center
	_open.snap(0.0)
	_open.target = 1.0
	_zoom.snap(1.0)
	_zoom.target = 1.0
	shell.wallpaper.dim.target = 1.0
	Nav.push(self)

func game_started() -> void:
	if not _active:
		return
	_status.text = "Enjoy"
	_zoom.target = 2.4
	_open.target = 0.0

func hide_now() -> void:
	if _active:
		Nav.pop(self)
	_active = false
	visible = false
	shell.wallpaper.dim.target = 0.0

func nav_action(a: StringName) -> bool:
	if a == &"back" and _t > 1.0:
		hide_now()
		Sfx.back()
	return true

func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	var o := _open.step(dt)
	var z := _zoom.step(dt)
	var p := _pos.step(dt)
	modulate.a = clampf(o * 1.3, 0.0, 1.0)
	_card.position = p
	_card.pivot_offset = _card.size * 0.5
	var breathe := 1.0 + sin(_t * 2.4) * 0.012
	_card.scale = Vector2.ONE * z * breathe * lerpf(0.9, 1.0, clampf(o, 0.0, 1.0))
	_ring.position = _card.position + _card.size * 0.5
	_ring.queue_redraw()
	_title.size = Vector2(size.x, 44)
	_title.position = Vector2(0, _card.position.y + _card.size.y + 46)
	_status.size = Vector2(size.x, 30)
	_status.position = Vector2(0, _title.position.y + 52)
	if _t > 8.0 and _status.text == "Starting…":
		_status.text = "Steam is getting it ready…"
	if _active and _t > 40.0 and not Session.is_playing():
		hide_now()
		shell.toast("%s didn't start. Check Steam for a message." % game.name, "info", Tokens.WARN)
	if not _active and o < 0.02:
		visible = false
	if _active and _open.target == 0.0 and o < 0.02:
		hide_now()

func _draw_ring() -> void:
	var r := 300.0
	var a0 := _t * 3.2
	var o := clampf(_open.value, 0.0, 1.0)
	for k in 3:
		var w := 3.0 - k
		var start := a0 + k * 2.1
		var len := 0.9 + 0.5 * sin(_t * 1.7 + k)
		_ring.draw_arc(Vector2.ZERO, r - k * 14.0, start, start + len, 64, Color(Tokens.GOLD, 0.65 * o / (k + 1)), w + 1.0, true)
