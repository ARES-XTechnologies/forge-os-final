class_name CalendarWidget
extends GlassWidget

func setup() -> void:
	size = Vector2(252, 252)

func tick_rate() -> float: return 30.0

func _paint() -> void:
	var t := Time.get_datetime_dict_from_system()
	var months := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	text(months[t.month - 1].to_upper(), Vector2(22, 34), 13, 700, Tokens.INK_FAINT)
	var first := Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict({"year": t.year, "month": t.month, "day": 1, "hour": 12, "minute": 0, "second": 0}))
	var dim: int = [31, 29 if (t.year % 4 == 0 and (t.year % 100 != 0 or t.year % 400 == 0)) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][t.month - 1]
	var labels := ["M", "T", "W", "T", "F", "S", "S"]
	var cw := (size.x - 36.0) / 7.0
	for i in 7:
		text(labels[i], Vector2(18 + i * cw, 64), 13, 700, Tokens.INK_FAINT, HORIZONTAL_ALIGNMENT_CENTER, cw)
	var start := (int(first.weekday) + 6) % 7
	for d in dim:
		var idx: int = start + d
		var x: float = 18 + (idx % 7) * cw
		var y: float = 92 + (idx / 7) * 30
		if d + 1 == t.day:
			canvas.draw_circle(Vector2(x + cw * 0.5, y - 6), 13.0, Tokens.ACCENT)
		text(str(d + 1), Vector2(x, y), 15, 600 if d + 1 == t.day else 400, Color("0b1020") if d + 1 == t.day else Tokens.INK_DIM, HORIZONTAL_ALIGNMENT_CENTER, cw)
