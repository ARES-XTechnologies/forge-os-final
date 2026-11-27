extends Node
## User settings, one file per profile. Flat dotted keys, saved as JSON.
## Emits `changed(key)` on every write, and for every key when a profile is loaded.

signal changed(key: String)
signal profile_loaded()

const LEGACY_PATH := "user://settings.json"

const DEFAULTS := {
	# Display (applied by the session on restart)
	"display.width": 0,                    # 0 = the screen's native resolution
	"display.height": 0,
	"display.refresh": 0,                  # 0 = the screen's highest refresh rate (e.g. 220 Hz)
	"display.custom": false,               # true once you pick a mode yourself in Settings
	"display.hdr": false,
	"display.vrr": false,
	"display.ui_scale": 1.0,
	# Appearance
	"appearance.wallpaper": "ribbons",    # ribbons, nebula, silk, caustics, northern, orbs, photo
	"appearance.wallpaper_photo": "",
	"appearance.wallpaper_soften": 0.0,
	"appearance.palette": "aurora",
	"appearance.wallpaper_animated": true,
	"appearance.wallpaper_speed": 1.0,
	"appearance.wallpaper_intensity": 1.0,
	"appearance.dynamic": true,
	"appearance.glass_refraction": 1.0,
	"appearance.glass_tint": 0.10,
	"appearance.glass_dispersion": 1.0,
	"appearance.glass_brightness": 1.0,
	"appearance.glass_style": "liquid",   # liquid (clear, default), mist, frosted, matte
	"appearance.glow": false,
	"appearance.glow_color": "adaptive",
	"appearance.glow_strength": 0.8,      # 1.0 = full (the original brightness)
	"appearance.glow_motion": true,
	"appearance.clock_color": "white",
	"appearance.clock_hue": 0.6,
	"appearance.clock_24h": true,
	"appearance.clock_seconds": false,
	"appearance.clock_size": 1.0,
	"appearance.intro": true,
	"appearance.parallax": true,
	"ui.preset": "ultra",
	# Motion & feedback
	"motion.speed": 1.0,
	"motion.reduce": false,
	"motion.bounce": 1.0,
	"feedback.sounds": true,
	"feedback.sound_theme": "crystal",
	"feedback.volume": 0.7,
	"feedback.haptics": true,
	"feedback.haptic_strength": 0.5,
	# Widgets
	"widgets.enabled": false,
	"widgets.side": "right",
	"widgets.clock": true,
	"widgets.date": true,
	"widgets.system": true,
	"widgets.storage": false,
	"widgets.session": true,
	"widgets.controllers": true,
	"widgets.network": false,
	"widgets.recent": false,
	"widgets.playtime": false,
	"widgets.calendar": false,
	# Controllers
	"input.deadzone": 0.35,
	"input.repeat_delay": 0.32,
	"input.repeat_rate": 0.075,
	"input.swap_ab": false,
	# Library
	"library.sort": "recent",
	"library.filter": "all",
	"library.favorites": [],
	"library.hidden": [],
	"library.show_uninstalled": true,
	"library.heroic": true,
	"library.retro": true,
	"library.badges": true,
	"library.last_folder": "",
	"library.external_stats": {},
	"steam.api_key": "",
	# Per-game
	"games.exe": {},
	"games.settings": {},
	# In game
	"ingame.pause": true,
	"ingame.hint": true,
	"ingame.achievement_toasts": true,
	# Capture
	"capture.clips": false,
	"capture.clip_length": 30,
	# Performance & benchmark
	"fsr.mode": "off",                     # off (default), fidelity, balanced, performance, ultra: FSR for every game
	"perf.overlay": "off",          # off | fps | detailed | full
	"perf.overlay_position": "top-left",
	"perf.logging": false,
	"perf.log_duration": 0,          # 0 = until stopped
	"perf.fps_limit": 0,
	"perf.shell_overlay": false,
	# Updates
	"update.repo": "",
	"update.token": "",
	"update.auto_check": true,
	"update.last_check": 0,
	"update.available": "",
	# System
	"system.first_run_done": false,
}

var _data := {}
var _save_pending := false
var path := LEGACY_PATH

func _ready() -> void:
	_data = DEFAULTS.duplicate(true)
	# Profiles pick the file; before that, load the legacy/single-user file.
	_load_file(LEGACY_PATH)

func _load_file(p: String) -> void:
	path = p
	_data = DEFAULTS.duplicate(true)
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for k in parsed:
					if not DEFAULTS.has(k):
						continue
					var a = parsed[k]
					var b = DEFAULTS[k]
					if typeof(a) == typeof(b) or (_numeric(a) and _numeric(b)):
						_data[k] = a
	# Until you choose a mode yourself, the console always follows the screen's own best mode
	# (older versions saved a fixed 1920x1080 at 60 Hz here).
	if not bool(_data.get("display.custom", false)):
		_data["display.width"] = 0
		_data["display.height"] = 0
		_data["display.refresh"] = 0

## Switch to another profile's settings file.
func load_profile_file(p: String) -> void:
	save_now()
	_load_file(p)
	for k in _data:
		changed.emit(k)
	profile_loaded.emit()

func _numeric(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

func get_v(key: String):
	return _data.get(key, DEFAULTS.get(key))

func get_b(key: String) -> bool:
	return bool(get_v(key))

func get_f(key: String) -> float:
	return float(get_v(key))

func get_i(key: String) -> int:
	return int(get_v(key))

func get_s(key: String) -> String:
	return str(get_v(key))

func set_v(key: String, value) -> void:
	if _data.get(key) == value and typeof(value) != TYPE_DICTIONARY and typeof(value) != TYPE_ARRAY:
		return
	_data[key] = value
	changed.emit(key)
	_queue_save()

func reset_all() -> void:
	var keep_done := get_b("system.first_run_done")
	_data = DEFAULTS.duplicate(true)
	_data["system.first_run_done"] = keep_done
	for k in _data:
		changed.emit(k)
	_queue_save()

func toggle_in_list(key: String, item) -> bool:
	var arr: Array = (get_v(key) as Array).duplicate()
	var on := not arr.has(item)
	if on:
		arr.append(item)
	else:
		arr.erase(item)
	set_v(key, arr)
	return on

## Per-game settings dictionary helpers.
func game_get(appid: int, key: String, default = null):
	var all: Dictionary = get_v("games.settings")
	return (all.get(str(appid), {}) as Dictionary).get(key, default)

func game_set(appid: int, key: String, value) -> void:
	var all: Dictionary = (get_v("games.settings") as Dictionary).duplicate(true)
	var g: Dictionary = all.get(str(appid), {})
	if value == null:
		g.erase(key)
	else:
		g[key] = value
	all[str(appid)] = g
	set_v("games.settings", all)

func _queue_save() -> void:
	if _save_pending:
		return
	_save_pending = true
	await get_tree().create_timer(0.4).timeout
	_save_pending = false
	save_now()

func save_now() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_data, "\t"))

## Global motion multiplier used by every Spring.
func anim_speed() -> float:
	if get_b("motion.reduce"):
		return 1.8
	return get_f("motion.speed")

## Bounce multiplier: lowers damping ratio when > 1, removes overshoot when reduced.
func bounce() -> float:
	return 0.0 if get_b("motion.reduce") else get_f("motion.bounce")
