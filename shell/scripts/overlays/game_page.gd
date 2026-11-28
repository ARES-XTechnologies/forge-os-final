class_name GamePage
extends Overlay
## Full-screen game details: hero art, logo, stats, and actions.

const HERO_SHADER := preload("res://shaders/hero.gdshader")

var game: Dictionary
var _hero: ColorRect
var _hero_mat: ShaderMaterial
var _logo: TextureRect
var _title: Label
var _buttons: FocusList
var _stats: Array[Control] = []
var _fav_btn: PillButton
var _hide_btn: PillButton
var _drift := 0.0
var _stat_springs: Array[Spring] = []
var _ach_btn: PillButton

func build() -> void:
	covers_screen = true
	from_offset = Vector2(0, 120)
	open_scale = 0.97
	_hero = ColorRect.new()
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_mat = ShaderMaterial.new()
	_hero_mat.shader = HERO_SHADER
	_hero_mat.set_shader_parameter("bottom_fade", 1.05)
	_hero.material = _hero_mat
	_hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_hero)

	var content := Control.new()
	content.name = "content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	_logo = TextureRect.new()
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.size = Vector2(720, 260)
	content.add_child(_logo)
	_title = Tokens.label(game.get("name", ""), 84, 700)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	Tokens.fit(_title, Vector2(1000, 260))
	content.add_child(_title)

	var installed: bool = game.get("installed", true)
	var steam: bool = game.get("source", "steam") == "steam"
	var play := PillButton.make("Play" if installed else "Install", "play" if installed else "update", 76, 28)
	play.primary = true
	play.min_width = 220
	play.pressed.connect(func():
		close()
		shell.launch(game))
	var bench := PillButton.make("Play with benchmark", "chart", 76, 24)
	bench.pressed.connect(func():
		Config.set_v("perf.logging", true)
		if Config.get_s("perf.overlay") == "off":
			Config.set_v("perf.overlay", "detailed")
		shell.toast("Benchmark logging on — results appear in Settings › Performance", "chart")
		close()
		shell.launch(game))
	_fav_btn = PillButton.make("", "star", 76, 24)
	_fav_btn.pressed.connect(_toggle_fav)
	var verify := PillButton.make("", "wrench", 76, 24)
	verify.pressed.connect(func():
		SteamLib.verify(game.appid)
		shell.toast("Steam is checking the game files", "wrench"))
	_hide_btn = PillButton.make("", "eye_off", 76, 24)
	_hide_btn.pressed.connect(_toggle_hide)
	var uninstall := PillButton.make("", "trash", 76, 24)
	uninstall.pressed.connect(func():
		shell.confirm("Uninstall %s?" % game.name, "This frees %s. Your saves in Steam Cloud stay safe." % SteamLib.fmt_size(game.size),
			[["Uninstall", "trash"], ["Cancel", "close"]], func(i):
				if i == 0:
					SteamLib.uninstall(game.appid)
					shell.toast("Uninstalling %s" % game.name, "trash", Tokens.WARN)
					close()))
	var settings_btn := PillButton.make("", "gear", 76, 24)
	settings_btn.pressed.connect(func(): shell.open_game_settings(game))
	_ach_btn = PillButton.make("Achievements", "star", 76, 22)
	_ach_btn.pressed.connect(func(): shell.open_achievements(game))
	var row := [play]
	if installed:
		row.append(bench)
	if steam and SteamWeb.has_key():
		row.append(_ach_btn)
		SteamWeb.achievements(int(game.appid), func(d: Dictionary):
			if d.is_empty():
				_ach_btn.text = "No achievements"
			else:
				_ach_btn.text = "%d / %d" % [d.unlocked, d.total])
	row.append(_fav_btn)
	if steam and installed:
		row += [settings_btn, verify]
	elif str(game.get("source", "")) in ["local", "usb"]:
		row.append(settings_btn)
	row.append(_hide_btn)
	if steam and installed:
		row.append(uninstall)
	for b in row:
		(b as PillButton).nested = true
	var x := 0.0
	for b in row:
		content.add_child(b)
		b.position = Vector2(x, 440)
		x += b.size.x + 18.0
	_buttons = FocusList.new(row, true)
	_buttons.focus(0)
	_refresh_toggles()

	var stats := [
		["clock", "Playtime", SteamLib.fmt_playtime(game.playtime).replace(" played", "")],
		["calendar", "Last played", SteamLib.fmt_last_played(game.last_played).replace("Played ", "") if game.last_played > 0 else "Never"],
		["storage", "Size on disk", SteamLib.fmt_size(game.size) if game.get("installed", true) else "Not installed"],
		["info", "From", SteamLib.source_label(game)],
	]
	var sx := 0.0
	for s in stats:
		var card := GlassPanel.new()
		card.radius = 24
		card.size = Vector2(250, 112)
		card.position = Vector2(sx, 580)
		card.nested = true
		card.body_dim = 0.35
		var ic := Icon.make(s[0], 24, Tokens.INK_DIM)
		ic.position = Vector2(22, 22)
		card.add_child(ic)
		var cap := Tokens.label(s[1].to_upper(), 14, 600, Tokens.INK_FAINT)
		cap.position = Vector2(56, 24)
		card.add_child(cap)
		var val := Tokens.label(s[2], 26, 600)
		val.position = Vector2(22, 56)
		val.clip_text = true
		val.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		Tokens.fit(val, Vector2(210, 34))
		card.add_child(val)
		content.add_child(card)
		_stats.append(card)
		var sp := Spring.preset(1.0, &"bouncy")
		_stat_springs.append(sp)
		sx += 270.0
	var where := ""
	if game.get("source", "steam") == "steam":
		where = ("Installed in " + str(game.get("library", "")) + "/steamapps/common/" + str(game.get("installdir", ""))) if game.get("installed", true) else "Owned on Steam · not installed"
	elif str(game.get("source", "")) in ["local", "usb"]:
		where = str(game.get("path", "")) + ("" if not game.get("missing", false) else "   ·   drive not connected")
	else:
		where = str(game.get("installdir", ""))
	var loc := Tokens.label(where, 17, 400, Tokens.INK_FAINT)
	loc.position = Vector2(4, 716)
	content.add_child(loc)
	content.size = Vector2(1700, 760)

	Art.art_ready.connect(_on_art)
	_apply_art()

func _on_art(appid: int, _k: String) -> void:
	if appid == game.appid:
		_apply_art()

func _apply_art() -> void:
	var hero := Art.get_tex(game.appid, "hero")
	if hero == null and Art.is_missing(game.appid, "hero"):
		hero = Art.get_tex(game.appid, "header")
	_hero_mat.set_shader_parameter("tex_a", hero)
	_hero_mat.set_shader_parameter("has_a", hero != null)
	if hero:
		_hero_mat.set_shader_parameter("size_a", Vector2(hero.get_size()))
	var logo := Art.get_tex(game.appid, "logo")
	_logo.texture = logo
	if logo:
		var k := minf(720.0 / logo.get_width(), 240.0 / logo.get_height())
		_logo.size = Vector2(logo.get_size()) * k
	_logo.visible = logo != null
	_title.visible = logo == null

func _content_base() -> Vector2:
	return Vector2(Tokens.SAFE_X, 120)

func _toggle_fav() -> void:
	var on := Config.toggle_in_list("library.favorites", game.appid)
	shell.toast("Added to favourites" if on else "Removed from favourites", "star_filled" if on else "star", Tokens.GOLD)
	_refresh_toggles()

func _toggle_hide() -> void:
	var on := Config.toggle_in_list("library.hidden", game.appid)
	shell.toast("Hidden from your library" if on else "Back in your library", "eye_off")
	_refresh_toggles()

func _refresh_toggles() -> void:
	var favs: Array = Config.get_v("library.favorites")
	_fav_btn.icon_name = "star_filled" if favs.has(game.appid) else "star"
	_fav_btn.selected = favs.has(game.appid)
	var hidden: Array = Config.get_v("library.hidden")
	_hide_btn.selected = hidden.has(game.appid)

func animate(o: float, dt: float) -> void:
	super.animate(o, dt)
	_drift += dt
	_hero_mat.set_shader_parameter("drift", _drift)
	_hero_mat.set_shader_parameter("view", size)
	_hero_mat.set_shader_parameter("strength", clampf(o, 0.0, 1.0))
	var bx := 0.0
	for b in _buttons.items:
		b.position.x = bx
		bx += b.size.x + 18.0
	_logo.position = Vector2(0, 400 - _logo.size.y)
	_title.position = Vector2(0, 400 - _title.size.y)
	for i in _stats.size():
		var sp := _stat_springs[i]
		if o > 0.4 + i * 0.08 and sp.target == 1.0 and not closing:
			sp.target = 0.0
		var v := sp.step(dt)
		_stats[i].position.y = 580 + v * 60.0
		_stats[i].modulate.a = clampf(1.0 - v, 0.0, 1.0)

func nav_action(a: StringName) -> bool:
	if _buttons.handle(a):
		return true
	match a:
		&"accept": _buttons.press()
		&"back": close()
		&"alt": _toggle_fav(); Sfx.play("toggle_on")
	return true

func hints() -> Array:
	return [["A", "Select"], ["X", "Favourite"], ["B", "Back"]]
