class_name ClockWidget
extends GlassWidget
## Analog glass clock with smoothly sweeping hands.

func setup() -> void:
	size = Vector2(252, 252)

func tick_rate() -> float: return 0.0

func _paint() -> void:
	var c := size * 0.5
	var r := size.x * 0.40
	var col := Tokens.clock_color()
	for i in 60:
		var a := i * TAU / 60.0
		var long := i % 5 == 0
		var p0 := c + Vector2(sin(a), -cos(a)) * (r - (14.0 if long else 6.0))
		var p1 := c + Vector2(sin(a), -cos(a)) * r
		canvas.draw_line(p0, p1, Color(col, 0.9 if long else 0.28), 3.0 if long else 1.5, true)
	var t := Time.get_datetime_dict_from_system()
	var ms := Time.get_unix_time_from_system()
	var sec := fmod(ms, 60.0)
	var mins: float = float(t.minute) + sec / 60.0
	var hrs: float = fmod(float(t.hour), 12.0) + mins / 60.0
	_hand(c, hrs / 12.0 * TAU, r * 0.52, 6.0, col)
	_hand(c, mins / 60.0 * TAU, r * 0.78, 4.0, col)
	_hand(c, sec / 60.0 * TAU, r * 0.88, 2.0, Tokens.GOLD)
	canvas.draw_circle(c, 6.0, Tokens.GOLD)

func _hand(c: Vector2, a: float, len: float, w: float, col: Color) -> void:
	var d := Vector2(sin(a), -cos(a))
	canvas.draw_line(c - d * len * 0.12, c + d * len, col, w, true)
