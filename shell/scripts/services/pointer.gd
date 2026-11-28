extends Node
## Controller as mouse and keyboard, for apps made for a mouse (Heroic, Firefox, and anything
## you add with Type: App). Switches on by itself while such an app is in front, and off when
## you return to FORGE or open the Guide.
##
##   Left stick      move the pointer (push further = faster)
##   Right stick     scroll (up/down and sideways)
##   A               click (hold to drag)
##   Y               right-click
##   R3              middle-click
##   B               Back (like a browser's back button)
##   X               on-screen keyboard: type, then Done to send the text to the app
##   D-pad           arrow keys
##   Start (Menu)    Enter
##   Guide           FORGE's in-game menu, as with games
##
## The pointer itself is a virtual mouse + keyboard made by /usr/lib/forge/forge-pointer
## (the same way Steam Input does it), so every app sees a real mouse and keyboard.

const HELPER := "/usr/lib/forge/forge-pointer"
const DEADZONE := 0.14
const SPEED := 1500.0          # pixels per second at full tilt
const SCROLL := 14.0           # notches per second at full tilt
const REPEAT_DELAY := 0.38
const REPEAT_RATE := 0.06

var active := false
var _pipe: FileAccess = null
var _pid := 0
var _acc := Vector2.ZERO
var _scroll := Vector2.ZERO
var _down := {}                # joy button -> pressed last frame
var _rep := {}                 # d-pad button -> time until next repeat
var _kb_open := false
var _warned := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Session.ended.connect(func(_g): _set_active(false))

func _exit_tree() -> void:
	_stop_helper()

func _wanted() -> bool:
	return Session.is_playing() and bool(Session.current.get("pointer", false)) \
		and Nav.passthrough and not _kb_open

func _process(dt: float) -> void:
	var want := _wanted()
	if want != active:
		_set_active(want)
	if not active:
		return
	# FORGE idles at a few frames a second while something runs; the pointer needs smooth input.
	Engine.max_fps = 60
	OS.low_processor_usage_mode = false
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	var dev: int = pads[0]

	# --- pointer
	var ls := _stick(dev, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	_acc += ls * SPEED * dt
	var mx := int(_acc.x)
	var my := int(_acc.y)
	if mx != 0 or my != 0:
		_send("m %d %d" % [mx, my])
		_acc -= Vector2(mx, my)

	# --- scrolling
	var rs := _stick(dev, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	_scroll += rs * SCROLL * dt
	var sv := int(_scroll.y)
	if sv != 0:
		_send("s %d" % sv)
		_scroll.y -= sv
	var sh := int(_scroll.x)
	if sh != 0:
		_send("h %d" % sh)
		_scroll.x -= sh

	# --- buttons
	_hold(dev, JOY_BUTTON_A, "l")
	_hold(dev, JOY_BUTTON_Y, "r")
	_hold(dev, JOY_BUTTON_RIGHT_STICK, "m")
	if _pressed(dev, JOY_BUTTON_B):
		_send("a left")
	if _pressed(dev, JOY_BUTTON_START):
		_send("k enter")
	if _pressed(dev, JOY_BUTTON_X):
		_open_keyboard()
	for pair in [[JOY_BUTTON_DPAD_UP, "up"], [JOY_BUTTON_DPAD_DOWN, "down"], [JOY_BUTTON_DPAD_LEFT, "left"], [JOY_BUTTON_DPAD_RIGHT, "right"]]:
		_repeat(dev, pair[0], pair[1], dt)

func _stick(dev: int, ax: JoyAxis, ay: JoyAxis) -> Vector2:
	var v := Vector2(Input.get_joy_axis(dev, ax), Input.get_joy_axis(dev, ay))
	var l := v.length()
	if l < DEADZONE:
		return Vector2.ZERO
	var k := pow(clampf((l - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0), 1.8)
	return v / l * k

func _pressed(dev: int, b: JoyButton) -> bool:
	var now := Input.is_joy_button_pressed(dev, b)
	var was: bool = _down.get(b, false)
	_down[b] = now
	return now and not was

func _hold(dev: int, b: JoyButton, which: String) -> void:
	var now := Input.is_joy_button_pressed(dev, b)
	var was: bool = _down.get(b, false)
	_down[b] = now
	if now and not was:
		_send("d " + which)
	elif was and not now:
		_send("u " + which)

func _repeat(dev: int, b: JoyButton, key: String, dt: float) -> void:
	if not Input.is_joy_button_pressed(dev, b):
		_rep.erase(b)
		return
	if not _rep.has(b):
		_rep[b] = REPEAT_DELAY
		_send("k " + key)
		return
	_rep[b] -= dt
	if _rep[b] <= 0.0:
		_rep[b] = REPEAT_RATE
		_send("k " + key)

# ------------------------------------------------------------------ on-screen keyboard
func _open_keyboard() -> void:
	var main := get_tree().current_scene
	if main == null or not ("shell" in main) or main.shell == null:
		return
	_kb_open = true
	_release_all()
	main.call("set_menu_awake", true)
	var kb: Node = main.shell.open_keyboard("Type into the app", "", false, func(text: String):
		if text != "":
			_send("t " + text.replace("\n", " ")))
	kb.tree_exited.connect(func():
		_kb_open = false
		var m := get_tree().current_scene if is_inside_tree() else null
		if m and Session.is_playing():
			m.call("set_menu_awake", false))

# ------------------------------------------------------------------ helper process
func _set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	_acc = Vector2.ZERO
	_scroll = Vector2.ZERO
	_rep.clear()
	if on:
		if not _start_helper():
			active = false
			return
		# The first 3 times, show which button does what (always in the Guide menu too).
		var shown := Config.get_i("pointer.guide_shown")
		if shown < 3:
			Config.set_v("pointer.guide_shown", shown + 1)
			Shellbus.notify({"title": "Controller mouse is on",
				"body": "Left stick: pointer · A: click · Right stick: scroll · X: keyboard · B: back · Start: Enter",
				"icon": "controller", "color": Tokens.ACCENT, "duration": 9.0})
		# Buttons already held when switching on don't count as presses.
		var pads := Input.get_connected_joypads()
		if not pads.is_empty():
			for b in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START, JOY_BUTTON_RIGHT_STICK]:
				_down[b] = Input.is_joy_button_pressed(pads[0], b)
	else:
		_release_all()

func _release_all() -> void:
	for b in [JOY_BUTTON_A, JOY_BUTTON_Y, JOY_BUTTON_RIGHT_STICK]:
		if _down.get(b, false):
			_send("u " + {JOY_BUTTON_A: "l", JOY_BUTTON_Y: "r", JOY_BUTTON_RIGHT_STICK: "m"}[b])
		_down[b] = false

func _start_helper() -> bool:
	if _pipe != null and _pid > 0 and OS.is_process_running(_pid):
		return true
	if not FileAccess.file_exists(HELPER):
		return false
	var r := OS.execute_with_pipe(HELPER, PackedStringArray())
	if r.is_empty() or r.get("stdio") == null:
		if not _warned:
			_warned = true
			Shellbus.notify({"title": "Controller mouse unavailable", "body": "Use a mouse and keyboard for this app.", "icon": "info", "color": Tokens.WARN})
		return false
	_pipe = r["stdio"]
	_pid = int(r.get("pid", 0))
	return true

func _stop_helper() -> void:
	if _pipe != null:
		_send("q")
		_pipe.close()
		_pipe = null
	_pid = 0

func _send(line: String) -> void:
	if _pipe == null:
		return
	_pipe.store_string(line + "\n")
	_pipe.flush()
