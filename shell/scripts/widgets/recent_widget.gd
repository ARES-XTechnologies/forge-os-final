class_name RecentWidget
extends GlassWidget

func setup() -> void:
	size = Vector2(252, 150)

func tick_rate() -> float: return 3.0

func _paint() -> void:
	caption("Last played")
	var r := SteamLib.recent(1)
	if r.is_empty() or r[0].last_played <= 0:
		text("Nothing yet", Vector2(22, 92), 20, 500, Tokens.INK_DIM)
		return
	var g: Dictionary = r[0]
	var logo := Art.get_tex(g.appid, "logo")
	if logo:
		var box := Rect2(Vector2(22, 50), Vector2(size.x - 44, 60))
		var s := minf(box.size.x / logo.get_width(), box.size.y / logo.get_height())
		var sz := Vector2(logo.get_size()) * s
		canvas.draw_texture_rect(logo, Rect2(box.position + Vector2(0, (box.size.y - sz.y) * 0.5), sz), false)
	else:
		text(g.name.substr(0, 18), Vector2(22, 90), 22, 600)
	text(SteamLib.fmt_last_played(g.last_played), Vector2(22, 134), 15, 500, Tokens.INK_FAINT)
