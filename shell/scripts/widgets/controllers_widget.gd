class_name ControllersWidget
extends GlassWidget

var _bat := {}

func setup() -> void:
	size = Vector2(252, 150)

func tick_rate() -> float: return 5.0

func update() -> void:
	_bat.clear()
	var d := DirAccess.open("/sys/class/power_supply")
	if d:
		for e in d.get_directories():
			var base := "/sys/class/power_supply/" + e
			if Sys.read_text(base + "/scope").strip_edges() == "Device":
				var cap := Sys.read_text(base + "/capacity").strip_edges()
				if cap.is_valid_int():
					_bat[e] = int(cap)

func _paint() -> void:
	caption("Controllers")
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		text("None connected", Vector2(22, 90), 20, 500, Tokens.INK_DIM)
		return
	var y := 72.0
	var bats := _bat.values()
	for i in mini(pads.size(), 3):
		var name := Input.get_joy_name(pads[i])
		text(name.substr(0, 18), Vector2(22, y), 17, 600)
		if i < bats.size():
			text("%d%%" % bats[i], Vector2(170, y), 16, 600, Tokens.OK if bats[i] > 25 else Tokens.BAD, HORIZONTAL_ALIGNMENT_RIGHT, 60)
		y += 28
