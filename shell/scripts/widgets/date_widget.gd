class_name DateWidget
extends GlassWidget

func setup() -> void:
	size = Vector2(252, 150)

func _paint() -> void:
	var t := Time.get_datetime_dict_from_system()
	var days := ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
	var months := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	text(days[t.weekday], Vector2(22, 36), 14, 700, Tokens.BAD.lerp(Tokens.GOLD, 0.5))
	text(str(t.day), Vector2(20, 106), 64, 300)
	text(months[t.month - 1], Vector2(22, 132), 18, 500, Tokens.INK_DIM)
