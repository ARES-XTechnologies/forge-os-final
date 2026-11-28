class_name Dialog
extends Overlay
## Centred confirmation dialog. options: [["Label", "icon"], ...]; callback(index).

var title := ""
var body := ""
var options: Array = []
var callback: Callable
var ingame := false
var _list: FocusList

func build() -> void:
	from_offset = Vector2(0, 60)
	open_scale = 0.86
	var c := GlassPanel.new()
	c.name = "content"
	c.radius = 40
	c.shadow = 1.0
	c.body_dim = 0.9
	c.ingame = ingame
	add_child(c)
	var t := Tokens.label(title, 34, 700)
	t.position = Vector2(48, 44)
	c.add_child(t)
	var b := Tokens.label(body, 21, 400, Tokens.INK_DIM)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.position = Vector2(48, 98)
	Tokens.fit(b, Vector2(640, 60))
	c.add_child(b)
	var btns := []
	var x := 48.0
	for i in options.size():
		var o: Array = options[i]
		var btn := PillButton.make(o[0], o[1] if o.size() > 1 else "", 64, 22)
		btn.primary = i == 0
		btn.min_width = 170
		var idx := i
		btn.pressed.connect(func():
			close()
			if callback.is_valid():
				callback.call(idx))
		c.add_child(btn)
		btn.position = Vector2(x, 190)
		x += btn.size.x + 16.0
		btns.append(btn)
	c.size = Vector2(maxf(736.0, x + 32.0), 300)
	_list = FocusList.new(btns, true)
	_list.focus(0)

func nav_action(a: StringName) -> bool:
	if _list.handle(a):
		return true
	match a:
		&"accept": _list.press()
		&"back":
			close()
			if callback.is_valid():
				callback.call(-1)
	return true
