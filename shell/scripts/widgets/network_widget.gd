class_name NetworkWidget
extends GlassWidget

var _st := {}

func setup() -> void:
	size = Vector2(252, 150)

func tick_rate() -> float: return 6.0

func update() -> void:
	Sys.net_status(func(st): _st = st)

func _paint() -> void:
	caption("Network")
	var name := "Offline"
	if _st.get("wired", false): name = "Wired"
	elif _st.get("wifi_ssid", "") != "": name = _st.wifi_ssid
	text(name.substr(0, 16), Vector2(22, 92), 28, 500, Tokens.INK if name != "Offline" else Tokens.INK_DIM)
	text(_st.get("ip", ""), Vector2(22, 124), 15, 500, Tokens.INK_FAINT)
