class_name Overlay
extends Control
## Base for anything that sits above the screens (guide, keyboard, dialogs, game page).
## Opens on a bouncy spring, takes input focus, and gives it back when closed.

var shell: Shell
var closing := false
var _open: Spring
var from_offset := Vector2(0, 80)     # where it slides in from
var open_scale := 0.94
var covers_screen := false            # full-screen pages hide what's underneath

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_open = Spring.preset(0.0, &"bouncy")
	_open.target = 1.0
	build()
	Nav.push(self)
	if covers_screen and shell:
		shell.cover(true)
	Sfx.play("open")
	Sfx.haptic(0.2, 0.0, 30)
	if shell:
		shell.hint_bar.set_hints(hints())

func close() -> void:
	if closing:
		return
	closing = true
	_open.set_preset(&"stiff")
	_open.target = 0.0
	Nav.pop(self)
	if covers_screen and shell:
		shell.cover(false)
	Sfx.play("close")
	on_close()

func _process(dt: float) -> void:
	var o := _open.step(dt)
	animate(o, dt)
	if closing and o < 0.03:
		queue_free()
		if shell:
			shell.overlay_closed()

## Default animation: slide + scale + fade for the `content` node.
func animate(o: float, _dt: float) -> void:
	modulate.a = clampf(o * 1.4, 0.0, 1.0)
	var c := get_node_or_null("content") as Control
	if c:
		c.pivot_offset = c.size * 0.5
		c.position = _content_base() + from_offset * (1.0 - o)
		var s := lerpf(open_scale, 1.0, o)
		c.scale = Vector2(s, s)

func _content_base() -> Vector2:
	var c := get_node_or_null("content") as Control
	return (size - c.size) * 0.5 if c else Vector2.ZERO

# ---- overridables
func build() -> void: pass
func on_close() -> void: pass
func hints() -> Array: return [["A", "Select"], ["B", "Back"]]
func nav_action(a: StringName) -> bool:
	if a == &"back":
		close()
	return true
