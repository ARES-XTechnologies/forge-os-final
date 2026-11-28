class_name InGameMenu
extends Overlay
## The in-game guide (Guide button while playing). A smoked-glass sheet slides in from
## the left over the game: big tiles for Resume / Screenshot / Save clip / Quit game,
## then volume, performance, overlay, this game's FPS limit and quick actions.
## The game is paused while it's open (can be turned off for online games).

var _sheet: GlassPanel
var _tiles: Array = []
var _tile_list: FocusList
var _list: RowList
var _area := 0                 # 0 tiles, 1 list
var _time: Label
var _playing: Label
var _volume := 0.5
var _portrait: ColorRect

func build() -> void:
	from_offset = Vector2(-680, 0)
	open_scale = 1.0
	_sheet = GlassPanel.new()
	_sheet.name = "content"
	_sheet.radius = 44
	_sheet.ingame = true
	_sheet.glow_scale = 0.8
	_sheet.size = Vector2(640, 1000)
	add_child(_sheet)
	var g: Dictionary = Session.current
	_portrait = ColorRect.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/card_art.gdshader")
	_portrait.material = m
	_portrait.position = Vector2(36, 34)
	_portrait.size = Vector2(84, 126)
	m.set_shader_parameter("size", _portrait.size)
	m.set_shader_parameter("radius", 14.0)
	var tex := Art.get_tex(int(g.get("appid", 0)), "portrait")
	m.set_shader_parameter("has_art", tex != null)
	if tex:
		m.set_shader_parameter("art", tex)
		m.set_shader_parameter("art_size", Vector2(tex.get_size()))
	_sheet.add_child(_portrait)
	var name := Tokens.label(str(g.get("name", "Game")), 30, 700)
	name.position = Vector2(140, 44)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Tokens.fit(name, Vector2(460, 40))
	_sheet.add_child(name)
	_playing = Tokens.label("", 19, 500, Tokens.INK_DIM)
	_playing.position = Vector2(142, 90)
	_sheet.add_child(_playing)
	_time = Tokens.label("", 19, 500, Tokens.INK_FAINT)
	_time.position = Vector2(142, 120)
	_sheet.add_child(_time)

	var defs := [["Resume", "play", Tokens.ACCENT], ["Screenshot", "image", Tokens.ACCENT_2], ["Save clip", "timer", Tokens.GOLD], ["Quit game", "close", Tokens.BAD]]
	var x := 36.0
	for d in defs:
		var t := _tile(d[0], d[1], d[2])
		t.position = Vector2(x, 190)
		_sheet.add_child(t)
		_tiles.append(t)
		x += 142.0
	_tile_list = FocusList.new(_tiles, true)
	_tile_list.focus(0)

	_list = RowList.new()
	_list.position = Vector2(18, 340)
	_list.size = Vector2(604, 640)
	_sheet.add_child(_list)
	Sys.audio_status(func(st):
		_volume = st.volume
		_list.refresh_all())
	var vol := SettingRow.slider("Volume", "", 0.0, 1.0, 0.05, func(v): return "%d%%" % int(round(float(v) * 100.0)), "volume")
	vol.getter = func(): return _volume
	vol.setter = func(v):
		_volume = v
		Sys.set_volume(v)
	var appid := int(g.get("appid", 0))
	var fps := SettingRow.choice("FPS limit", "", [[-1, "Same as console"], [0, "Off"], [30, "30"], [40, "40"], [60, "60"], [90, "90"], [120, "120"], [144, "144"]], "timer", "This game · next start")
	fps.getter = func():
		var v = Config.game_get(appid, "fps", null)
		return -1 if v == null else int(v)
	fps.setter = func(v):
		Config.game_set(appid, "fps", null if int(v) < 0 else int(v))
		GameSettings.write_per_game_mangohud(appid)
	var rows: Array = [
		vol,
		SettingRow.choice("FSR", "fsr.mode", GameSettings.FSR_CHOICES, "gauge", "From the next game start"),
		SettingRow.choice("Overlay", "perf.overlay", [["off", "Off"], ["fps", "FPS only"], ["detailed", "Detailed"], ["full", "Everything"]], "chart", "Shows after a restart"),
		fps,
		SettingRow.toggle("Pause in menu", "ingame.pause", "moon", "Off for online games"),
		SettingRow.action("Downloads", func(): shell.open_downloads(), "update", "", func(): return "%d active" % Downloads.active_count() if Downloads.active_count() > 0 else "None"),
		SettingRow.action("Rest mode", func():
			close()
			Sys.power("suspend"), "moon", "The game waits while it sleeps"),
	]
	if bool(Session.current.get("pointer", false)):
		# Apps made for a mouse: what each controller button does (Pointer service).
		var help := [["Left stick", "Move the pointer"], ["A", "Click (hold to drag)"], ["Right stick", "Scroll"],
			["Y", "Right-click"], ["X", "On-screen keyboard"], ["B", "Back"], ["Start", "Enter"], ["D-pad", "Arrow keys"]]
		rows.push_front(SettingRow.header(""))
		for i in range(help.size() - 1, -1, -1):
			var h: Array = help[i]
			rows.push_front(SettingRow.info(h[0], func(): return h[1], "controller"))
		rows.push_front(SettingRow.header("Controller mouse"))
	_list.set_rows(rows)
	_list.set_active(false)
	if Config.get_b("ingame.pause"):
		Session.pause()

func _tile(label: String, icon: String, col: Color) -> Control:
	var t := PillButton.new()
	t.text = ""
	t.icon_name = icon
	t.height = 120
	t.font_size = 30
	t.min_width = 128
	t.nested = true
	t.set_meta("label", label)
	t.set_meta("color", col)
	var l := Tokens.label(label, 16, 600, Tokens.INK_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tokens.fit(l, Vector2(128, 22))
	l.position = Vector2(0, 128)
	t.add_child(l)
	t.pressed.connect(_tile_pressed.bind(label))
	return t

func _tile_pressed(label: String) -> void:
	match label:
		"Resume":
			close()
		"Screenshot":
			close()
			await get_tree().create_timer(0.45).timeout
			Session.screenshot()
		"Save clip":
			Session.save_clip()
		"Quit game":
			shell.confirm("Quit %s?" % str(Session.current.get("name", "the game")), "Unsaved progress will be lost.", [["Quit game", "close"], ["Keep playing", "play"]], func(i):
				if i == 0:
					close()
					Session.quit_game())

func on_close() -> void:
	Session.resume()

func _content_base() -> Vector2:
	return Vector2(40, 40)

func nav_action(a: StringName) -> bool:
	if a == &"back" or a == &"guide":
		close()
		return true
	if _area == 0:
		if a == &"down":
			_area = 1
			_tile_list.set_active(false)
			_list.set_active(true)
			Sfx.focus_tick(2)
			return true
		if _tile_list.handle(a):
			return true
		if a == &"accept":
			_tile_list.press()
		return true
	if a == &"up" and _list.index == 0:
		_area = 0
		_list.set_active(false)
		_tile_list.set_active(true)
		Sfx.focus_tick(0)
		return true
	_list.handle(a)
	return true

func hints() -> Array:
	return [["A", "Select"], ["B", "Back to game"]]

func animate(o: float, dt: float) -> void:
	super.animate(o, dt)
	_playing.text = "Playing · " + Session.duration_text()
	var t := Time.get_datetime_dict_from_system()
	_time.text = "%02d:%02d" % [t.hour, t.minute] if Config.get_b("appearance.clock_24h") else "%d:%02d %s" % [12 if t.hour % 12 == 0 else t.hour % 12, t.minute, "AM" if t.hour < 12 else "PM"]
	for tl in _tiles:
		var b: PillButton = tl
		if b.focused:
			b.focus_color = b.get_meta("color")
