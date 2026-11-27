class_name GameHint
extends Control
## The "Press ⌂ for the FORGE menu" card that slides down when a game starts,
## like the console guide hint on Xbox. Smoked glass, contour glow, then it floats away.

var _card: GlassPanel
var _y: Spring
var _life := 0.0
var _title: Label
var _sub: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_y = Spring.preset(-160.0, &"bouncy")
	_card = GlassPanel.new()
	_card.radius = 36
	_card.ingame = true
	_card.focus = 0.5
	_card.focus_color = Tokens.GOLD
	_card.size = Vector2(620, 92)
	add_child(_card)
	var orb := Control.new()
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.position = Vector2(22, 18)
	orb.size = Vector2(56, 56)
	orb.draw.connect(func():
		orb.draw_circle(Vector2(28, 28), 27.0, Color(1, 1, 1, 0.12))
		orb.draw_arc(Vector2(28, 28), 26.0, 0, TAU, 48, Tokens.GOLD, 2.5, true)
		var f := Tokens.font(700)
		var txt := "⌂" if Nav.last_device == "pad" else "G"
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		orb.draw_string(f, Vector2(28 - w * 0.5, 38), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Tokens.GOLD))
	_card.add_child(orb)
	_title = Tokens.label("Press the Guide button for the FORGE menu", 21, 700)
	_title.position = Vector2(96, 18)
	_card.add_child(_title)
	_sub = Tokens.label("Share or Guide + X for a screenshot  ·  Guide + Y saves a clip", 16, 500, Tokens.INK_DIM)
	_sub.position = Vector2(96, 50)
	_card.add_child(_sub)
	visible = false

func show_hint() -> void:
	if not Config.get_b("ingame.hint"):
		return
	visible = true
	_life = 5.0
	_y.snap(-160.0)
	_y.target = 40.0
	_card.shine = 0.0

func _process(dt: float) -> void:
	if not visible:
		return
	_life -= dt
	if _life <= 0.0:
		_y.target = -180.0
	var y := _y.step(dt)
	_card.position = Vector2((size.x - _card.size.x) * 0.5, y)
	if _card.shine >= 0.0:
		_card.shine += dt * 0.8
		if _card.shine > 1.3:
			_card.shine = -1.0
	if _life < -1.5:
		visible = false
