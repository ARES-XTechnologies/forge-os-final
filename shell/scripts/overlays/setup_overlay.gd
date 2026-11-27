class_name SetupOverlay
extends Overlay
## First-boot setup: name, time zone, internet, controllers, look & feel, Steam.
## One glass card per step, sliding sideways with a bounce, progress dots underneath.

const STEPS := ["welcome", "profile", "timezone", "internet", "controllers", "look", "steam"]

var _step := 0
var _card: GlassPanel
var _title: Label
var _sub: Label
var _list: RowList
var _dots: Control
var _slide: Spring
var _name := ""
var _region := ""
var _city := ""
var _wifi: Array = []
var _bt: Array = []
var _net := {}
var _wifi_scanned := false

func build() -> void:
	covers_screen = true
	from_offset = Vector2(0, 80)
	_card = GlassPanel.new()
	_card.name = "content"
	_card.radius = 48
	_card.body_dim = 0.55
	_card.size = Vector2(1100, 700)
	add_child(_card)
	_title = Tokens.label("", 52, 700)
	_title.position = Vector2(64, 54)
	_card.add_child(_title)
	_sub = Tokens.label("", 22, 500, Tokens.INK_DIM)
	_sub.position = Vector2(66, 128)
	_sub.size = Vector2(970, 60)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(_sub)
	_list = RowList.new()
	_list.position = Vector2(36, 210)
	_list.size = Vector2(1028, 460)
	_card.add_child(_list)
	_dots = Control.new()
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.draw.connect(_draw_dots)
	add_child(_dots)
	_slide = Spring.preset(0.0, &"bouncy")
	_name = str(Profiles.current().get("name", ""))
	if _name.begins_with("Player"):
		_name = ""
	_detect_tz()
	_show(0)

func _detect_tz() -> void:
	var out := []
	OS.execute("readlink", PackedStringArray(["-f", "/etc/localtime"]), out)
	var p := str(out[0]).strip_edges() if not out.is_empty() else ""
	var idx := p.find("zoneinfo/")
	if idx != -1:
		var tz := p.substr(idx + 9).split("/")
		if tz.size() >= 2:
			_region = tz[0]
			_city = "/".join(tz.slice(1))
	if _region == "":
		_region = "Asia"
		_city = "Kolkata"

func _show(i: int, dir := 1) -> void:
	_step = clampi(i, 0, STEPS.size() - 1)
	_slide.snap(dir * 1.0)
	_slide.target = 0.0
	var rows: Array = []
	match STEPS[_step]:
		"welcome":
			_title.text = "Welcome to " + Tokens.OS_NAME
			_sub.text = "Let's get your console ready. It takes about a minute."
			rows = [SettingRow.action("Let's go", func(): _next(), "play")]
		"profile":
			_title.text = "What should we call you?"
			_sub.text = "Each player can have their own profile, look and Steam account. You can add more later."
			var nm := SettingRow.action("Your name", func():
				shell.open_keyboard("Your name", _name, false, func(t: String):
					_name = t.strip_edges()
					_list.refresh_all()), "keyboard", "", func(): return _name if _name != "" else "Choose a name")
			var col := SettingRow.choice("Colour", "", Profiles.COLORS.map(func(c): return [c, Profiles.color_name(c)]), "palette")
			col.getter = func(): return str(Profiles.current().get("color", Profiles.COLORS[0]))
			col.setter = func(v): Profiles.set_color(Profiles.active, v)
			rows = [nm, col, SettingRow.action("Continue", func(): _next(), "chevron_right")]
		"timezone":
			_title.text = "Where are you?"
			_sub.text = "This sets the clock."
			var regions := _dirs("/usr/share/zoneinfo", ["Africa", "America", "Antarctica", "Asia", "Atlantic", "Australia", "Europe", "Indian", "Pacific"])
			var reg := SettingRow.choice("Region", "", regions.map(func(r): return [r, r]), "network")
			reg.getter = func(): return _region
			reg.setter = func(v):
				_region = v
				var cities := _files("/usr/share/zoneinfo/" + v)
				_city = cities[0] if not cities.is_empty() else ""
				_show(_step, 0)
			var cities2 := _files("/usr/share/zoneinfo/" + _region)
			var city := SettingRow.choice("City", "", cities2.map(func(c): return [c, c.replace("_", " ")]), "clock")
			city.getter = func(): return _city
			city.setter = func(v): _city = v
			rows = [reg, city, SettingRow.action("Continue", func():
				if _region != "" and _city != "":
					Sys.run("sudo", ["-n", "/usr/lib/forge/forge-helper", "timezone", _region + "/" + _city])
				_next(), "chevron_right")]
		"internet":
			_title.text = "Get online"
			_sub.text = "FORGE needs the internet for Steam, updates and game art."
			rows.append(SettingRow.info("Status", func():
				if _net.get("wired", false): return "Connected by cable"
				if _net.get("wifi_ssid", "") != "": return "Connected to " + str(_net.wifi_ssid)
				return "Not connected", "network"))
			for w in _wifi.slice(0, 8):
				var ww: Dictionary = w
				rows.append(SettingRow.action(ww.ssid, func():
					if ww.secure:
						shell.open_keyboard("Password for " + ww.ssid, "", true, func(pw): _connect(ww.ssid, pw))
					else:
						_connect(ww.ssid, ""), "wifi", "", func(): return "%d%%" % ww.signal))
			rows.append(SettingRow.action("Continue", func(): _next(), "chevron_right"))
			Sys.net_status(func(st):
				_net = st
				_list.refresh_all())
			# Scan once only. A PC without Wi-Fi returns an empty list, and rescanning
			# on every redraw looped forever and kept pulling focus back to Status.
			if not _wifi_scanned:
				_wifi_scanned = true
				Sys.wifi_scan(func(l):
					_wifi = l
					if not _wifi.is_empty() and STEPS[_step] == "internet": _show(_step, 0))
		"controllers":
			_title.text = "Controllers"
			_sub.text = "USB, wireless dongles and Bluetooth all work. Put a Bluetooth controller in pairing mode, then search."
			var pads := Input.get_connected_joypads()
			for id in pads:
				rows.append(SettingRow.info(Input.get_joy_name(id), func(): return "Connected", "controller"))
			rows.append(SettingRow.action("Search for Bluetooth controllers", func():
				shell.toast("Searching for 12 seconds…", "bluetooth")
				Sys.bt_power(true, func():
					Sys.bt_scan(12, func():
						Sys.bt_devices(func(l):
							_bt = l
							_show(_step, 0)))), "bluetooth"))
			for d in _bt:
				var dd: Dictionary = d
				if dd.connected:
					continue
				rows.append(SettingRow.action(dd.name, func():
					shell.toast("Pairing with %s…" % dd.name, "bluetooth")
					Sys.bt_pair(dd.mac, func(ok, _o):
						shell.toast(("Paired with " + dd.name) if ok else "Pairing failed, try again", "bluetooth", Tokens.OK if ok else Tokens.BAD)), "bluetooth", "", func(): return "Pair"))
			rows.append(SettingRow.action("Continue", func(): _next(), "chevron_right"))
		"look":
			_title.text = "Make it yours"
			_sub.text = "You can change all of this later in Settings."
			var pal := []
			for k in Tokens.PALETTES.keys():
				pal.append([k, k.capitalize()])
			rows = [
				SettingRow.choice("Wallpaper colours", "appearance.palette", pal, "palette"),
				SettingRow.toggle("Contour glow", "appearance.glow", "sparkle"),
				SettingRow.choice("Sounds", "feedback.sound_theme", Sfx.THEMES, "volume"),
				SettingRow.toggle("Boot intro", "appearance.intro", "sparkle"),
				SettingRow.action("Continue", func(): _next(), "chevron_right"),
			]
		"steam":
			_title.text = "Sign in to Steam"
			_sub.text = "When Steam's sign-in window appears, scan the QR code with the Steam app on your phone. Optional: add a Steam Web API key to see games you own but haven't installed, and achievements."
			var key := SettingRow.action("Steam Web API key (optional)", func():
				shell.open_keyboard("Steam Web API key (steamcommunity.com/dev/apikey)", Config.get_s("steam.api_key"), false, func(t: String):
					Config.set_v("steam.api_key", t.strip_edges())
					_list.refresh_all()), "steam", "", func(): return "Added" if SteamWeb.has_key() else "Skip")
			rows = [key, SettingRow.action("Finish", func(): _finish(), "check")]
	# On a refresh (dir 0) stay on the same row, matched by name: new Wi-Fi networks
	# appearing above Continue must not move the highlight.
	var keep_title := ""
	if dir == 0 and _list.focused_row():
		keep_title = _list.focused_row().title
	var keep := -1
	for ri in rows.size():
		if keep_title != "" and rows[ri].title == keep_title:
			keep = ri
	_list.set_rows(rows)
	if keep >= 0:
		_list.index = keep
	elif STEPS[_step] == "internet" and rows.size() > 1:
		_list.index = rows.size() - 1  # start on Continue: cable users just press A
	_list.set_active(true)
	_dots.queue_redraw()
	if shell:
		shell.hint_bar.set_hints(hints())

func _dirs(path: String, keep: Array) -> Array:
	var d := DirAccess.open(path)
	if d == null:
		return keep
	return keep.filter(func(r): return d.dir_exists(r))

func _files(path: String) -> Array:
	var d := DirAccess.open(path)
	if d == null:
		return ["Kolkata"] if path.ends_with("Asia") else []
	var out := Array(d.get_files())
	out.sort()
	return out

func _connect(ssid: String, pw: String) -> void:
	shell.toast("Connecting to %s…" % ssid, "wifi")
	Sys.wifi_connect(ssid, pw, func(ok, _o):
		shell.toast(("Connected to " + ssid) if ok else "Couldn't connect. Check the password.", "wifi", Tokens.OK if ok else Tokens.BAD)
		Sys.net_status(func(st):
			_net = st
			_list.refresh_all()))

func _next() -> void:
	if STEPS[_step] == "profile" and _name != "":
		Profiles.rename(Profiles.active, _name)
	_show(_step + 1, 1)
	Sfx.play("tab")

func _finish() -> void:
	Config.set_v("system.first_run_done", true)
	Config.save_now()
	Shellbus.notify({"title": "You're all set" + ((", " + _name) if _name != "" else ""), "body": "Enjoy " + Tokens.OS_NAME, "icon": "sparkle", "color": Tokens.GOLD, "sound": "achievement"})
	close()

func nav_action(a: StringName) -> bool:
	if a == &"back":
		if _step > 0:
			_show(_step - 1, -1)
			Sfx.back()
		return true
	_list.handle(a)
	return true

func hints() -> Array:
	return [["A", "Select"], ["B", "Back"]]

func _content_base() -> Vector2:
	return (size - _card.size) * 0.5 + Vector2(0, -20)

func _draw_dots() -> void:
	var n := STEPS.size()
	var w := n * 26.0
	var x0 := (size.x - w) * 0.5
	var y := _card.position.y + _card.size.y + 40.0
	for i in n:
		var on := i == _step
		var r := Rect2(Vector2(x0 + i * 26.0 - (8.0 if on else 0.0), y), Vector2(30.0 if on else 12.0, 12.0))
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(6)
		sb.anti_aliasing = true
		sb.bg_color = Tokens.ACCENT if on else (Color(1, 1, 1, 0.5) if i < _step else Color(1, 1, 1, 0.18))
		_dots.draw_style_box(sb, r)

func animate(o: float, dt: float) -> void:
	super.animate(o, dt)
	var s := _slide.step(dt)
	_title.position.x = 64 + s * 120.0
	_sub.position.x = 66 + s * 90.0
	_list.position.x = 36 + s * 70.0
	_list.modulate.a = 1.0 - clampf(absf(s), 0.0, 1.0)
	_dots.size = size
	_dots.queue_redraw()
