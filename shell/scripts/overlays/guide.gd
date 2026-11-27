class_name GuideOverlay
extends Overlay
## Quick menu (Guide / Home button): a glass sheet that springs in from the right.
## Power, performance, overlay, volume and quick toggles, one press away.

var _list: RowList
var _sheet: GlassPanel
var _time: Label
var _date: Label
var _volume := 0.5

func build() -> void:
	from_offset = Vector2(640, 0)
	open_scale = 1.0
	_sheet = GlassPanel.new()
	_sheet.name = "content"
	_sheet.radius = 44
	_sheet.shadow = 1.0
	_sheet.body_dim = 0.88
	_sheet.glow_scale = 0.7
	_sheet.tint_boost = 0.04
	_sheet.size = Vector2(620, 1080 - 80)
	add_child(_sheet)
	_time = Tokens.label("", 64, 250, Tokens.clock_color())
	_time.position = Vector2(42, 30)
	_sheet.add_child(_time)
	_date = Tokens.label("", 21, 500, Tokens.INK_DIM)
	_date.position = Vector2(46, 112)
	_sheet.add_child(_date)
	_list = RowList.new()
	_list.position = Vector2(18, 168)
	_list.size = Vector2(584, _sheet.size.y - 190)
	_sheet.add_child(_list)
	Sys.audio_status(func(st: Dictionary):
		_volume = st.volume
		_list.refresh_all())
	var vol := SettingRow.slider("Volume", "", 0.0, 1.0, 0.05, func(v): return "%d%%" % int(round(float(v) * 100.0)), "volume")
	vol.getter = func(): return _volume
	vol.setter = func(v):
		_volume = v
		Sys.set_volume(v)
	var rows: Array = [
		SettingRow.header("Play"),
		SettingRow.choice("FSR", "fsr.mode", GameSettings.FSR_CHOICES, "gauge", "From the next game start"),
		SettingRow.choice("Game overlay", "perf.overlay", [["off", "Off"], ["fps", "FPS only"], ["detailed", "Detailed"], ["full", "Everything"]], "chart"),
		SettingRow.toggle("Record benchmarks", "perf.logging", "timer"),
		vol,
		SettingRow.action("Downloads", func():
			close()
			shell.open_downloads(), "update", "", func(): return "%d active" % Downloads.active_count() if Downloads.active_count() > 0 else "None"),
		SettingRow.action("Take a screenshot", func():
			close()
			await get_tree().create_timer(0.5).timeout
			Session.screenshot(), "image"),
		SettingRow.header("Home"),
		SettingRow.action("Switch profile", func():
			close()
			shell.open_profiles(), "sparkle", "", func(): return str(Profiles.current().get("name", ""))),
		SettingRow.toggle("Widgets", "widgets.enabled", "widgets"),
		SettingRow.toggle("UI sounds", "feedback.sounds", "volume"),
		SettingRow.action("All settings", func():
			close()
			shell.go_tab(3), "gear"),
		SettingRow.header("Power"),
		SettingRow.action("Rest mode", func():
			close()
			Sys.power("suspend"), "moon", "Wake it with the Guide or power button"),
		SettingRow.action("Restart", func():
			shell.confirm("Restart the console?", "Steam will close first so your games can save.", [["Restart", "restart"], ["Cancel", "close"]], func(i): if i == 0: Sys.power("reboot")), "restart"),
		SettingRow.action("Power off", func():
			shell.confirm("Power off?", "Steam will close first so your games can save.", [["Power off", "power"], ["Cancel", "close"]], func(i): if i == 0: Sys.power("poweroff")), "power"),
		SettingRow.action("Steam Big Picture", func():
			shell.confirm("Switch to Steam Big Picture?", "FORGE comes back when you exit Big Picture.", [["Switch", "steam"], ["Cancel", "close"]], func(i): if i == 0: Sys.switch_to_big_picture()), "steam"),
	]
	_list.set_rows(rows)
	_list.set_active(true)

func _content_base() -> Vector2:
	return Vector2(size.x - _sheet.size.x - 40, 40)

func nav_action(a: StringName) -> bool:
	if a == &"back" or a == &"guide":
		close()
		return true
	_list.handle(a)
	return true

func hints() -> Array:
	return [["A", "Select"], ["◀▶", "Change"], ["B", "Close"]]

func animate(o: float, dt: float) -> void:
	super.animate(o, dt)
	var t := Time.get_datetime_dict_from_system()
	if Config.get_b("appearance.clock_24h"):
		_time.text = "%02d:%02d" % [t.hour, t.minute]
	else:
		_time.text = "%d:%02d %s" % [12 if t.hour % 12 == 0 else t.hour % 12, t.minute, "AM" if t.hour < 12 else "PM"]
	var days := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
	var months := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	_date.text = "%s, %d %s" % [days[t.weekday], t.day, months[t.month - 1]]
