class_name WidgetDock
extends Control
## Glass widgets on the Home screen, packed into two columns on the right.
## They pop in one by one with a jelly bounce and only exist on Home.

var shell: Shell
var _widgets: Array[GlassWidget] = []
var _on_home := true
var _vis: Spring
const COL_W := 252.0
const GAP := 18.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vis = Spring.preset(0.0, &"smooth")
	Config.changed.connect(func(k): if k.begins_with("widgets.") or k.begins_with("appearance.clock"): refresh())

func set_screen(i: int) -> void:
	_on_home = i == 0
	_vis.target = 1.0 if (_on_home and Config.get_b("widgets.enabled")) else 0.0
	if _on_home:
		for k in _widgets.size():
			_widgets[k].pop_in(0.15 + k * 0.06)

func refresh() -> void:
	for w in _widgets:
		w.queue_free()
	_widgets.clear()
	if not Config.get_b("widgets.enabled"):
		_vis.target = 0.0
		return
	var order := [["clock", ClockWidget], ["date", DateWidget], ["system", SystemWidget], ["calendar", CalendarWidget],
		["session", SessionWidget], ["controllers", ControllersWidget], ["network", NetworkWidget],
		["storage", StorageWidget], ["recent", RecentWidget], ["playtime", PlaytimeWidget]]
	for o in order:
		if Config.get_b("widgets." + o[0]):
			var w: GlassWidget = o[1].new()
			add_child(w)
			_widgets.append(w)
	_pack()
	_vis.target = 1.0 if _on_home else 0.0
	for k in _widgets.size():
		_widgets[k].pop_in(0.1 + k * 0.06)

## Widgets live in the space above the game row. If they don't fit at full size the
## whole dock shrinks a little; anything that still doesn't fit is left out.
const TOP := 160.0
const BOTTOM := 585.0

func _pack() -> void:
	var s := 1.0
	while s > 0.66:
		if _layout_at(s, false):
			break
		s -= 0.04
	_layout_at(s, true)

func _layout_at(s: float, apply: bool) -> bool:
	var cw := COL_W * s
	var gap := GAP * s
	var x0 := size.x - Tokens.SAFE_X - (cw * 2.0 + gap)
	var cols := [TOP, TOP]
	var fits := true
	for w in _widgets:
		var h := w.size.y * s
		var pos := Vector2.ZERO
		if w.span == 2:
			var y := maxf(cols[0], cols[1])
			pos = Vector2(x0, y)
			cols[0] = y + h + gap
			cols[1] = cols[0]
		else:
			var c := 0 if cols[0] <= cols[1] else 1
			pos = Vector2(x0 + c * (cw + gap), cols[c])
			cols[c] += h + gap
		var ok: bool = pos.y + h <= BOTTOM
		fits = fits and ok
		if apply:
			w.home = pos
			w.dock_scale = s
			w.visible = ok
	return fits

func _process(dt: float) -> void:
	var v := _vis.step(dt)
	modulate.a = clampf(v, 0.0, 1.0)
	visible = v > 0.01
	if visible:
		_pack()
