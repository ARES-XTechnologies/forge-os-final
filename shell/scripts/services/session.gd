extends Node
## Game sessions for every source (Steam, Epic/GOG via Heroic, RetroArch).
## Knows what's running, for how long, and can pause, resume and quit it,
## take screenshots and save clips from the replay buffer.

signal started(game: Dictionary)
signal ended(game: Dictionary)
signal captured(kind: String, path: String)     # "screenshot" | "clip"

var current: Dictionary = {}
var started_ms := 0
var paused := false
var _ext_pid := 0            # process we launched ourselves (RetroArch / Heroic)
var _ext_match := ""         # cmdline text that identifies an external game's processes
var _ext_poll := 0.0
var _rec_pid := 0            # gpu-screen-recorder replay buffer
var home := OS.get_environment("HOME")
var forge_game := "/opt/forge/system/forge-game"

func _ready() -> void:
	SteamLib.running_changed.connect(_on_steam_running)
	if not FileAccess.file_exists(forge_game):
		forge_game = ProjectSettings.globalize_path("res://").path_join("../system/forge-game").simplify_path()

func is_playing() -> bool:
	return not current.is_empty()

func minutes_played() -> int:
	return 0 if current.is_empty() else int((Time.get_ticks_msec() - started_ms) / 60000)

func duration_text() -> String:
	var s := 0 if current.is_empty() else int((Time.get_ticks_msec() - started_ms) / 1000)
	if s < 60: return "Just started"
	if s < 3600: return "%d min" % (s / 60)
	return "%dh %02dm" % [s / 3600, (s % 3600) / 60]

# ------------------------------------------------------------------ start / end
func _on_steam_running(appid: int) -> void:
	if appid != 0:
		if current.get("appid", 0) == appid:
			return
		var g: Dictionary = SteamLib.by_id.get(appid, {"appid": appid, "name": "Game", "source": "steam"})
		_begin(g)
	elif current.get("source", "steam") == "steam" and not current.is_empty():
		_finish()

## Launch a non-Steam game and track it until its processes are gone.
func launch_external(game: Dictionary, cmd: String, args: Array, match_text: String) -> void:
	if is_playing():
		return
	var pid := OS.create_process(cmd, PackedStringArray(args))
	if pid <= 0:
		Shellbus.notify({"title": "Couldn't start " + str(game.get("name", "the game")), "body": "Is it installed correctly?", "icon": "info", "color": Tokens.BAD})
		return
	_ext_pid = pid
	_ext_match = match_text
	_begin(game)

func _begin(g: Dictionary) -> void:
	current = g
	started_ms = Time.get_ticks_msec()
	paused = false
	started.emit(g)
	_start_replay_buffer()
	if g.get("source", "steam") == "steam":
		# learn the game's process name so per-game overlay / FPS settings can target it
		get_tree().create_timer(20.0).timeout.connect(_learn_exe.bind(int(g.get("appid", 0))))

func _finish() -> void:
	if current.is_empty():
		return
	var g := current
	if paused:
		resume()
	if g.get("source", "steam") != "steam":
		var stats: Dictionary = (Config.get_v("library.external_stats") as Dictionary).duplicate(true)
		var key := str(g.get("appid", 0))
		var st: Dictionary = stats.get(key, {"playtime": 0, "last_played": 0})
		st.playtime = int(st.get("playtime", 0)) + minutes_played()
		st.last_played = int(Time.get_unix_time_from_system())
		stats[key] = st
		Config.set_v("library.external_stats", stats)
	_stop_replay_buffer()
	Sys.fsr_reset()
	current = {}
	_ext_pid = 0
	_ext_match = ""
	ended.emit(g)

func _process(dt: float) -> void:
	if current.is_empty() or current.get("source", "steam") == "steam":
		return
	_ext_poll += dt
	if _ext_poll < 2.0:
		return
	_ext_poll = 0.0
	var alive := _ext_pid > 0 and OS.is_process_running(_ext_pid)
	if not alive and _ext_match != "":
		var out := []
		OS.execute("pgrep", PackedStringArray(["-f", _ext_match]), out)
		alive = not out.is_empty() and str(out[0]).strip_edges() != ""
	if not alive:
		_finish()

func _target() -> String:
	if current.get("source", "steam") == "steam":
		return str(current.get("appid", 0))
	if _ext_match != "":
		return "match:" + _ext_match
	return "pid:%d" % _ext_pid

func _learn_exe(appid: int) -> void:
	if current.get("appid", -1) != appid:
		return
	Sys.run(forge_game, ["exe", str(appid)], func(t: String, c: int):
		var exe := t.strip_edges()
		if c == 0 and exe != "":
			var map: Dictionary = (Config.get_v("games.exe") as Dictionary).duplicate()
			map[str(appid)] = exe
			Config.set_v("games.exe", map)
			GameSettings.write_per_game_mangohud(appid))

# ------------------------------------------------------------------ control
func pause() -> void:
	if current.is_empty() or paused:
		return
	paused = true
	Sys.run(forge_game, ["pause", _target()])

func resume() -> void:
	if not paused:
		return
	paused = false
	Sys.run(forge_game, ["resume", _target()])

func quit_game() -> void:
	if current.is_empty():
		return
	var g := current
	Sys.run(forge_game, ["quit", _target()], func(_t, _c):
		if current == g and g.get("source", "steam") != "steam":
			_finish())

# ------------------------------------------------------------------ capture
func _safe_name(n: String) -> String:
	var out := ""
	for ch in n:
		out += ch if (ch.is_valid_identifier() or ch in " -()[]0123456789") else ""
	out = out.strip_edges()
	return out if out != "" else "FORGE"

func screenshot() -> void:
	var game_name := _safe_name(str(current.get("name", "FORGE")))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var out := "%s/Pictures/FORGE/%s/%s.png" % [home, game_name, stamp]
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	Sfx.play("shutter")
	Sfx.haptic(0.4, 0.2, 60)
	if is_playing() and Sys.is_linux:
		Sys.run(forge_game, ["screenshot", out], func(_t, c: int):
			if c == 0:
				captured.emit("screenshot", out)
			else:
				Shellbus.notify({"title": "Screenshot failed", "body": "The game screen couldn't be captured.", "icon": "image", "color": Tokens.BAD}))
	else:
		# Not in a game: capture the console UI itself.
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(out)
		captured.emit("screenshot", out)

func clips_available() -> bool:
	return Sys.has_cmd("gpu-screen-recorder")

func _start_replay_buffer() -> void:
	if not Config.get_b("capture.clips") or not clips_available() or _rec_pid > 0:
		return
	var dir := "%s/Videos/FORGE/%s" % [home, _safe_name(str(current.get("name", "FORGE")))]
	DirAccess.make_dir_recursive_absolute(dir)
	var secs := str(Config.get_i("capture.clip_length"))
	_rec_pid = OS.create_process("gpu-screen-recorder", PackedStringArray([
		"-w", "screen", "-f", "60", "-r", secs, "-c", "mp4", "-q", "high",
		"-a", "default_output", "-o", dir]))

func _stop_replay_buffer() -> void:
	if _rec_pid > 0:
		OS.execute("kill", PackedStringArray(["-INT", str(_rec_pid)]))
		_rec_pid = 0

func save_clip() -> void:
	if _rec_pid <= 0:
		if not Config.get_b("capture.clips"):
			Shellbus.notify({"title": "Clips are off", "body": "Turn on clip recording in Settings › Capture.", "icon": "image", "color": Tokens.WARN})
		elif not clips_available():
			Shellbus.notify({"title": "Clips need the recorder", "body": "Install gpu-screen-recorder from Settings › System › Update.", "icon": "image", "color": Tokens.WARN})
		return
	OS.execute("kill", PackedStringArray(["-USR1", str(_rec_pid)]))
	Sfx.play("shutter", 0.8)
	Sfx.haptic(0.5, 0.3, 90)
	captured.emit("clip", "%d seconds saved" % Config.get_i("capture.clip_length"))
