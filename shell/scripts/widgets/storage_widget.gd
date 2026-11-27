class_name StorageWidget
extends GlassWidget

var _drives: Array = []
var _fill: Spring

func setup() -> void:
	size = Vector2(522, 130)
	span = 2
	_fill = Spring.preset(0.0, &"bouncy")

func tick_rate() -> float: return 20.0

func update() -> void:
	Sys.storage(func(list):
		_drives = list
		if not list.is_empty():
			_fill.target = float(list[0].used) / maxf(1.0, list[0].size))

func _paint() -> void:
	caption("Storage")
	if _drives.is_empty():
		return
	var d: Dictionary = _drives[0]
	var f := clampf(_fill.step(get_process_delta_time()), 0.0, 1.0)
	var r := Rect2(Vector2(22, 62), Vector2(size.x - 44, 14))
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(7)
	sb.anti_aliasing = true
	sb.bg_color = Color(1, 1, 1, 0.12)
	canvas.draw_style_box(sb, r)
	sb.bg_color = Tokens.ACCENT
	canvas.draw_style_box(sb, Rect2(r.position, Vector2(maxf(14.0, r.size.x * f), 14)))
	text("%s free of %s" % [SteamLib.fmt_size(d.free), SteamLib.fmt_size(d.size)], Vector2(22, 108), 18, 500, Tokens.INK_DIM)
	text("Games " + SteamLib.fmt_size(SteamLib.total_size()), Vector2(22, 108), 18, 600, Tokens.INK, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 44)
