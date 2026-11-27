class_name Screen
extends Control
## Base for full screens (Home, Library, Media, Settings).
## The shell slides screens in and out on springs; screens handle their own focus.

var shell: Node           # the Shell
var _x: Spring
var _a: Spring
var _s: Spring
var active := false
var _out := 1.0           # leaving: a quick linear fade, so the old screen never lingers

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ensure_springs() -> void:
	if _x == null:
		_x = Spring.preset(0.0, &"snappy")
		_a = Spring.preset(0.0, &"smooth")
		_s = Spring.preset(1.0, &"snappy")

## dir: +1 when arriving from the right, -1 from the left, 0 = fade/zoom.
func enter(dir: int) -> void:
	_ensure_springs()
	active = true
	visible = true
	_x.snap(dir * 180.0)
	_x.target = 0.0
	_a.snap(0.0)
	_a.target = 1.0
	_s.snap(0.97 if dir == 0 else 1.0)
	_s.target = 1.0
	_out = 1.0
	on_enter(dir)

func leave(dir: int) -> void:
	_ensure_springs()
	active = false
	_x.target = -dir * 140.0
	_a.target = 0.0
	_s.target = 0.985
	on_leave()

func _process(dt: float) -> void:
	if _x == null:
		return
	var x := _x.step(dt)
	var a := _a.step(dt)
	var s := _s.step(dt)
	position.x = x
	if not active:
		_out = maxf(_out - dt / 0.18, 0.0)
	modulate.a = clampf(minf(a, _out), 0.0, 1.0)
	pivot_offset = size * 0.5
	scale = Vector2(s, s)
	if not active and (a < 0.01 or _out <= 0.0) and visible:
		visible = false
	if visible:
		tick(dt)

# ---- overridables
func on_enter(_dir: int) -> void: pass
func on_leave() -> void: pass
func tick(_dt: float) -> void: pass
func nav_action(_a: StringName) -> bool: return false
func hints() -> Array: return []
## Called when a game starts/stops so screens can pause heavy work.
func on_game_mode(_playing: bool) -> void: pass
