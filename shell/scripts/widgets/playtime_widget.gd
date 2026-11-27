class_name PlaytimeWidget
extends GlassWidget

func setup() -> void:
	size = Vector2(252, 150)

func tick_rate() -> float: return 10.0

func _paint() -> void:
	caption("Total playtime")
	var m := 0
	for g in SteamLib.games:
		m += int(g.playtime)
	text("%d" % (m / 60), Vector2(20, 104), 52, 300)
	text("hours across %d games" % SteamLib.games.size(), Vector2(22, 132), 15, 500, Tokens.INK_FAINT)
