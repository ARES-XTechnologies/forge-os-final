extends Control
## FORGE OS entry point.
## Builds the wallpaper, the shell and the intro, and runs Game Mode:
##  • While a game is running the console UI stops drawing almost entirely so the game
##    gets the GPU, CPU and memory to itself.
##  • The UI's window becomes a transparent Gamescope overlay, so the in-game guide,
##    the "press Guide" hint and notifications can appear on top of the game.

var wallpaper: Wallpaper
var shell: Shell
var intro: Intro
var _playing := false
var _last_wall := 0.0
var _overlay_tagged := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--apply-pending"):
		# Headless helper mode: write queued Steam config changes while Steam is closed.
		GameSettings.apply_pending()
		# Let start-up work running on other threads finish before quitting (quitting
		# inside _ready crashed the engine on exit).
		set_process(false)
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0)
		return

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.content_scale_factor = Config.get_f("display.ui_scale")
	var mode_changed := Sys.write_session_conf()
	_last_wall = Time.get_unix_time_from_system()
	# The console is following the screen's own best mode and that just changed (first start
	# after an update that reads the screen better, or a new monitor): switch to it now, once.
	var rt := OS.get_environment("XDG_RUNTIME_DIR")
	if mode_changed and OS.get_environment("FORGE_SESSION") == "1" and not Config.get_b("display.custom") and rt != "" and not FileAccess.file_exists(rt + "/forge-mode-switched"):
		var g := FileAccess.open(rt + "/forge-mode-switched", FileAccess.WRITE)
		if g:
			g.close()
			get_tree().create_timer(1.5).timeout.connect(Sys.restart_session)

	wallpaper = Wallpaper.new()
	add_child(wallpaper)

	shell = Shell.new()
	shell.wallpaper = wallpaper
	add_child(shell)

	Session.started.connect(_on_game_started)
	Session.ended.connect(_on_game_ended)
	# CPU and GPU are always at full speed (forge-tune at start-up); nothing to set here.

	var skip := args.has("--no-intro") or not Config.get_b("appearance.intro")
	if skip:
		shell.reveal()
		_after_reveal()
	else:
		wallpaper.reveal.snap(0.0)
		intro = Intro.new()
		add_child(intro)
		for a in args:
			if a.begins_with("--intro-at="):
				var at := float(a.substr(11))
				get_tree().process_frame.connect(func(): if is_instance_valid(intro) and intro._t < at: intro.fast_forward(at), CONNECT_ONE_SHOT)
		intro.finished.connect(func():
			wallpaper.reveal.target = 1.0
			shell.reveal()
			_after_reveal())

	_dev_args()

func _after_reveal() -> void:
	await get_tree().create_timer(0.9).timeout
	if OS.get_cmdline_user_args().has("--no-setup"):
		return
	if not Config.get_b("system.first_run_done"):
		shell.open_setup()
	elif Profiles.list.size() > 1:
		shell.open_profiles(true)

# ------------------------------------------------------------------ game mode
func _on_game_started(_g: Dictionary) -> void:
	if _playing:
		return
	_playing = true
	shell.set_game_mode(true)
	# Let the launch zoom finish, then hand the screen to the game.
	await get_tree().create_timer(0.7).timeout
	if _playing:
		_enter_game_mode()

func _on_game_ended(_g: Dictionary) -> void:
	if not _playing:
		return
	_playing = false
	_exit_game_mode()
	shell.set_game_mode(false)

func _enter_game_mode() -> void:
	wallpaper.visible = false
	wallpaper.set_process(false)
	shell.set_ingame(true)
	get_viewport().transparent_bg = true
	get_window().transparent = true
	_tag_overlay(true)
	Nav.passthrough = true
	_idle(true)
	Config.save_now()
	shell.game_hint.show_hint()

func _exit_game_mode() -> void:
	_idle(false)
	Nav.passthrough = false
	_tag_overlay(false)
	get_viewport().transparent_bg = false
	wallpaper.visible = true
	wallpaper.set_process(true)
	shell.set_ingame(false)

## Barely-awake mode while a game runs: a few checks a second, nothing redrawn.
func _idle(on: bool) -> void:
	Engine.max_fps = 12 if on else 0
	OS.low_processor_usage_mode = on
	OS.low_processor_usage_mode_sleep_usec = 60000

## While the in-game menu is open we need full frame rate for smooth animation.
func set_menu_awake(on: bool) -> void:
	if not _playing:
		return
	_idle(not on)
	Nav.passthrough = not on

## Mark our window as a Gamescope external overlay so it's drawn on top of the game.
func _tag_overlay(on: bool) -> void:
	if not Sys.is_linux or not Sys.has_cmd("xprop") or on == _overlay_tagged:
		return
	var wid := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
	if wid == 0:
		return
	_overlay_tagged = on
	if on:
		Sys.run("xprop", ["-id", str(wid), "-f", "GAMESCOPE_EXTERNAL_OVERLAY", "32c", "-set", "GAMESCOPE_EXTERNAL_OVERLAY", "1"])
	else:
		Sys.run("xprop", ["-id", str(wid), "-remove", "GAMESCOPE_EXTERNAL_OVERLAY"])

# ------------------------------------------------------------------ wake from rest mode
func _process(_dt: float) -> void:
	var now := Time.get_unix_time_from_system()
	if now - _last_wall > 8.0 and shell:
		shell.wake()
	_last_wall = now

# ------------------------------------------------------------------ dev helpers
## --screenshot=<path> --after=<seconds> [--tab=N] [--overlay=NAME] [--keys=a,b,c]
## Used to render reference frames during development.
func _dev_args() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := ""
	var after := 3.0
	var tab := -1
	var overlay := ""
	var keys: Array = []
	for a in args:
		if a.begins_with("--screenshot="): shot = a.substr(13)
		elif a.begins_with("--after="): after = float(a.substr(8))
		elif a.begins_with("--tab="): tab = int(a.substr(6))
		elif a.begins_with("--overlay="): overlay = a.substr(10)
		elif a.begins_with("--keys="): keys = a.substr(7).split(",")
	if shot == "":
		return
	await get_tree().create_timer(minf(after, 1.0)).timeout
	if tab >= 0:
		shell.go_tab(tab)
	match overlay:
		"guide": shell.open_guide()
		"game":
			if not SteamLib.games.is_empty():
				shell.open_game(SteamLib.recent(1)[0])
		"keyboard": shell.open_keyboard("Password for Home-WiFi", "forge", false, func(_t): pass)
		"bench": shell.open_benchmarks()
		"search": shell.open_search()
		"dialog": shell.confirm("Power off?", "Steam will close first so your games can save.", [["Power off", "power"], ["Cancel", "close"]], func(_i): pass)
		"toast": Shellbus.notify({"title": "Achievement unlocked", "body": "Into the Ashes  ·  4.2% of players", "icon": "star_filled", "color": Tokens.GOLD, "sound": "achievement"})
		"toast2":
			shell.toast("Settings saved", "check", Tokens.OK)
			shell.toast("Couldn't open the drive: it uses a file system FORGE can't read yet", "info", Tokens.BAD)
			Shellbus.notify({"title": "Updating FORGE OS", "body": "Keep the console on. It restarts by itself when done.", "icon": "update", "color": Tokens.ACCENT, "duration": 8.0})
			Shellbus.notify({"title": "FORGE OS updated", "body": "Drivers update next time. Restarting the console UI…", "icon": "check", "color": Tokens.OK})
		"setup": shell.open_setup()
		"profiles": shell.open_profiles(true)
		"downloads": shell.open_downloads()
		"picker": shell.open_add_game()
		"addgame":
			var ag := AddGameOverlay.new()
			ag.path = "/root/Games/Hollow Realm/Binaries/Win64/Game-Win64-Shipping.exe"
			shell.push_overlay(ag)
		"achievements":
			var list := SteamLib.recent(1)
			if not list.is_empty():
				shell.open_achievements(list[0], _fake_achievements())
		"gamesettings":
			if not SteamLib.games.is_empty():
				shell.open_game_settings(SteamLib.recent(1)[0])
		"ingame":
			Session.current = SteamLib.recent(1)[0] if not SteamLib.games.is_empty() else {"name": "Game", "appid": 0}
			Session.started_ms = Time.get_ticks_msec() - 4380000
			shell.set_ingame(true)
			wallpaper.visible = false
			shell.game_hint.show_hint()
			shell.open_ingame_menu()
		"hint":
			Session.current = SteamLib.recent(1)[0] if not SteamLib.games.is_empty() else {"name": "Game", "appid": 0}
			shell.set_ingame(true)
			wallpaper.visible = false
			shell.game_hint.show_hint()
	for k in keys:
		await get_tree().create_timer(0.12).timeout
		Nav._fire(StringName(k))
	await get_tree().create_timer(maxf(0.2, after - minf(after, 1.0))).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot)
	print("FORGE: saved ", shot)
	get_tree().quit()

func _fake_achievements() -> Dictionary:
	var names := ["First Steps", "Into the Ashes", "Crown of Embers", "Untouchable", "Collector", "Night Rider", "Master Smith", "The Long Road", "Perfectionist", "Secret Ending"]
	var list := []
	for i in names.size():
		list.append({"api": str(i), "name": names[i], "desc": "Finish a chapter without taking damage." if i % 2 else "Reach the forge at the heart of the mountain.",
			"icon": "", "icon_gray": "", "hidden": i == 9, "achieved": i < 6, "time": int(Time.get_unix_time_from_system()) - i * 86400 * 3, "percent": [71.2, 54.0, 23.5, 4.2, 12.8, 33.1, 8.9, 2.1, 1.4, 0.6][i]})
	return {"total": list.size(), "unlocked": 6, "list": list}
