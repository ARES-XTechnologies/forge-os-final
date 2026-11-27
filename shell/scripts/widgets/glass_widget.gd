class_name GlassWidget
extends GlassPanel
## Base widget: a glass tile with a drawing canvas and a pop-in animation.

var span := 1                    # 1 = one column, 2 = both columns
var home := Vector2.ZERO
var dock_scale := 1.0
var canvas: Control
var _pop: Spring
var _delay := 0.0
var _t := 0.0
var _tick := 0.0

func _init() -> void:
	super._init()
	radius = 30
	bevel = 18
	shadow = 0.6
	_pop = Spring.preset(1.0, &"jelly")
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_paint)
	add_child(canvas)
	setup()

func pop_in(delay: float) -> void:
	_delay = delay
	_pop.snap(1.0)
	modulate.a = 0.0

func _process(dt: float) -> void:
	_t += dt
	if _delay > 0.0:
		_delay -= dt
		if _delay <= 0.0:
			_pop.target = 0.0
		return
	if _pop.target == 1.0 and _pop.value == 1.0:
		_pop.target = 0.0
	var p := _pop.step(dt)
	pivot_offset = Vector2.ZERO
	var s := (1.0 - p * 0.12) * dock_scale
	scale = Vector2(s, s)
	position = home + Vector2(size.x * dock_scale * p * 0.06, p * 40.0 + size.y * dock_scale * p * 0.06)
	modulate.a = clampf(1.0 - p, 0.0, 1.0)
	canvas.size = size
	_tick += dt
	if _tick >= tick_rate():
		_tick = 0.0
		update()
	canvas.queue_redraw()

# overridables
func setup() -> void: pass
func update() -> void: pass
func tick_rate() -> float: return 1.0
func _paint() -> void: pass

# helpers
func text(s: String, pos: Vector2, fs: int, w := 500, col := Tokens.INK, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	canvas.draw_string(Tokens.font(w), pos, s, align, width, fs, col)

func caption(s: String) -> void:
	text(s.to_upper(), Vector2(22, 34), 13, 700, Tokens.INK_FAINT)

func ring(center: Vector2, r: float, v: float, col: Color, w := 9.0) -> void:
	canvas.draw_arc(center, r, 0, TAU, 64, Color(1, 1, 1, 0.1), w, true)
	if v > 0.002:
		canvas.draw_arc(center, r, -PI / 2, -PI / 2 + TAU * clampf(v, 0, 1), 64, col, w, true)
