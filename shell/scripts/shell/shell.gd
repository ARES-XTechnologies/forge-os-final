class_name Shell
extends Control
## The console shell: owns the top bar, the four main screens, overlays, toasts,
## widgets and the launch sequence. Main screens switch with LB / RB.

var wallpaper: Wallpaper
var top_bar: TopBar
var hint_bar: HintBar
var screens: Array[Screen] = []
var current := 0
var home: HomeScreen
var library: LibraryScreen
var media: MediaScreen
var settings: SettingsScreen
var widgets: WidgetDock
var toasts: Toasts
var launch_overlay: LaunchOverlay
var perf_overlay: PerfOverlay
var game_hint: GameHint
var ingame := false

var _screen_layer: Control
var _overlay_layer: Control
var _ui_alpha: Spring
var _ui_y: Spring
var _revealed := false
var _cover: Spring
var _dim: Spring
var _covers := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_alpha = Spring.preset(0.0, &"smooth")
	_ui_y = Spring.preset(30.0, &"bouncy")
	_cover = Spring.preset(0.0, &"smooth")
	_dim = Spring.preset(0.0, &"smooth")

	_screen_layer = Control.new()
	_screen_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen_layer)

	home = HomeScreen.new()
	library = LibraryScreen.new()
	media = MediaScreen.new()
	settings = SettingsScreen.new()
	for s in [home, library, media, settings]:
		s.shell = self
		s.visible = false
		_screen_layer.add_child(s)
		screens.append(s)

	widgets = WidgetDock.new()
	widgets.shell = self
	add_child(widgets)

	# Top bar sits above a fresh back-buffer copy so its glass refracts the hero art.
	var bbc := BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bbc)
	top_bar = TopBar.new()
	top_bar.tab_clicked.connect(func(i):
		if Nav.is_top(self) and not ingame:
			go_tab(i))
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(top_bar)

	hint_bar = HintBar.new()
	add_child(hint_bar)

	var bbc2 := BackBufferCopy.new()
	bbc2.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bbc2)
	_overlay_layer = Control.new()
	_overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_layer)

	launch_overlay = LaunchOverlay.new()
	launch_overlay.shell = self
	add_child(launch_overlay)
	toasts = Toasts.new()
	add_child(toasts)
	perf_overlay = PerfOverlay.new()
	add_child(perf_overlay)
	game_hint = GameHint.new()
	add_child(game_hint)

	resized.connect(_layout)
	_layout()
	modulate.a = 0.0
	Session.captured.connect(_on_captured)

func _on_captured(kind: String, path: String) -> void:
	if kind == "screenshot":
		var tex: Texture2D = null
		var img := Image.new()
		if img.load(path) == OK:
			img.resize(128, int(128.0 * img.get_height() / maxf(1.0, img.get_width())), Image.INTERPOLATE_BILINEAR)
			tex = ImageTexture.create_from_image(img)
		Shellbus.notify({"title": "Screenshot saved", "body": "Find it in Media", "icon": "image", "image": tex, "color": Tokens.ACCENT_2, "sound": "notify", "duration": 3.0})
	else:
		Shellbus.notify({"title": "Clip saved", "body": path + " · find it in Media", "icon": "timer", "color": Tokens.GOLD, "duration": 3.5})

func _layout() -> void:
	hint_bar.position = Vector2(Tokens.SAFE_X, size.y - 76)

## Called by the intro (or immediately when the intro is off).
func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	_ui_alpha.target = 1.0
	_ui_y.target = 0.0
	Nav.push(self)
	screens[0].enter(0)
	_refresh_hints()
	widgets.refresh()

## Full-screen pages (game details) hide the screens, top bar and widgets behind them.
func cover(on: bool) -> void:
	_covers = maxi(0, _covers + (1 if on else -1))
	_cover.target = 1.0 if _covers > 0 else 0.0

func _process(dt: float) -> void:
	var a := _ui_alpha.step(dt)
	modulate.a = clampf(a, 0.0, 1.0)
	var cv := clampf(_cover.step(dt), 0.0, 1.0)
	var under := 1.0 - cv
	var dm := clampf(_dim.step(dt), 0.0, 1.0) * 0.55
	_screen_layer.modulate = Color(1.0 - dm, 1.0 - dm, 1.0 - dm * 0.9, under)
	top_bar.modulate = Color(1.0 - dm * 0.6, 1.0 - dm * 0.6, 1.0 - dm * 0.6, under)
	_screen_layer.visible = under > 0.01 and not ingame
	widgets.self_modulate.a = under
	hint_bar.visible = not ingame and Config.get_b("appearance.hints")
	top_bar.position.y = _ui_y.step(dt) * 0.6
	hint_bar.position.y = size.y - 76 - _ui_y.value * 0.3

# ------------------------------------------------------------------ navigation
func nav_action(a: StringName) -> bool:
	match a:
		&"tab_prev":
			go_tab(current - 1)
			return true
		&"tab_next":
			go_tab(current + 1)
			return true
		&"guide", &"start":
			if Session.is_playing():
				open_ingame_menu()
			else:
				open_guide()
			return true
	var s := screens[current]
	if s.nav_action(a):
		_refresh_hints()
		return true
	if a == &"back" and current != 0:
		go_tab(0)
		return true
	return false

func go_tab(i: int) -> void:
	if i < 0 or i >= screens.size():
		Sfx.play("edge")
		return
	if i == current:
		return
	var dir := 1 if i > current else -1
	screens[current].leave(dir)
	current = i
	screens[i].enter(dir)
	top_bar.set_tab(i)
	Sfx.play("tab")
	Sfx.haptic(0.25, 0.0, 30)
	_refresh_hints()
	widgets.set_screen(i)

func _refresh_hints() -> void:
	# Whatever is in front owns the hint bar: an open menu beats the screen behind it.
	var kids := _overlay_layer.get_children()
	for i in range(kids.size() - 1, -1, -1):
		var o = kids[i]
		if o is Overlay and not o.is_queued_for_deletion():
			hint_bar.set_hints(o.hints())
			return
	hint_bar.set_hints(screens[current].hints())

func refresh_hints() -> void:
	_refresh_hints()

# ------------------------------------------------------------------ overlays
func push_overlay(o: Control) -> void:
	if "shell" in o:
		o.shell = self
	_overlay_layer.add_child(o)
	wallpaper.dim.target = 1.0
	_dim.target = 1.0

func overlay_closed() -> void:
	# Remove the dim only when no overlay is left.
	await get_tree().process_frame
	var any := false
	for c in _overlay_layer.get_children():
		if not c.is_queued_for_deletion():
			any = true
	if not any:
		wallpaper.dim.target = 0.0
		_dim.target = 0.0
		if ingame:
			(get_parent() as Node).call("set_menu_awake", false)
	_refresh_hints()

func open_guide() -> void:
	for c in _overlay_layer.get_children():
		if c is GuideOverlay:
			return
	var g := GuideOverlay.new()
	g.shell = self
	push_overlay(g)

func open_game(game: Dictionary) -> void:
	var p := GamePage.new()
	p.shell = self
	p.game = game
	push_overlay(p)

func open_search() -> void:
	var s := SearchOverlay.new()
	s.shell = self
	push_overlay(s)

func open_keyboard(title: String, initial: String, secret: bool, on_done: Callable, on_change := Callable()) -> Keyboard:
	var k := Keyboard.new()
	k.title = title
	k.text = initial
	k.secret = secret
	k.on_done = on_done
	k.on_change = on_change
	push_overlay(k)
	return k

func confirm(title: String, body: String, options: Array, cb: Callable) -> void:
	var d := Dialog.new()
	d.ingame = ingame
	d.title = title
	d.body = body
	d.options = options
	d.callback = cb
	push_overlay(d)

func open_benchmarks() -> void:
	var b := BenchmarkScreen.new()
	b.shell = self
	push_overlay(b)

func toast(text: String, icon := "info", color := Tokens.ACCENT) -> void:
	toasts.show_toast(text, icon, color)

func open_ingame_menu() -> void:
	for c in _overlay_layer.get_children():
		if c is InGameMenu and not c.closing:
			return
	(get_parent() as Node).call("set_menu_awake", true)
	var m := InGameMenu.new()
	push_overlay(m)

func open_setup() -> void:
	push_overlay(SetupOverlay.new())

func open_profiles(picker := false) -> void:
	var p := ProfilePicker.new()
	p.startup = picker
	push_overlay(p)

func open_downloads() -> void:
	push_overlay(DownloadsOverlay.new())

func open_achievements(game: Dictionary, preset: Dictionary = {}) -> void:
	var a := AchievementsOverlay.new()
	a.game = game
	a.preset = preset
	push_overlay(a)

## "Add a game": browse for the file, then name it, pick art and Proton.
func open_add_game() -> void:
	var fp := FilePicker.new()
	fp.title = "Add a game"
	fp.on_pick = func(path: String):
		var ag := AddGameOverlay.new()
		ag.path = path
		push_overlay(ag)
	push_overlay(fp)

## Pick a photo for the wallpaper. It's copied into FORGE, so unplugging the drive later
## doesn't lose it.
func open_photo_picker() -> void:
	var fp := FilePicker.new()
	fp.title = "Choose a photo"
	fp.accept_exts = PackedStringArray(["jpg", "jpeg", "png", "webp"])
	fp.on_pick = func(path: String):
		var dest_dir := ProjectSettings.globalize_path("user://wallpapers")
		DirAccess.make_dir_recursive_absolute(dest_dir)
		var dest := dest_dir.path_join("photo-%d.%s" % [Time.get_unix_time_from_system(), path.get_extension().to_lower()])
		if DirAccess.copy_absolute(path, dest) != OK or Image.load_from_file(dest) == null:
			toast("That photo couldn't be opened. Try a JPG or PNG.", "image", Tokens.BAD)
			return
		var old := Config.get_s("appearance.wallpaper_photo")
		Config.set_v("appearance.wallpaper_photo", dest)
		Config.set_v("appearance.wallpaper", "photo")
		if old != "" and old != dest and old.begins_with(dest_dir):
			DirAccess.remove_absolute(old)
		toast("Wallpaper set", "image", Tokens.OK)
	push_overlay(fp)

func open_edit_game(id: int) -> void:
	var ag := AddGameOverlay.new()
	ag.edit_id = id
	push_overlay(ag)

func open_game_settings(game: Dictionary) -> void:
	if str(game.get("source", "steam")) in ["local", "usb"]:
		open_edit_game(int(game.appid))
		return
	var g := GameSettingsOverlay.new()
	g.game = game
	push_overlay(g)

## Game mode: everything but notifications, the hint and the in-game menu disappears.
func set_ingame(on: bool) -> void:
	ingame = on
	_screen_layer.visible = not on
	top_bar.visible = not on
	hint_bar.visible = not on and Config.get_b("appearance.hints")
	widgets.visible = not on
	perf_overlay.visible = not on
	toasts.ingame = on

## Back from rest mode: the world fades up and the UI drops in.
func wake() -> void:
	if ingame:
		return
	wallpaper.reveal.snap(0.0)
	wallpaper.reveal.target = 1.0
	_ui_y.snap(50.0)
	_ui_y.target = 0.0
	_ui_alpha.snap(0.0)
	_ui_alpha.target = 1.0
	screens[current].enter(0)
	Sfx.play("wake")
	SteamLib.rescan()

# ------------------------------------------------------------------ launching
func launch(game: Dictionary, card: Control = null) -> void:
	if game.is_empty():
		return
	if game.get("missing", false):
		Shellbus.notify({"title": "Can't find " + str(game.name), "body": "Plug in the drive it's on, then try again.", "icon": "storage", "color": Tokens.WARN})
		Sfx.play("error")
		return
	if game.get("updating", false):
		toast("%s is still downloading" % game.name, "update", Tokens.WARN)
		Sfx.play("error")
		return
	if not game.get("installed", true):
		confirm("Install %s?" % game.name, "It downloads in the background. You can keep playing other games.",
			[["Install", "update"], ["Not now", "close"]], func(i):
				if i == 0:
					if Session.is_playing():
						SteamLib.install(int(game.appid))
					else:
						SteamLib.install_quiet(int(game.appid))
					Shellbus.notify({"title": "Download starting", "body": str(game.name) + " · Steam is getting it ready", "icon": "update", "appid": game.appid}))
		return
	Sfx.play("launch")
	Sfx.haptic(0.5, 0.4, 120)
	launch_overlay.start(game, card)
	SteamLib.play(game)

## Main calls this when a game starts or stops.
func set_game_mode(playing: bool) -> void:
	for s in screens:
		s.on_game_mode(playing)
	if playing:
		launch_overlay.game_started()
		for c in _overlay_layer.get_children():
			if c is Overlay and not (c is InGameMenu):
				c.close()
	else:
		launch_overlay.hide_now()
		# Welcome back: the UI drops in again.
		_ui_y.snap(40.0)
		_ui_y.target = 0.0
		_ui_alpha.snap(0.0)
		_ui_alpha.target = 1.0
		screens[current].enter(0)
		SteamLib.rescan()
