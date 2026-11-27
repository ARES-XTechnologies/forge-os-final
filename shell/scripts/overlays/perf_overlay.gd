class_name PerfOverlay
extends Control
## Small frame-time graph for the console UI itself (Settings › Performance).

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(300, 96)

func _process(_dt: float) -> void:
	visible = Config.get_b("perf.shell_overlay")
	if visible:
		position = Vector2(get_viewport_rect().size.x - Tokens.SAFE_X - size.x, 140)
		queue_redraw()

func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(16)
	sb.anti_aliasing = true
	sb.bg_color = Color(0, 0, 0, 0.55)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var ms := Metrics.frame_ms
	var pts := PackedVector2Array()
	var worst := 0.0
	for i in ms.size():
		worst = maxf(worst, ms[i])
		pts.append(Vector2(10 + i * (size.x - 20) / ms.size(), size.y - 10 - clampf(ms[i] / 33.3, 0, 1) * (size.y - 40)))
	var y60 := size.y - 10 - (16.67 / 33.3) * (size.y - 40)
	draw_dashed_line(Vector2(10, y60), Vector2(size.x - 10, y60), Color(1, 1, 1, 0.2), 1.0, 6.0)
	draw_polyline(pts, Tokens.OK if worst < 20.0 else Tokens.WARN, 1.5, true)
	draw_string(Tokens.font(600), Vector2(12, 24), "UI %.0f FPS · worst %.1f ms" % [Metrics.shell_fps(), worst], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Tokens.INK)
