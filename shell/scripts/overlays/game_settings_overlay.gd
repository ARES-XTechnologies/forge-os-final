class_name GameSettingsOverlay
extends Overlay
## Per-game settings: FPS limit, overlay, Proton version, launch options.

var game: Dictionary
var _card: GlassPanel
var _list: RowList

func build() -> void:
	from_offset = Vector2(0, 80)
	_card = GlassPanel.new()
	_card.name = "content"
	_card.radius = 44
	_card.body_dim = 0.95
	_card.size = Vector2(1000, 760)
	add_child(_card)
	var t := Tokens.label(str(game.get("name", "Game")), 40, 700)
	t.position = Vector2(48, 38)
	t.size = Vector2(900, 50)
	t.clip_text = true
	_card.add_child(t)
	var s := Tokens.label("Game settings", 20, 500, Tokens.INK_DIM)
	s.position = Vector2(50, 94)
	_card.add_child(s)
	_list = RowList.new()
	_list.position = Vector2(18, 140)
	_list.size = Vector2(964, 600)
	_card.add_child(_list)
	_list.set_rows(_rows())
	_list.set_active(true)
	GameSettings.pending_changed.connect(func(): _list.refresh_all())

func _rows() -> Array:
	var appid := int(game.appid)
	var rows: Array = []
	if game.get("source", "steam") != "steam":
		if game.get("source", "") in ["local", "usb"]:
			# Games you added start through forge-fsr too, so they get their own FSR choice.
			var lfsr := SettingRow.choice("FSR upscaling", "", [["", "Same as console"], ["off", "Off (Fidelity)"], ["balanced", "Balanced"], ["performance", "Performance"]], "gauge", "From the next launch")
			lfsr.getter = func(): return str(Config.game_get(appid, "fsr", ""))
			lfsr.setter = func(v): Config.game_set(appid, "fsr", null if v == "" else v)
			rows.append(lfsr)
		rows.append(SettingRow.info("More per-game settings", func(): return "Steam games only for now", "info"))
		return rows
	var exe: String = (Config.get_v("games.exe") as Dictionary).get(str(appid), "")
	var fps := SettingRow.choice("FPS limit", "", [[-1, "Same as console"], [0, "Off"], [30, "30 FPS"], [40, "40 FPS"], [60, "60 FPS"], [90, "90 FPS"], [120, "120 FPS"], [144, "144 FPS"], [165, "165 FPS"], [240, "240 FPS"]], "timer", "" if exe != "" else "Takes effect after you've played the game once")
	fps.getter = func():
		var v = Config.game_get(appid, "fps", null)
		return -1 if v == null else int(v)
	fps.setter = func(v):
		Config.game_set(appid, "fps", null if int(v) < 0 else int(v))
		GameSettings.write_per_game_mangohud(appid)
	var ov := SettingRow.choice("Performance overlay", "", [["", "Same as console"], ["off", "Off"], ["fps", "FPS only"]], "chart")
	ov.getter = func(): return str(Config.game_get(appid, "overlay", ""))
	ov.setter = func(v):
		Config.game_set(appid, "overlay", null if v == "" else v)
		GameSettings.write_per_game_mangohud(appid)
	var fsr := SettingRow.choice("FSR upscaling", "", [["", "Same as console"], ["off", "Off (Fidelity)"], ["balanced", "Balanced"], ["performance", "Performance"]], "gauge", "From the next launch. If the game has its own FSR, use one or the other")
	fsr.getter = func(): return str(Config.game_get(appid, "fsr", ""))
	fsr.setter = func(v): Config.game_set(appid, "fsr", null if v == "" else v)
	var proton := SettingRow.choice("Proton version", "", GameSettings.proton_options(), "wrench", "Which compatibility layer runs this Windows game")
	proton.getter = func(): return str(Config.game_get(appid, "proton", ""))
	proton.setter = func(v): GameSettings.set_proton(appid, v)
	var launch := SettingRow.action("Launch options", func():
		shell.open_keyboard("Launch options (e.g. -dx11 or PROTON_ENABLE_NVAPI=1 %command%)", str(Config.game_get(appid, "launch", "")), false, func(t: String):
			GameSettings.set_launch_options(appid, t)
			_list.refresh_all()), "keyboard", "", func():
				var v := str(Config.game_get(appid, "launch", ""))
				return v if v != "" else "None")
	var apply := SettingRow.action("Apply now", func():
		if GameSettings.apply_now():
			shell.toast("Restarting Steam to apply…", "restart")
		else:
			shell.toast("Close the game first", "info", Tokens.WARN), "restart", "Restarts Steam in the background (about 20 seconds)", func(): return "Changes waiting" if GameSettings.has_pending() else "Nothing to apply")
	rows = [SettingRow.header("Performance"), fsr, fps, ov, SettingRow.header("Compatibility"), proton, launch, apply]
	if exe != "":
		rows.append(SettingRow.info("Game process", func(): return exe, "cpu"))
	return rows

func nav_action(a: StringName) -> bool:
	if a == &"back":
		close()
		return true
	_list.handle(a)
	return true

func hints() -> Array:
	return [["A", "Select"], ["◀▶", "Change"], ["B", "Back"]]
