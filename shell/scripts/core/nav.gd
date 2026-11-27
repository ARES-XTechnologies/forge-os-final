extends Node
## Controller-first input router.
## Turns D-pad, sticks, buttons and keyboard into a small set of actions with
## accelerating auto-repeat, then hands them to whichever layer is on top.
##
## Actions: up down left right accept back alt menu tab_prev tab_next page_prev page_next guide start
## A handler is any Node with `func nav_action(action: StringName) -> bool`.

signal action_fired(action: StringName)
signal device_changed()

var _stack: Array[Node] = []
var _held := {}          # dir action -> {t, next}
var _stick_dir := Vector2i.ZERO
var enabled := true
## While a game is running the controller belongs to the game: only the Guide button,
## its combos (Guide+X screenshot, Guide+Y clip), Share and View+Menu reach FORGE.
var passthrough := false
var last_device := "keyboard"
var _guide_down := false
var _combo_used := false
var _view_down := false
var _menu_down := false
const PASS := [&"guide", &"screenshot", &"clip"]

const DIRS := [&"up", &"down", &"left", &"right"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_map(&"up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP])
	_map(&"down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN])
	_map(&"left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT])
	_map(&"right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT])
	_map(&"accept", [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER], [JOY_BUTTON_A])
	_map(&"back", [KEY_ESCAPE, KEY_BACKSPACE], [JOY_BUTTON_B])
	_map(&"alt", [KEY_F, KEY_X], [JOY_BUTTON_X])
	_map(&"menu", [KEY_TAB, KEY_Y], [JOY_BUTTON_Y])
	_map(&"tab_prev", [KEY_Q], [JOY_BUTTON_LEFT_SHOULDER])
	_map(&"tab_next", [KEY_E], [JOY_BUTTON_RIGHT_SHOULDER])
	_map(&"page_prev", [KEY_PAGEUP, KEY_Z], [])
	_map(&"page_next", [KEY_PAGEDOWN, KEY_C], [])
	_map(&"guide", [KEY_HOME, KEY_G], [JOY_BUTTON_GUIDE])
	_map(&"view", [], [JOY_BUTTON_BACK])
	_map(&"start", [KEY_M], [JOY_BUTTON_START])
	_map(&"screenshot", [KEY_F12, KEY_PRINT], [JOY_BUTTON_MISC1])
	_map(&"clip", [KEY_F11], [])
	Input.joy_connection_changed.connect(func(_id, _c): device_changed.emit())

func _map(action: StringName, keys: Array, buttons: Array) -> void:
	var n := "forge_" + String(action)
	if not InputMap.has_action(n):
		InputMap.add_action(n, 0.5)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(n, e)
	for b in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		j.device = -1
		InputMap.action_add_event(n, j)

# ---------------------------------------------------------------- stack
func push(handler: Node) -> void:
	_stack.erase(handler)
	_stack.append(handler)
	_held.clear()

func pop(handler: Node) -> void:
	_stack.erase(handler)
	_held.clear()

func top() -> Node:
	while not _stack.is_empty() and not is_instance_valid(_stack.back()):
		_stack.pop_back()
	return null if _stack.is_empty() else _stack.back()

func is_top(handler: Node) -> bool:
	return top() == handler

# ---------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		last_device = "pad"
	elif event is InputEventKey:
		last_device = "keyboard"
	if not enabled:
		return
	# Real keyboard typing goes straight into the on-screen keyboard.
	if event is InputEventKey and event.pressed:
		var t := top()
		if t != null and t.has_method("type_key") and t.type_key(event):
			get_viewport().set_input_as_handled()
			return
	if _handle_combos(event):
		get_viewport().set_input_as_handled()
		return
	if passthrough:
		for a in [&"screenshot", &"clip"]:
			if event.is_action_pressed("forge_" + String(a), false, true):
				_fire(a)
		return
	# Triggers as page jumps
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_TRIGGER_LEFT and event.axis_value > 0.6 and not _held.has(&"trig_l"):
			_held[&"trig_l"] = {}
			_fire(&"page_prev")
		elif event.axis == JOY_AXIS_TRIGGER_LEFT and event.axis_value < 0.3:
			_held.erase(&"trig_l")
		if event.axis == JOY_AXIS_TRIGGER_RIGHT and event.axis_value > 0.6 and not _held.has(&"trig_r"):
			_held[&"trig_r"] = {}
			_fire(&"page_next")
		elif event.axis == JOY_AXIS_TRIGGER_RIGHT and event.axis_value < 0.3:
			_held.erase(&"trig_r")
		return
	for a in [&"up", &"down", &"left", &"right", &"accept", &"back", &"alt", &"menu", &"tab_prev", &"tab_next", &"page_prev", &"page_next", &"start", &"screenshot", &"clip"]:
		var n := "forge_" + String(a)
		if event.is_action_pressed(n, false, true):
			var act: StringName = a
			if Config.get_b("input.swap_ab") and event is InputEventJoypadButton:
				if a == &"accept": act = &"back"
				elif a == &"back": act = &"accept"
			if act in DIRS:
				_held[act] = {"t": 0.0, "next": Config.get_f("input.repeat_delay")}
			_fire(act)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_released(n, true):
			_held.erase(a)

## Guide fires on release so Guide+X / Guide+Y can be combos. View+Menu also opens it.
func _handle_combos(event: InputEvent) -> bool:
	if event.is_action_pressed("forge_guide", false, true):
		_guide_down = true
		_combo_used = false
		return true
	if event.is_action_released("forge_guide", true):
		var was := _guide_down
		_guide_down = false
		if was and not _combo_used:
			_fire(&"guide")
		return true
	if _guide_down and event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_X:
			_combo_used = true
			_fire(&"screenshot")
			return true
		if event.button_index == JOY_BUTTON_Y:
			_combo_used = true
			_fire(&"clip")
			return true
	if event.is_action("forge_view", true):
		_view_down = event.is_pressed()
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START:
		_menu_down = event.pressed
	if _view_down and _menu_down and event.is_pressed():
		_view_down = false
		_menu_down = false
		_fire(&"guide")
		return true
	return false

func _process(dt: float) -> void:
	if not enabled or passthrough:
		return
	# Left stick → directions with the same repeat curve as the D-pad.
	var v := Vector2.ZERO
	for id in Input.get_connected_joypads():
		var s := Vector2(Input.get_joy_axis(id, JOY_AXIS_LEFT_X), Input.get_joy_axis(id, JOY_AXIS_LEFT_Y))
		if s.length() > v.length():
			v = s
	var dz := Config.get_f("input.deadzone")
	var d := Vector2i.ZERO
	if v.length() > dz:
		if absf(v.x) > absf(v.y) * 1.15:
			d = Vector2i(signi(int(signf(v.x))), 0)
		elif absf(v.y) > absf(v.x) * 1.15:
			d = Vector2i(0, signi(int(signf(v.y))))
	if d != _stick_dir:
		for a in DIRS:
			if _held.has(a) and _held[a].get("stick", false):
				_held.erase(a)
		_stick_dir = d
		if d != Vector2i.ZERO:
			var act := _dir_action(d)
			_held[act] = {"t": 0.0, "next": Config.get_f("input.repeat_delay"), "stick": true}
			last_device = "pad"
			_fire(act)
	# Accelerating auto-repeat: the longer you hold, the faster it flies.
	for a in _held.keys():
		if not (a in DIRS):
			continue
		var h: Dictionary = _held[a]
		h.t += dt
		if h.t >= h.next:
			var rate := Config.get_f("input.repeat_rate")
			var accel := clampf(1.0 - (h.t - 0.6) * 0.35, 0.45, 1.0)
			h.next = h.t + rate * accel
			_fire(a, true)

func _dir_action(d: Vector2i) -> StringName:
	if d.x < 0: return &"left"
	if d.x > 0: return &"right"
	if d.y < 0: return &"up"
	return &"down"

var repeating := false

func _fire(action: StringName, is_repeat := false) -> void:
	repeating = is_repeat
	action_fired.emit(action)
	if action == &"screenshot":
		Session.screenshot()
		return
	if action == &"clip":
		Session.save_clip()
		return
	if passthrough and not (action in PASS):
		return
	var h := top()
	if h and h.has_method("nav_action"):
		h.nav_action(action)
	repeating = false

static func dir_of(action: StringName) -> Vector2i:
	match action:
		&"up": return Vector2i(0, -1)
		&"down": return Vector2i(0, 1)
		&"left": return Vector2i(-1, 0)
		&"right": return Vector2i(1, 0)
	return Vector2i.ZERO
