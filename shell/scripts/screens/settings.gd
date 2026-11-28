class_name SettingsScreen
extends Screen
## Settings: categories on the left, detailed controls on the right, both glass.
## Up/Down to move, A or → to enter a category, ◀ ▶ to change values, B to go back.

const CATS := [
	["profiles", "Profiles", "sparkle"],
	["display", "Display", "display"],
	["appearance", "Appearance", "palette"],
	["clock", "Clock", "clock"],
	["motion", "Motion & feel", "sparkle"],
	["widgets", "Widgets", "widgets"],
	["library", "Library & stores", "grid"],
	["capture", "Capture & play", "image"],
	["audio", "Audio", "volume"],
	["network", "Network", "network"],
	["bluetooth", "Bluetooth", "bluetooth"],
	["controllers", "Controllers", "controller"],
	["performance", "Performance", "gauge"],
	["storage", "Storage", "storage"],
	["system", "System", "info"],
]

var _left: GlassPanel
var _right: GlassPanel
var _cats: RowList
var _rows: RowList
var _cat_title: Label
var _cat_sub: Label
var _side := 0                   # 0 = categories, 1 = rows
var _cat := 0
var _panel_x: Spring
var _panel_a: Spring
var _pending_cat := -1
var _wifi: Array = []
var _bt: Array = []
var _audio := {"sinks": [], "volume": 0.5, "muted": false}
var _drives: Array = []
var _net := {}
var _modes: Array = []

func _ready() -> void:
	_left = GlassPanel.new()
	_left.radius = 40
	_left.shadow = 0.7
	_left.body_dim = 0.5
	_left.glow_scale = 0.75
	add_child(_left)
	_right = GlassPanel.new()
	_right.radius = 40
	_right.shadow = 0.7
	_right.body_dim = 0.5
	_right.glow_scale = 0.75
	add_child(_right)
	_cats = RowList.new()
	_left.add_child(_cats)
	_cat_title = Tokens.label("", 40, 700)
	_right.add_child(_cat_title)
	_cat_sub = Tokens.label("", 19, 500, Tokens.INK_FAINT)
	_right.add_child(_cat_sub)
	_rows = RowList.new()
	_right.add_child(_rows)
	_panel_x = Spring.preset(0.0, &"snappy")
	_panel_a = Spring.preset(1.0, &"smooth")
	resized.connect(_layout)
	_layout()
	var list := []
	for c in CATS:
		var r := SettingRow.action(c[1], Callable(), c[2])
		list.append(r)
	_cats.set_rows(list)
	_cats.set_active(false)
	_show_cat(0, true)

func _layout() -> void:
	var top := 170.0
	var h := size.y - top - 110.0
	_left.position = Vector2(Tokens.SAFE_X, top)
	_left.size = Vector2(430, h)
	_cats.position = Vector2(16, 20)
	_cats.size = Vector2(398, h - 40)
	_right.position = Vector2(Tokens.SAFE_X + 460, top)
	_right.size = Vector2(size.x - Tokens.SAFE_X * 2.0 - 460, h)
	_cat_title.position = Vector2(44, 32)
	_cat_sub.position = Vector2(46, 86)
	_rows.position = Vector2(16, 132)
	_rows.size = Vector2(_right.size.x - 32, h - 150)

func _show_cat(i: int, instant := false) -> void:
	_cat = i
	_cat_title.text = CATS[i][1]
	_cat_sub.text = _subtitle(CATS[i][0])
	_rows.set_rows(_build_rows(CATS[i][0]))
	_rows.set_active(_side == 1)
	if not instant:
		_panel_x.snap(40.0)
		_panel_x.target = 0.0
		_panel_a.snap(0.3)
		_panel_a.target = 1.0
	_fetch_async(CATS[i][0])

func _subtitle(id: String) -> String:
	match id:
		"display": return "Resolution and refresh rate apply after a quick restart of the console UI."
		"appearance": return "Wallpaper, liquid glass and the boot intro."
		"clock": return "Make the clock yours."
		"motion": return "How fast, bouncy and noisy everything feels."
		"widgets": return "Glass widgets on the Home screen. All off by default."
		"audio": return "Output device and volume."
		"network": return "Wi-Fi and wired connection."
		"bluetooth": return "Pair controllers and headsets."
		"controllers": return "Any controller works: Bluetooth, wireless dongle or USB."
		"performance": return "FSR upscaling, in-game overlay and benchmarks."
		"storage": return "Drives and how much space your games use."
		"system": return "About this console, updates and power."
		"profiles": return "Everyone gets their own look, favourites and Steam account."
		"library": return "Steam, Epic, GOG and classic games in one library."
		"capture": return "Screenshots, clips and what happens while you play."
	return ""

# ------------------------------------------------------------------ rows per category
func _build_rows(id: String) -> Array:
	var pct := func(v): return "%d%%" % int(round(float(v) * 100.0))
	var mult := func(v): return "%.2f×" % float(v)
	match id:
		"profiles":
			var cur := Profiles.current()
			var name := SettingRow.action("Name", func():
				shell.open_keyboard("Profile name", str(cur.name), false, func(t):
					Profiles.rename(cur.id, t)
					_show_cat(_cat, true)), "keyboard", "", func(): return str(Profiles.current().name))
			var col := SettingRow.choice("Colour", "", Profiles.COLORS.map(func(c): return [c, Profiles.color_name(c)]), "palette")
			col.getter = func(): return str(Profiles.current().color)
			col.setter = func(v): Profiles.set_color(Profiles.active, v)
			var accs := [["", "Use whoever is signed in"]]
			for a in GameSettings.steam_accounts():
				accs.append([a[0], a[1]])
			var acc := SettingRow.choice("Steam account", "", accs, "steam", "Steam restarts in the background when this changes")
			acc.getter = func(): return str(Profiles.current().get("steam", ""))
			acc.setter = func(v): Profiles.set_steam(Profiles.active, v)
			var rows0: Array = [SettingRow.header("This profile"), name, col, acc, SettingRow.header("Players"),
				SettingRow.action("Switch profile", func(): shell.open_profiles(), "restart", "", func(): return "%d profile%s" % [Profiles.list.size(), "" if Profiles.list.size() == 1 else "s"]),
				SettingRow.action("Add a profile", func():
					shell.open_keyboard("New profile name", "", false, func(t):
						var p := Profiles.add(t)
						shell.toast("Added " + str(p.name), "plus")
						_show_cat(_cat, true)), "plus")]
			for p in Profiles.list:
				if p.id == Profiles.active:
					continue
				var pp: Dictionary = p
				rows0.append(SettingRow.action("Remove " + str(pp.name), func():
					shell.confirm("Remove %s?" % pp.name, "Their settings and favourites are deleted. Games aren't touched.", [["Remove", "trash"], ["Cancel", "close"]], func(i):
						if i == 0:
							Profiles.remove(pp.id)
							_show_cat(_cat, true)), "trash"))
			return rows0
		"library":
			return [
				SettingRow.header("Steam"),
				SettingRow.action("Steam Web API key", func():
					shell.open_keyboard("Steam Web API key (get one free at steamcommunity.com/dev/apikey)", Config.get_s("steam.api_key"), false, func(t: String):
						Config.set_v("steam.api_key", t.strip_edges())
						_rows.refresh_all()), "steam", "Shows games you own but haven't installed, and achievements", func(): return "Added" if SteamWeb.has_key() else "Not set"),
				SettingRow.toggle("Show games you haven't installed", "library.show_uninstalled", "update"),
				SettingRow.header("Home and apps"),
				SettingRow.choice("Home layout", "library.home_layout", [["unified", "Unified"], ["separate", "Separate rows"]], "grid", "Unified: games and apps in one row. Separate rows: press down for Apps"),
				SettingRow.toggle("Show apps", "library.apps", "grid", "Steam, Heroic, RetroArch and Firefox on Home and in Library"),
				SettingRow.action("Refresh library", func():
					SteamWeb.refresh_owned()
					SteamLib.rescan()
					shell.toast("Refreshing your library…", "restart"), "restart"),
				SettingRow.header("Epic Games & GOG"),
				SettingRow.toggle("Show Epic & GOG games", "library.heroic", "grid", "Installed through Heroic Games Launcher"),
				SettingRow.action("Open Heroic", func():
					if HeroicLib.available():
						HeroicLib.open_launcher()
						shell.toast("Sign in and install games in Heroic. They'll appear here.", "grid")
					else:
						shell.toast("Heroic isn't installed. Run Update system first.", "info", Tokens.WARN), "grid", "Sign in to Epic / GOG and install games"),
				SettingRow.header("Your own games"),
				SettingRow.action("Add a game", func(): shell.open_add_game(), "plus", "Any .exe or Linux game on this console or a USB drive"),
				SettingRow.info("Games you've added", func(): return str(LocalGames.games.size()), "grid"),
				SettingRow.action("Prepare Proton now", func():
					shell.toast("Downloading Proton… this takes a few minutes", "wrench")
					LocalGames.prepare_proton("", func(ok: bool):
						shell.toast("Proton is ready" if ok else "Couldn't download Proton. Check the internet.", "check" if ok else "info", Tokens.OK if ok else Tokens.BAD)), "wrench", "Downloads it ahead of time so your first Windows game starts faster"),
				SettingRow.toggle("Show where each game comes from", "library.badges", "info", "Steam, Epic, GOG, Local disk, USB or the console name"),
				SettingRow.header("Classics (RetroArch)"),
				SettingRow.toggle("Show classic games", "library.retro", "controller"),
				SettingRow.action("Import games from USB", _import_roms, "storage", "Copies game files you own into the right folders"),
				SettingRow.info("Game folder", func(): return RetroLib.rom_root(), "info"),
			]
		"capture":
			return [
				SettingRow.header("Screenshots"),
				SettingRow.info("Take a screenshot", func(): return "Share, or Guide + X", "image"),
				SettingRow.header("Clips"),
				SettingRow.toggle("Record clips", "capture.clips", "timer", "Keeps the last moments of gameplay ready to save (costs a few FPS)"),
				SettingRow.choice("Clip length", "capture.clip_length", [[15, "15 seconds"], [30, "30 seconds"], [60, "1 minute"], [120, "2 minutes"]], "clock"),
				SettingRow.info("Save a clip", func(): return "Guide + Y", "timer"),
				SettingRow.header("While playing"),
				SettingRow.toggle("Show the menu hint when a game starts", "ingame.hint", "info"),
				SettingRow.toggle("Pause the game while the menu is open", "ingame.pause", "moon", "Turn off for online games"),
				SettingRow.toggle("Achievement notifications", "ingame.achievement_toasts", "star", "Needs the Steam Web API key"),
			]
		"display":
			_modes = Sys.display_modes()
			var nat := Sys.native_mode()
			var mode_opts := []
			for m in _modes:
				var native: bool = m.x == nat.x and m.y == nat.y
				mode_opts.append(["%dx%d" % [m.x, m.y], "%d × %d%s" % [m.x, m.y, " (default)" if native else ""]])
			var res := SettingRow.choice("Resolution", "", mode_opts, "display", "Default is your screen's own resolution")
			res.getter = func(): return "%dx%d" % [Sys.display_width(), Sys.display_height()]
			res.setter = func(v: String):
				var p := v.split("x")
				Config.set_v("display.custom", true)
				Config.set_v("display.width", int(p[0]))
				Config.set_v("display.height", int(p[1]))
				if Config.get_i("display.refresh") <= 0:
					Config.set_v("display.refresh", Sys.display_refresh())
			var hz := []
			for r in Sys.refresh_rates():
				hz.append([r, "%d Hz%s" % [r, " (default)" if r == nat.z else ""]])
			var hz_row := SettingRow.choice("Refresh rate", "", hz, "gauge", "Default is your screen's highest: %d Hz. The whole console runs at this rate" % nat.z)
			hz_row.getter = func(): return Sys.display_refresh()
			hz_row.setter = func(v):
				Config.set_v("display.custom", true)
				if Config.get_i("display.width") <= 0:
					Config.set_v("display.width", Sys.display_width())
					Config.set_v("display.height", Sys.display_height())
				Config.set_v("display.refresh", int(v))
			var reset_row := SettingRow.action("Use my screen's best mode", func():
				Config.set_v("display.custom", false)
				Config.set_v("display.width", 0)
				Config.set_v("display.height", 0)
				Config.set_v("display.refresh", 0)
				_rows.refresh_all(), "restart", "%d × %d at %d Hz (default)" % [nat.x, nat.y, nat.z])
			var scale_row := SettingRow.slider("Interface size", "display.ui_scale", 0.8, 1.3, 0.05, mult, "widgets", "Make the whole console UI bigger or smaller")
			return [
				SettingRow.header("Output"), res,
				hz_row, reset_row,
				SettingRow.toggle("HDR", "display.hdr", "sparkle", "Needs an HDR display and an HDR-capable game"),
				SettingRow.toggle("Variable refresh rate", "display.vrr", "chart", "FreeSync / G-SYNC Compatible displays"),
				SettingRow.action("Apply display changes", _apply_display, "check", "The console UI restarts in a second. Games are not affected."),
				SettingRow.header("Interface"), scale_row,
			]
		"appearance":
			var pal := []
			for k in Tokens.PALETTES.keys():
				pal.append([k, k.capitalize()])
			return [
				SettingRow.header("Wallpaper"),
				SettingRow.choice("Wallpaper", "appearance.wallpaper", [["ribbons", "Silk Ribbons"], ["nebula", "Nebula"], ["silk", "Satin"], ["caustics", "Caustics"], ["northern", "Northern Lights"], ["orbs", "Orbs"], ["golden", "Golden Dust"], ["shallows", "Sunlit Shallows"], ["coral", "Coral Light"], ["deep", "The Deep"], ["night_rain", "Night Rain"], ["chrome", "Liquid Chrome"], ["gold", "Liquid Gold"], ["prism", "Prism"], ["starfall", "Starfall"], ["rose", "Rose Horizon"], ["canopy", "Night Canopy"], ["deepfield", "Deep Field"], ["afterglow", "Afterglow"], ["mirror", "Mirror Lake"], ["violet", "Violet Peaks"], ["photo", "Your photo"]], "image", "Animated scenes. Colours below tint the abstract ones"),
				SettingRow.action("Use your own photo", func(): shell.open_photo_picker(), "plus", "JPG or PNG from any drive or USB stick"),
				SettingRow.slider("Soften photo", "appearance.wallpaper_soften", 0.0, 1.0, 0.1, pct, "image", "Blurs your photo so the glass stands out"),
				SettingRow.choice("Colours", "appearance.palette", pal, "palette"),
				SettingRow.toggle("Animated", "appearance.wallpaper_animated", "sparkle"),
				SettingRow.slider("Flow speed", "appearance.wallpaper_speed", 0.2, 2.0, 0.1, mult, "timer"),
				SettingRow.slider("Brightness", "appearance.wallpaper_intensity", 0.4, 1.6, 0.1, pct, "sparkle"),
				SettingRow.toggle("Parallax", "appearance.parallax", "image", "The sky shifts gently as you move between games"),
				SettingRow.toggle("Match colours to the game", "appearance.dynamic", "palette", "The sky takes on the colours of the game you're on"),
				SettingRow.choice("Game art", "appearance.game_art", [["full", "Full screen"], ["blend", "Blend"]], "image", "Full screen: the game's art covers the screen. Blend: it melts into your wallpaper"),
				SettingRow.toggle("Card frames", "library.card_frames", "image", "A liquid-glass frame around each game. Off: artwork only"),
				SettingRow.toggle("Button hints", "appearance.hints", "info", "The button guide along the bottom of the screen"),
				SettingRow.header("Glass"),
				SettingRow.choice("Glass style", "appearance.glass_style", [["liquid", "Liquid glass"], ["mist", "Liquid mist"], ["frosted", "Frosted glass"], ["matte", "Matte"]], "sparkle", "Liquid: clear like water. Mist: clear with a soft veil. Frosted: soft and milky. Matte: calm"),
				SettingRow.slider("Refraction", "appearance.glass_refraction", 0.0, 2.0, 0.1, pct, "sparkle"),
				SettingRow.slider("Colour split", "appearance.glass_dispersion", 0.0, 2.0, 0.1, pct, "palette"),
				SettingRow.slider("Tint", "appearance.glass_tint", 0.0, 0.3, 0.02, func(v): return "%d%%" % int(float(v) / 0.3 * 100.0), "palette"),
				SettingRow.slider("Glass brightness", "appearance.glass_brightness", 0.0, 2.0, 0.1, pct, "sparkle", "How light or dark every glass surface looks"),
				SettingRow.header("Contour glow"),
				SettingRow.toggle("Contour glow", "appearance.glow", "sparkle", "A line of light around the edge of every glass surface"),
				SettingRow.choice("Glow colour", "appearance.glow_color", [["adaptive", "Adaptive"], ["accent", "Accent"], ["gold", "Gold"], ["ice", "Ice"], ["rainbow", "Rainbow"]], "palette", "Adaptive picks up the colours behind the glass"),
				SettingRow.slider("Glow brightness", "appearance.glow_strength", 0.1, 1.5, 0.05, pct, "sparkle", "100% is full brightness. Starts at 80%"),
				SettingRow.toggle("Moving light", "appearance.glow_motion", "restart", "A soft highlight slowly travels around each edge"),
				SettingRow.header("Startup"),
				SettingRow.toggle("Boot intro", "appearance.intro", "sparkle", "The golden particle intro when the console starts"),
			]
		"clock":
			var cols := []
			for k in Tokens.CLOCK_COLORS.keys():
				cols.append([k, k.capitalize()])
			cols.append(["custom", "Custom"])
			return [
				SettingRow.choice("Colour", "appearance.clock_color", cols, "palette"),
				SettingRow.slider("Custom colour", "appearance.clock_hue", 0.0, 1.0, 0.02, func(v): return "%d°" % int(float(v) * 360.0), "palette", "Used when Colour is set to Custom"),
				SettingRow.toggle("24-hour clock", "appearance.clock_24h", "clock"),
				SettingRow.toggle("Show seconds", "appearance.clock_seconds", "timer"),
				SettingRow.slider("Size", "appearance.clock_size", 0.8, 1.6, 0.05, mult, "widgets"),
			]
		"motion":
			return [
				SettingRow.header("Animation"),
				SettingRow.slider("Speed", "motion.speed", 0.5, 1.6, 0.1, mult, "timer"),
				SettingRow.slider("Bounciness", "motion.bounce", 0.0, 2.0, 0.1, pct, "sparkle", "0% removes all overshoot"),
				SettingRow.toggle("Reduce motion", "motion.reduce", "eye_off", "Calmer, faster transitions"),
				SettingRow.header("Feedback"),
				SettingRow.toggle("UI sounds", "feedback.sounds", "volume"),
				SettingRow.choice("Sound theme", "feedback.sound_theme", Sfx.THEMES, "volume"),
				SettingRow.slider("Sound volume", "feedback.volume", 0.0, 1.0, 0.05, pct, "volume"),
				SettingRow.toggle("Controller vibration", "feedback.haptics", "controller"),
				SettingRow.slider("Vibration strength", "feedback.haptic_strength", 0.1, 1.0, 0.1, pct, "controller"),
			]
		"widgets":
			return [
				SettingRow.toggle("Show widgets on Home", "widgets.enabled", "widgets"),
				SettingRow.header("Widgets"),
				SettingRow.toggle("Clock", "widgets.clock", "clock", "Analog glass clock"),
				SettingRow.toggle("Date", "widgets.date", "calendar"),
				SettingRow.toggle("Calendar", "widgets.calendar", "calendar", "This month at a glance"),
				SettingRow.toggle("System", "widgets.system", "cpu", "CPU, GPU and memory rings"),
				SettingRow.toggle("Session", "widgets.session", "timer", "How long the console has been on"),
				SettingRow.toggle("Controllers", "widgets.controllers", "controller"),
				SettingRow.toggle("Network", "widgets.network", "network"),
				SettingRow.toggle("Storage", "widgets.storage", "storage"),
				SettingRow.toggle("Last played", "widgets.recent", "play"),
				SettingRow.toggle("Total playtime", "widgets.playtime", "chart"),
			]
		"audio":
			var sinks := []
			for s in _audio.sinks:
				sinks.append([s.id, s.name])
			if sinks.is_empty():
				sinks.append([-1, "No speakers found"])
			var out := SettingRow.choice("Output", "", sinks, "volume")
			out.getter = func():
				for s in _audio.sinks:
					if s.default: return s.id
				return -1 if _audio.sinks.is_empty() else _audio.sinks[0].id
			out.setter = func(v):
				if int(v) < 0:
					return
				Sys.set_default_sink(int(v))
				for s in _audio.sinks: s.default = s.id == v
			var vol := SettingRow.slider("Volume", "", 0.0, 1.0, 0.05, pct, "volume")
			vol.getter = func(): return float(_audio.volume)
			vol.setter = func(v):
				_audio.volume = v
				Sys.set_volume(v)
			var mute := SettingRow.toggle("Mute", "", "mute")
			mute.getter = func(): return bool(_audio.muted)
			mute.setter = func(v):
				_audio.muted = v
				Sys.set_mute(v)
			return [out, vol, mute]
		"network":
			var rows: Array = []
			var wifi := SettingRow.toggle("Wi-Fi", "", "wifi")
			wifi.getter = func(): return bool(_net.get("wifi_on", true))
			wifi.setter = func(v):
				_net.wifi_on = v
				Sys.wifi_set(v, func(): _fetch_async("network"))
			rows.append(wifi)
			rows.append(SettingRow.info("Connection", func():
				if _net.get("wired", false): return "Wired"
				if _net.get("wifi_ssid", "") != "": return _net.wifi_ssid
				return "Not connected", "network"))
			rows.append(SettingRow.info("IP address", func(): return _net.get("ip", "—") if _net.get("ip", "") != "" else "—", "info"))
			rows.append(SettingRow.header("Networks nearby"))
			for w in _wifi:
				var ww: Dictionary = w
				var label: String = ww.ssid + ("   ✓" if ww.active else "")
				rows.append(SettingRow.action(label, func(): _wifi_pressed(ww), "wifi", "", func(): return "%d%%%s" % [ww.signal, " · secured" if ww.secure else ""]))
			rows.append(SettingRow.action("Scan again", func():
				_wifi.clear()
				shell.toast("Looking for networks…", "wifi")
				_fetch_async("network", true), "restart"))
			return rows
		"bluetooth":
			var rows2: Array = [
				SettingRow.action("Pair a new device", _bt_scan, "plus", "Put your controller or headset in pairing mode first"),
				SettingRow.header("Devices"),
			]
			for d in _bt:
				var dd: Dictionary = d
				var state := "Connected" if dd.connected else ("Paired" if dd.paired else "Available")
				rows2.append(SettingRow.action(dd.name, func(): _bt_pressed(dd), "bluetooth", "", func(): return state))
			if _bt.is_empty():
				rows2.append(SettingRow.info("No devices yet", func(): return "", "info"))
			return rows2
		"controllers":
			var rows3: Array = [SettingRow.header("Connected")]
			var pads := Input.get_connected_joypads()
			if pads.is_empty():
				rows3.append(SettingRow.info("No controller connected", func(): return "", "controller"))
			for jid in pads:
				var pid: int = jid
				rows3.append(SettingRow.action(Input.get_joy_name(pid), func():
					Input.start_joy_vibration(pid, 0.6, 0.9, 0.4)
					shell.toast("Buzz! That's controller %d" % (pid + 1), "controller"), "controller", "", func(): return "Press A to identify"))
			rows3 += [
				SettingRow.header("Feel"),
				SettingRow.slider("Stick dead zone", "input.deadzone", 0.15, 0.7, 0.05, pct, "controller"),
				SettingRow.slider("Hold-to-scroll delay", "input.repeat_delay", 0.15, 0.6, 0.01, func(v): return "%d ms" % int(float(v) * 1000), "timer"),
				SettingRow.slider("Scroll speed", "input.repeat_rate", 0.03, 0.15, 0.005, func(v): return "%d/s" % int(1.0 / float(v)), "gauge"),
				SettingRow.toggle("Swap A and B", "input.swap_ab", "controller", "Nintendo-style layout"),
				SettingRow.toggle("Vibration", "feedback.haptics", "controller"),
			]
			return rows3
		"performance":
			return [
				SettingRow.header("Upscaling and speed"),
				SettingRow.choice("FSR upscaling", "fsr.mode", GameSettings.FSR_CHOICES, "gauge", "Fidelity 67% · Balanced 59% · Performance 50% · Ultra 33%"),
				SettingRow.info("CPU and GPU", func(): return "Always at full speed", "cpu"),
				SettingRow.choice("Frame rate limit", "perf.fps_limit", [[0, "Off"], [30, "30 FPS"], [40, "40 FPS"], [60, "60 FPS"], [90, "90 FPS"], [120, "120 FPS"], [144, "144 FPS"], [165, "165 FPS"], [240, "240 FPS"]], "timer"),
				SettingRow.header("In-game overlay"),
				SettingRow.choice("Overlay", "perf.overlay", [["off", "Off"], ["fps", "FPS only"], ["detailed", "Detailed"], ["full", "Everything"]], "chart", "Shift+F12 on a keyboard toggles it in game"),
				SettingRow.choice("Position", "perf.overlay_position", [["top-left", "Top left"], ["top-right", "Top right"], ["bottom-left", "Bottom left"], ["bottom-right", "Bottom right"], ["top-center", "Top centre"]], "display"),
				SettingRow.header("Benchmarks"),
				SettingRow.toggle("Record every game session", "perf.logging", "timer", "Saves frame times, CPU and GPU data for each run"),
				SettingRow.choice("Recording length", "perf.log_duration", [[0, "Whole session"], [30, "30 seconds"], [60, "1 minute"], [120, "2 minutes"], [300, "5 minutes"]], "clock"),
				SettingRow.action("Benchmark results", func(): shell.open_benchmarks(), "chart", "Average FPS, 1% lows, frame pacing, temperatures"),
				SettingRow.toggle("Console UI frame graph", "perf.shell_overlay", "gauge", "Shows how smoothly this interface is running"),
			]
		"storage":
			var rows4: Array = [SettingRow.header("Drives")]
			for d in _drives:
				var dd2: Dictionary = d
				rows4.append(SettingRow.info(dd2.mount, func(): return "%s free of %s" % [SteamLib.fmt_size(dd2.free), SteamLib.fmt_size(dd2.size)], "storage"))
			rows4.append(SettingRow.header("Games"))
			rows4.append(SettingRow.info("All games", func(): return SteamLib.fmt_size(SteamLib.total_size()), "grid"))
			for g in SteamLib.sorted("size").slice(0, 10):
				var gg: Dictionary = g
				rows4.append(SettingRow.action(gg.name, func(): shell.open_game(gg), "play", "", func(): return SteamLib.fmt_size(gg.size)))
			return rows4
		"system":
			var info := Sys.about()
			return [
				SettingRow.header("About"),
				SettingRow.info("System", func(): return info.os, "sparkle"),
				SettingRow.info("Processor", func(): return "%s · %d threads" % [info.cpu.strip_edges(), info.threads], "cpu"),
				SettingRow.info("Graphics", func(): return info.gpu, "gpu"),
				SettingRow.info("Memory", func(): return SteamLib.fmt_size(info.ram), "ram"),
				SettingRow.info("Kernel", func(): return info.kernel if info.kernel != "" else "—", "info"),
				SettingRow.info("Made by", func(): return Tokens.STUDIO, "sparkle"),
				SettingRow.header("FORGE updates"),
				SettingRow.info("Status", func(): return Updater.status if Updater.status != "" else "Version " + Tokens.OS_VERSION, "info"),
				SettingRow.action("Check for updates", func(): Updater.check(), "restart"),
				SettingRow.action("Install update", func():
					if Updater.latest == "":
						shell.toast("You're on the latest version", "check", Tokens.OK)
					else:
						Updater.install(), "update", "Keeps your games, settings and profiles", func(): return Updater.latest.trim_prefix("v") if Updater.latest != "" else "Up to date"),
				SettingRow.toggle("Check automatically", "update.auto_check", "clock"),
				SettingRow.action("Update source", func():
					shell.open_keyboard("GitHub repository (owner/name)", Config.get_s("update.repo"), false, func(t): Config.set_v("update.repo", t.strip_edges())), "network", "", func(): return Config.get_s("update.repo") if Config.get_s("update.repo") != "" else "Not set"),
				SettingRow.action("Access token (private repos)", func():
					shell.open_keyboard("GitHub access token", Config.get_s("update.token"), true, func(t): Config.set_v("update.token", t.strip_edges())), "keyboard", "", func(): return "Set" if Config.get_s("update.token") != "" else "None"),
				SettingRow.action("Undo the last update", func():
					shell.confirm("Go back to the previous version?", "The console UI restarts.", [["Go back", "restart"], ["Cancel", "close"]], func(i): if i == 0: Updater.rollback()), "restart"),
				SettingRow.header("Quality"),
				SettingRow.choice("Visual quality", "ui.preset", [["ultra", "Ultra"], ["high", "High"], ["balanced", "Balanced"]], "sparkle", "Sets refraction, colour split and glow together"),
				SettingRow.header("Maintenance"),
				SettingRow.action("Repair system", _update, "update", "Reinstalls FORGE's system parts and brings every package back to the tested versions"),
				SettingRow.action("Restart console UI", func(): Sys.restart_session(), "restart"),
				SettingRow.action("Open Steam Big Picture", func(): Sys.switch_to_big_picture(), "steam", "FORGE returns when you exit it"),
				SettingRow.action("Reset console", func():
					shell.confirm("Reset this console?", "Profiles and settings are erased and setup runs again. Your installed games stay.", [["Reset", "restart"], ["Reset + sign out of Steam", "trash"], ["Cancel", "close"]], func(i):
						if i == 0: Sys.factory_reset(false)
						elif i == 1: Sys.factory_reset(true)), "trash", "Like new: setup runs again"),
				SettingRow.info("Recovery mode", func(): return "Hold Space while the console starts", "wrench"),
				SettingRow.action("Reset all settings", func():
					shell.confirm("Reset every setting?", "Your games and Steam account are not touched.", [["Reset", "restart"], ["Cancel", "close"]], func(i):
						if i == 0:
							Config.reset_all()
							shell.toast("Settings reset", "restart")
							_show_cat(_cat)), "restart"),
				SettingRow.header("Power"),
				SettingRow.action("Restart", func(): Sys.power("reboot"), "restart"),
				SettingRow.action("Power off", func(): Sys.power("poweroff"), "power"),
			]
	return []

func _fetch_async(id: String, force := false) -> void:
	match id:
		"audio":
			Sys.audio_status(func(st):
				_audio = st
				_rebuild_if(id))
		"network":
			Sys.net_status(func(st):
				_net = st
				_rows.refresh_all())
			if _wifi.is_empty() or force:
				Sys.wifi_scan(func(list):
					_wifi = list
					_rebuild_if(id))
		"bluetooth":
			Sys.bt_devices(func(list):
				_bt = list
				_rebuild_if(id))
		"storage":
			Sys.storage(func(list):
				_drives = list
				_rebuild_if(id))

func _rebuild_if(id: String) -> void:
	if CATS[_cat][0] != id:
		return
	var keep := _rows.index
	_rows.set_rows(_build_rows(id))
	_rows.index = mini(keep, _rows.rows.size() - 1)
	_rows.set_active(_side == 1 and active)

# ------------------------------------------------------------------ actions
func _apply_display() -> void:
	shell.confirm("Apply display settings?", "%d × %d at %d Hz. The console UI restarts now." % [Sys.display_width(), Sys.display_height(), Sys.display_refresh()],
		[["Apply", "check"], ["Cancel", "close"]], func(i):
			if i == 0:
				Sys.write_session_conf()
				Sys.restart_session())

func _update() -> void:
	shell.toast("Updating… this can take a few minutes", "update")
	Sys.system_update(func(ok: bool, _out: String):
		if ok:
			shell.toast("Everything is up to date. Restart to finish.", "check", Tokens.OK)
		else:
			shell.toast("Update failed. Check your internet connection.", "info", Tokens.BAD))

func _wifi_pressed(w: Dictionary) -> void:
	if w.active:
		shell.confirm("Forget %s?" % w.ssid, "You'll need the password to connect again.", [["Forget", "trash"], ["Cancel", "close"]], func(i):
			if i == 0:
				Sys.wifi_forget(w.ssid, func(): _fetch_async("network", true)))
		return
	if w.secure:
		shell.open_keyboard("Password for " + w.ssid, "", true, func(pw: String):
			_connect_wifi(w.ssid, pw))
	else:
		_connect_wifi(w.ssid, "")

func _connect_wifi(ssid: String, pw: String) -> void:
	shell.toast("Connecting to %s…" % ssid, "wifi")
	Sys.wifi_connect(ssid, pw, func(ok: bool, _out):
		if ok:
			shell.toast("Connected to %s" % ssid, "check", Tokens.OK)
		else:
			shell.toast("Couldn't connect. Check the password.", "info", Tokens.BAD)
		_fetch_async("network", true))

func _bt_scan() -> void:
	shell.toast("Searching for devices for 12 seconds…", "bluetooth")
	Sys.bt_power(true, func():
		Sys.bt_scan(12, func(): _fetch_async("bluetooth")))

func _bt_pressed(d: Dictionary) -> void:
	if d.connected:
		shell.confirm(d.name, "Connected", [["Disconnect", "close"], ["Forget", "trash"], ["Cancel", "close"]], func(i):
			if i == 0: Sys.bt_disconnect(d.mac, func(): _fetch_async("bluetooth"))
			elif i == 1: Sys.bt_forget(d.mac, func(): _fetch_async("bluetooth")))
	elif d.paired:
		shell.toast("Connecting to %s…" % d.name, "bluetooth")
		Sys.bt_connect(d.mac, func(ok, _o):
			shell.toast(("Connected to %s" % d.name) if ok else "Couldn't connect. Is it switched on?", "bluetooth", Tokens.OK if ok else Tokens.BAD)
			_fetch_async("bluetooth"))
	else:
		shell.toast("Pairing with %s…" % d.name, "bluetooth")
		Sys.bt_pair(d.mac, func(ok, _o):
			shell.toast(("Paired with %s" % d.name) if ok else "Pairing failed. Put the device in pairing mode and try again.", "bluetooth", Tokens.OK if ok else Tokens.BAD)
			_fetch_async("bluetooth"))

# ------------------------------------------------------------------ input
func nav_action(a: StringName) -> bool:
	if _side == 0:
		match a:
			&"up", &"down":
				if _cats.handle(a):
					_pending_cat = _cats.index
					_show_cat(_cats.index)
				return true
			&"right", &"accept":
				if _rows.rows.is_empty():
					return true
				_side = 1
				_cats.set_active(false)
				_rows.set_active(true)
				_cats.focused_row().set_focused(true)
				Sfx.confirm()
				shell.refresh_hints()
				return true
		return false
	# rows side
	if a == &"back" or (a == &"left" and _rows.focused_row() and _rows.focused_row().kind in ["action", "info", "header"]):
		_side = 0
		_rows.set_active(false)
		_cats.set_active(true)
		Sfx.back()
		shell.refresh_hints()
		return true
	if _rows.handle(a):
		_after_change()
		return true
	return true

func _import_roms() -> void:
	shell.toast("Looking for a USB drive…", "storage")
	Sys.usb_drives(func(list: Array):
		if list.is_empty():
			shell.toast("Plug in a USB drive with your game files", "info", Tokens.WARN)
			return
		var d: Dictionary = list[0]
		var go := func(mount: String):
			var n := RetroLib.import_from(mount)
			shell.toast("Imported %d game%s" % [n, "" if n == 1 else "s"], "check" if n > 0 else "info", Tokens.OK if n > 0 else Tokens.WARN)
			SteamLib.rescan()
		if d.mount != "":
			go.call(d.mount)
		else:
			Sys.run("udisksctl", ["mount", "-b", d.path, "--no-user-interaction"], func(t: String, c: int):
				var at := t.find(" at ")
				if c == 0 and at != -1:
					go.call(t.substr(at + 4).strip_edges().trim_suffix("."))
				else:
					shell.toast("Couldn't open the USB drive", "info", Tokens.BAD)))

func _after_change() -> void:
	var r := _rows.focused_row()
	if r and r.key == "ui.preset":
		Sys.apply_preset(Config.get_s("ui.preset"))
	if r and r.key == "display.ui_scale":
		get_tree().root.content_scale_factor = Config.get_f("display.ui_scale")

func hints() -> Array:
	if _side == 0:
		return [["A", "Open"], ["LB+RB", "Switch"]]
	return [["A", "Select"], ["◀▶", "Change"], ["B", "Back"]]

func on_enter(_dir: int) -> void:
	_side = 0
	_cats.set_active(true)
	_rows.set_active(false)
	if CATS[_cat][0] in ["controllers", "storage", "system"]:
		_show_cat(_cat, true)
	else:
		_fetch_async(CATS[_cat][0])

func on_leave() -> void:
	_cats.set_active(false)
	_rows.set_active(false)

func tick(dt: float) -> void:
	var x := _panel_x.step(dt)
	var a := _panel_a.step(dt)
	_rows.position.x = 16 + x
	_rows.modulate.a = clampf(a, 0.0, 1.0)
	_cat_title.position.x = 44 + x * 0.5
