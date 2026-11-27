class_name ProfilePicker
extends Overlay
## "Who's playing?" — big glass orbs, one per profile, that swell and glow on focus.

var startup := false
var _orbs: Array = []
var _focus := 0
var _row: Control
var _title: Label

func build() -> void:
	covers_screen = true
	from_offset = Vector2(0, 60)
	open_scale = 0.9
	var c := Control.new()
	c.name = "content"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(1600, 600)
	add_child(c)
	_title = Tokens.label("Who's playing?", 60, 700)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size = Vector2(1600, 80)
	c.add_child(_title)
	_row = Control.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.position = Vector2(0, 190)
	c.add_child(_row)
	_build_orbs()

func _build_orbs() -> void:
	for o in _orbs:
		o.node.queue_free()
	_orbs.clear()
	var entries: Array = Profiles.list.duplicate()
	if entries.size() < 8:
		entries.append({"id": "+", "name": "Add profile", "color": "c9d0ff"})
	var n := entries.size()
	var spacing := 250.0
	var x0 := (1600.0 - (n - 1) * spacing) * 0.5
	for i in n:
		var p: Dictionary = entries[i]
		var node := Control.new()
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.size = Vector2(200, 300)
		node.position = Vector2(x0 + i * spacing - 100, 0)
		node.pivot_offset = Vector2(100, 100)
		var glass := GlassPanel.new()
		glass.radius = 100
		glass.size = Vector2(200, 200)
		glass.focus_color = Color(str(p.color))
		glass.tint = Color(str(p.color))
		glass.tint_boost = 0.18
		node.add_child(glass)
		var label_txt := "+" if p.id == "+" else Profiles.initials(p)
		var ini := Tokens.label(label_txt, 72, 300, Color(str(p.color)).lightened(0.4))
		ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ini.size = Vector2(200, 200)
		node.add_child(ini)
		var nm := Tokens.label(str(p.name), 26, 600)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.size = Vector2(260, 34)
		nm.position = Vector2(-30, 226)
		node.add_child(nm)
		_row.add_child(node)
		_orbs.append({"node": node, "glass": glass, "id": p.id, "s": Spring.preset(1.0, &"bouncy"), "appear": Spring.preset(1.0, &"bouncy"), "delay": 0.15 + i * 0.07})
		if p.id == Profiles.active:
			_focus = i
	_apply()

func _apply() -> void:
	for i in _orbs.size():
		var o: Dictionary = _orbs[i]
		o.s.target = 1.14 if i == _focus else 0.94
		o.glass.focus = 1.0 if i == _focus else 0.0

func nav_action(a: StringName) -> bool:
	match a:
		&"left", &"right":
			var n := _focus + (1 if a == &"right" else -1)
			if n < 0 or n >= _orbs.size():
				Sfx.play("edge")
			else:
				_focus = n
				_orbs[_focus].s.kick(2.0)
				_apply()
				Sfx.focus_tick(_focus)
		&"accept":
			var id: String = _orbs[_focus].id
			_orbs[_focus].s.kick(-4.0)
			if id == "+":
				shell.open_keyboard("New profile name", "", false, func(t: String):
					var p := Profiles.add(t)
					Profiles.switch_to(p.id)
					close()
					shell.toast("Welcome, " + str(p.name), "sparkle", Tokens.GOLD))
			else:
				Sfx.play("launch")
				Profiles.switch_to(id)
				close()
				shell.toast("Hi, " + str(Profiles.current().name), "sparkle", Color(str(Profiles.current().color)))
		&"back":
			if not startup:
				close()
	return true

func hints() -> Array:
	return [["A", "Choose"]] if startup else [["A", "Choose"], ["B", "Back"]]

func animate(o: float, dt: float) -> void:
	super.animate(o, dt)
	for ob in _orbs:
		ob.delay -= dt
		if ob.delay <= 0.0:
			ob.appear.target = 0.0
		var ap: float = ob.appear.step(dt)
		var s: float = ob.s.step(dt)
		var node: Control = ob.node
		node.scale = Vector2(s, s)
		node.position.y = ap * 120.0
		node.modulate.a = clampf(1.0 - maxf(ap, 0.0) * 1.3, 0.0, 1.0)
