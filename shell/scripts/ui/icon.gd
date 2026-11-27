class_name Icon
extends Control
## Vector icons drawn in code: crisp at any size, tint-able, zero assets.
## Stroke style: rounded 2px-equivalent lines on a 24-unit grid.

var icon := "dot":
	set(v): icon = v; queue_redraw()
var color := Tokens.INK:
	set(v): color = v; queue_redraw()
var stroke := 2.0:
	set(v): stroke = v; queue_redraw()
var value := 1.0:            # used by wifi strength, volume, battery
	set(v): value = v; queue_redraw()

static func make(name: String, px: float = 28.0, col: Color = Tokens.INK) -> Icon:
	var i := Icon.new()
	i.icon = name
	i.color = col
	i.custom_minimum_size = Vector2(px, px)
	i.size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i

func _s() -> float:
	return minf(size.x, size.y) / 24.0

func _p(x: float, y: float) -> Vector2:
	var s := _s()
	var off := (size - Vector2(24, 24) * s) * 0.5
	return off + Vector2(x, y) * s

func _line(pts: Array, closed := false, w := -1.0) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(_p(p.x, p.y))
	if closed:
		arr.append(arr[0])
	draw_polyline(arr, color, (stroke if w < 0 else w) * _s(), true)

func _arc(cx: float, cy: float, r: float, a0: float, a1: float, w := -1.0, col := Color(0, 0, 0, 0)) -> void:
	draw_arc(_p(cx, cy), r * _s(), a0, a1, 48, color if col.a == 0 else col, (stroke if w < 0 else w) * _s(), true)

func _circle(cx: float, cy: float, r: float, filled := false) -> void:
	if filled:
		draw_circle(_p(cx, cy), r * _s(), color)
	else:
		_arc(cx, cy, r, 0, TAU)

func _rrect(x: float, y: float, w: float, h: float, r: float, filled := false) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(r * _s()))
	sb.anti_aliasing = true
	if filled:
		sb.bg_color = color
	else:
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(maxi(1, int(round(stroke * _s()))))
		sb.border_color = color
	draw_style_box(sb, Rect2(_p(x, y), Vector2(w, h) * _s()))

func _draw() -> void:
	match icon:
		"home":
			_line([Vector2(4, 11), Vector2(12, 4), Vector2(20, 11)])
			_line([Vector2(6, 9.5), Vector2(6, 20), Vector2(18, 20), Vector2(18, 9.5)])
			_line([Vector2(10, 20), Vector2(10, 14), Vector2(14, 14), Vector2(14, 20)])
		"grid":
			for p in [Vector2(4, 4), Vector2(13.5, 4), Vector2(4, 13.5), Vector2(13.5, 13.5)]:
				_rrect(p.x, p.y, 6.5, 6.5, 2)
		"image":
			_rrect(3, 5, 18, 14, 3)
			_circle(8.5, 10, 1.6, true)
			_line([Vector2(4, 17), Vector2(9.5, 12.5), Vector2(13, 15.5), Vector2(16, 13), Vector2(20, 16.5)])
		"gear":
			_circle(12, 12, 3.2)
			for k in 8:
				var a := k * TAU / 8.0
				_line([Vector2(12, 12) + Vector2(cos(a), sin(a)) * 6.4, Vector2(12, 12) + Vector2(cos(a), sin(a)) * 8.6], false, 2.6)
			_circle(12, 12, 6.4)
		"search":
			_circle(10.5, 10.5, 6)
			_line([Vector2(15, 15), Vector2(20, 20)])
		"controller":
			_line([Vector2(7, 7), Vector2(17, 7), Vector2(20.5, 15.5), Vector2(19, 18.5), Vector2(16, 17.5), Vector2(14, 14.5), Vector2(10, 14.5), Vector2(8, 17.5), Vector2(5, 18.5), Vector2(3.5, 15.5)], true)
			_line([Vector2(7, 10.5), Vector2(10, 10.5)])
			_line([Vector2(8.5, 9), Vector2(8.5, 12)])
			_circle(15.5, 10, 0.9, true)
			_circle(17.3, 11.8, 0.9, true)
		"wifi":
			var lv := clampf(value, 0.0, 1.0)
			for k in 3:
				var on := lv >= (k + 1) / 3.0 - 0.01
				var c := color if on else Color(color, 0.28)
				_arc(12, 19, 4.0 + k * 4.5, -PI * 0.78, -PI * 0.22, -1, c)
			_circle(12, 19, 1.3, true)
		"wifi_off":
			_arc(12, 19, 13, -PI * 0.78, -PI * 0.22, -1, Color(color, 0.35))
			_line([Vector2(4, 4), Vector2(20, 20)])
		"ethernet":
			_rrect(5, 4, 14, 10, 2)
			_line([Vector2(12, 14), Vector2(12, 20)])
			_line([Vector2(6, 20), Vector2(18, 20)])
			for x in [8.5, 12.0, 15.5]:
				_line([Vector2(x, 7), Vector2(x, 10)], false, 1.6)
		"bluetooth":
			_line([Vector2(7, 7.5), Vector2(17, 16), Vector2(12, 20.5), Vector2(12, 3.5), Vector2(17, 8), Vector2(7, 16.5)])
		"battery":
			_rrect(3, 7.5, 16, 9, 2.5)
			_rrect(19.6, 10.5, 1.8, 3, 0.8, true)
			var w := 12.0 * clampf(value, 0.0, 1.0)
			if w > 0.5:
				_rrect(5, 9.5, w, 5, 1.2, true)
		"volume":
			_line([Vector2(4, 9.5), Vector2(8, 9.5), Vector2(13, 5), Vector2(13, 19), Vector2(8, 14.5), Vector2(4, 14.5)], true)
			if value > 0.01:
				_arc(13, 12, 4.5, -PI * 0.3, PI * 0.3)
			if value > 0.5:
				_arc(13, 12, 8, -PI * 0.3, PI * 0.3)
		"mute":
			_line([Vector2(4, 9.5), Vector2(8, 9.5), Vector2(13, 5), Vector2(13, 19), Vector2(8, 14.5), Vector2(4, 14.5)], true)
			_line([Vector2(16, 9.5), Vector2(21, 14.5)])
			_line([Vector2(21, 9.5), Vector2(16, 14.5)])
		"power":
			_arc(12, 13, 7.5, -PI * 0.28 - PI * 0.5 + PI, PI * 2.0 - PI * 0.22 - PI * 0.5)
			_line([Vector2(12, 3.5), Vector2(12, 11)])
		"restart":
			_arc(12, 12, 7.5, -PI * 0.35, PI * 1.45)
			_line([Vector2(17.5, 3.8), Vector2(18.3, 8.2), Vector2(13.9, 8.6)])
		"moon":
			_arc(12, 12, 8, PI * 0.55, PI * 2.25)
			_arc(15.5, 8.5, 6, PI * 0.62, PI * 1.62)
		"play":
			_line([Vector2(8, 5), Vector2(19, 12), Vector2(8, 19)], true)
		"star":
			var pts := []
			for k in 10:
				var a := -PI / 2 + k * PI / 5
				var r := 8.5 if k % 2 == 0 else 3.8
				pts.append(Vector2(12, 12.6) + Vector2(cos(a), sin(a)) * r)
			_line(pts, true)
		"star_filled":
			var pts2 := PackedVector2Array()
			for k in 10:
				var a := -PI / 2 + k * PI / 5
				var r := 8.5 if k % 2 == 0 else 3.8
				pts2.append(_p(12 + cos(a) * r, 12.6 + sin(a) * r))
			draw_colored_polygon(pts2, color)
		"trash":
			_line([Vector2(4, 7), Vector2(20, 7)])
			_line([Vector2(9, 7), Vector2(9.5, 4), Vector2(14.5, 4), Vector2(15, 7)])
			_line([Vector2(6, 7), Vector2(7.2, 20), Vector2(16.8, 20), Vector2(18, 7)])
		"info":
			_circle(12, 12, 8.5)
			_line([Vector2(12, 11), Vector2(12, 16.5)])
			_circle(12, 7.8, 1.1, true)
		"chart":
			_line([Vector2(4, 4), Vector2(4, 20), Vector2(20, 20)])
			_line([Vector2(7, 16), Vector2(11, 11), Vector2(14, 13.5), Vector2(19.5, 7)])
		"display":
			_rrect(3, 4.5, 18, 12, 2.5)
			_line([Vector2(9, 20), Vector2(15, 20)])
			_line([Vector2(12, 16.5), Vector2(12, 20)])
		"palette":
			_arc(12, 12, 8.5, PI * 0.2, PI * 2.0)
			_circle(8.5, 10, 1.3, true)
			_circle(12, 7.5, 1.3, true)
			_circle(15.5, 10, 1.3, true)
			_line([Vector2(18.8, 14.2), Vector2(14.5, 15.5), Vector2(14, 19)])
		"widgets":
			_rrect(3.5, 3.5, 7.5, 7.5, 2)
			_rrect(13, 3.5, 7.5, 7.5, 3.7)
			_rrect(3.5, 13, 17, 7.5, 2)
		"network":
			_circle(12, 12, 8.5)
			_line([Vector2(3.5, 12), Vector2(20.5, 12)])
			var e := PackedVector2Array()
			for k in 25:
				var a := -PI / 2 + k * PI / 24.0
				e.append(_p(12 + cos(a) * 3.8, 12 + sin(a) * 8.5))
			draw_polyline(e, color, stroke * _s(), true)
		"storage":
			_rrect(4, 5, 16, 6, 2)
			_rrect(4, 13, 16, 6, 2)
			_circle(16.5, 8, 0.9, true)
			_circle(16.5, 16, 0.9, true)
		"update":
			_line([Vector2(12, 4), Vector2(12, 15)])
			_line([Vector2(7.5, 10.5), Vector2(12, 15), Vector2(16.5, 10.5)])
			_line([Vector2(5, 19.5), Vector2(19, 19.5)])
		"check":
			_line([Vector2(5, 12.5), Vector2(10, 17.5), Vector2(19.5, 7)])
		"chevron_right":
			_line([Vector2(9.5, 6), Vector2(15.5, 12), Vector2(9.5, 18)])
		"chevron_left":
			_line([Vector2(14.5, 6), Vector2(8.5, 12), Vector2(14.5, 18)])
		"plus":
			_line([Vector2(12, 5), Vector2(12, 19)])
			_line([Vector2(5, 12), Vector2(19, 12)])
		"close":
			_line([Vector2(6, 6), Vector2(18, 18)])
			_line([Vector2(18, 6), Vector2(6, 18)])
		"keyboard":
			_rrect(2.5, 6, 19, 12, 2.5)
			for r in 2:
				for k in 5:
					_circle(6 + k * 3, 9.5 + r * 3, 0.75, true)
			_line([Vector2(8, 15.5), Vector2(16, 15.5)], false, 1.6)
		"clock":
			_circle(12, 12, 8.5)
			_line([Vector2(12, 7), Vector2(12, 12), Vector2(15.5, 14)])
		"cpu":
			_rrect(6, 6, 12, 12, 2)
			_rrect(9.5, 9.5, 5, 5, 1)
			for k in 3:
				var o := 9.0 + k * 3.0
				_line([Vector2(o, 3), Vector2(o, 6)], false, 1.5)
				_line([Vector2(o, 18), Vector2(o, 21)], false, 1.5)
				_line([Vector2(3, o), Vector2(6, o)], false, 1.5)
				_line([Vector2(18, o), Vector2(21, o)], false, 1.5)
		"gpu":
			_rrect(2.5, 6, 19, 11, 2)
			_circle(9, 11.5, 3)
			_circle(16, 11.5, 2)
			_line([Vector2(5, 17), Vector2(5, 20)], false, 1.6)
		"sparkle":
			_line([Vector2(12, 3), Vector2(13.6, 10.4), Vector2(21, 12), Vector2(13.6, 13.6), Vector2(12, 21), Vector2(10.4, 13.6), Vector2(3, 12), Vector2(10.4, 10.4)], true)
		"filter":
			_line([Vector2(4, 6), Vector2(20, 6)])
			_line([Vector2(7, 12), Vector2(17, 12)])
			_line([Vector2(10, 18), Vector2(14, 18)])
		"sort":
			_line([Vector2(8, 4), Vector2(8, 20)])
			_line([Vector2(4.5, 7.5), Vector2(8, 4), Vector2(11.5, 7.5)])
			_line([Vector2(16, 4), Vector2(16, 20)])
			_line([Vector2(12.5, 16.5), Vector2(16, 20), Vector2(19.5, 16.5)])
		"eye_off":
			_arc(12, 18, 10, -PI * 0.85, -PI * 0.15)
			_arc(12, 6, 10, PI * 0.15, PI * 0.85)
			_line([Vector2(4, 4), Vector2(20, 20)])
		"wrench":
			_line([Vector2(14.5, 4.5), Vector2(19.5, 9.5)])
			_arc(16, 8, 4.5, PI * 0.6, PI * 1.9)
			_line([Vector2(13, 11), Vector2(5, 19)], false, 3.0)
		"steam":
			_circle(15.5, 9, 4)
			_circle(15.5, 9, 1.5, true)
			_circle(8, 16, 2.6)
			_line([Vector2(10.3, 14.7), Vector2(12.8, 11.6)])
		"thermo":
			_line([Vector2(12, 4), Vector2(12, 14)], false, 4.0)
			_circle(12, 17, 3.2, true)
		"ram":
			_rrect(3, 7, 18, 9, 1.5)
			for k in 4:
				_rrect(5.5 + k * 3.8, 9.5, 2.4, 4, 0.5, true)
			_line([Vector2(6, 16), Vector2(6, 19)], false, 1.4)
			_line([Vector2(18, 16), Vector2(18, 19)], false, 1.4)
		"calendar":
			_rrect(4, 5.5, 16, 14.5, 2.5)
			_line([Vector2(4, 10), Vector2(20, 10)])
			_line([Vector2(8.5, 3.5), Vector2(8.5, 7)])
			_line([Vector2(15.5, 3.5), Vector2(15.5, 7)])
		"timer":
			_circle(12, 13.5, 7.5)
			_line([Vector2(12, 13.5), Vector2(12, 9.5)])
			_line([Vector2(10, 3.5), Vector2(14, 3.5)])
		"gauge":
			_arc(12, 14, 8.5, PI, TAU)
			_line([Vector2(12, 14), Vector2(16.5, 8.5)])
			_circle(12, 14, 1.4, true)
		_:
			_circle(12, 12, 3, true)
