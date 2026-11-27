class_name HintBar
extends Control
## Button hints at the bottom of the screen: (A) Play  (X) Details ...
## Glyphs match the input you used last (controller or keyboard).

const GLYPH_COLORS := {"A": Color("6fe39a"), "B": Color("ff7a8a"), "X": Color("6fb8ff"), "Y": Color("ffd36b"),
	"LB": Color("c9d0ff"), "RB": Color("c9d0ff"), "LT": Color("c9d0ff"), "RT": Color("c9d0ff"), "☰": Color("c9d0ff"), "⌂": Color("c9d0ff")}
const KEYS := {"◀▶": "← →", "A": "Enter", "B": "Esc", "X": "F", "Y": "Tab", "LB": "Q", "RB": "E", "LT": "PgUp", "RT": "PgDn", "☰": "M", "⌂": "G"}

var _items: Array = []
var _alpha: Spring

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alpha = Spring.preset(0.0, &"smooth")
	Nav.action_fired.connect(func(_a): queue_redraw())

func set_hints(items: Array) -> void:
	# items: [["A", "Play"], ["X", "Details"]]
	_items = items
	_alpha.snap(0.0)
	_alpha.target = 1.0
	queue_redraw()

func _process(dt: float) -> void:
	var a := _alpha.step(dt)
	modulate.a = clampf(a, 0.0, 1.0)

func _draw() -> void:
	var font := Tokens.font(500)
	var fs := 19
	var x := 0.0
	var pad := Nav.last_device == "pad"
	for it in _items:
		var label: String = it[1]
		for g in String(it[0]).split("+"):
			var gw := 34.0
			var glyph_text: String = g if pad else KEYS.get(g, g)
			var gtw := font.get_string_size(glyph_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			if not pad or g.length() > 1:
				gw = maxf(34.0, gtw + 18.0)
			var r := Rect2(Vector2(x, 0), Vector2(gw, 34))
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(17)
			sb.anti_aliasing = true
			sb.bg_color = Color(1, 1, 1, 0.08)
			sb.border_color = GLYPH_COLORS.get(g, Tokens.INK) if pad else Color(1, 1, 1, 0.35)
			sb.set_border_width_all(2)
			draw_style_box(sb, r)
			draw_string(font, Vector2(x + (gw - gtw) * 0.5, 23), glyph_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, sb.border_color.lightened(0.2) if pad else Tokens.INK)
			x += gw + 6.0
		x += 4.0
		draw_string(font, Vector2(x, 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tokens.INK_DIM)
		x += font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 30.0
	custom_minimum_size = Vector2(x, 34)
	size = custom_minimum_size
