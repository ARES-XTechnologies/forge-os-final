class_name SessionWidget
extends GlassWidget

func setup() -> void:
	size = Vector2(252, 150)

func _paint() -> void:
	caption("Console on for")
	var up := Sys.read_text("/proc/uptime").split(" ")
	var s := float(up[0]) if up.size() > 0 and up[0].is_valid_float() else Time.get_ticks_msec() / 1000.0
	var h := int(s) / 3600
	var m := (int(s) % 3600) / 60
	text("%dh %02dm" % [h, m] if h > 0 else "%d min" % m, Vector2(20, 100), 44, 300)
