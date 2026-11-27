extends Node
## System integration: network, audio, Bluetooth, power, display modes, updates,
## MangoHud (in-game performance overlay + logging) and session control.
## Every command runs on a worker thread; results come back on the main thread.

signal busy_changed(busy: bool)

const EXIT_RESTART_SESSION := 42
const EXIT_BIG_PICTURE := 43
const EXIT_POWEROFF := 44
const EXIT_REBOOT := 45

var home := OS.get_environment("HOME")
var conf_dir := home + "/.config/forge"
var bench_dir := home + "/.local/share/forge/bench"
var is_linux := OS.get_name() == "Linux"
var _running := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(conf_dir)
	DirAccess.make_dir_recursive_absolute(bench_dir)
	Config.changed.connect(_on_config)
	write_mangohud_conf()
	write_fsr_conf()

func _on_config(key: String) -> void:
	if key.begins_with("perf."):
		write_mangohud_conf()
	if key == "fsr.mode" or key == "games.settings":
		write_fsr_conf()

## FSR settings for forge-fsr, which every game starts through: the console-wide mode and
## each game's own choice. Read at launch, so changes apply from the next game start.
func write_fsr_conf() -> void:
	var f := FileAccess.open(conf_dir + "/fsr.conf", FileAccess.WRITE)
	if f:
		f.store_string("# Written by FORGE (Settings › Performance)\nMODE=%s\n" % Config.get_s("fsr.mode"))
		f.close()
	var lines := PackedStringArray()
	var all: Dictionary = Config.get_v("games.settings")
	for appid in all:
		var m := str((all[appid] as Dictionary).get("fsr", ""))
		if m in ["off", "fidelity", "balanced", "performance", "ultra"]:
			lines.append("%s=%s" % [appid, m])
	var g := FileAccess.open(conf_dir + "/fsr-games.conf", FileAccess.WRITE)
	if g:
		g.store_string("\n".join(lines) + "\n")

# ------------------------------------------------------------------ command runner
var _cbs := {}          # request id -> callback; callbacks never leave the main thread
var _tasks := {}        # request id -> WorkerThreadPool task id (must be collected)
var _next_id := 0

func run(cmd: String, args: Array, cb: Callable = Callable()) -> void:
	_running += 1
	busy_changed.emit(true)
	_next_id += 1
	var id := _next_id
	_cbs[id] = cb
	var a := PackedStringArray(args)
	var linux := is_linux
	# The background thread only gets the command and a ticket number, never the callback:
	# a callback released from that thread while FORGE was shutting down corrupted memory and
	# crashed FORGE on exit. The command may still be running when FORGE quits (a restart,
	# an update): only report back if FORGE is still here.
	var me := weakref(self)
	_tasks[id] = WorkerThreadPool.add_task(func():
		var out := []
		var code := -1
		if linux:
			code = OS.execute(cmd, a, out, true)
		var text := "" if out.is_empty() else str(out[0])
		var s = me.get_ref()
		if s:
			s._done.call_deferred(id, text, code))

## Answer a caller, but only if it still exists (see _done).
func _reply(cb: Callable, args: Array) -> void:
	if cb.is_valid() and (cb.get_object() == null or is_instance_valid(cb.get_object())):
		cb.callv(args)

func _done(id: int, text: String, code: int) -> void:
	var cb: Callable = _cbs.get(id, Callable())
	_cbs.erase(id)
	# Godot needs every finished background task collected, or quitting crashes the engine.
	if _tasks.has(id):
		WorkerThreadPool.wait_for_task_completion(_tasks[id])
		_tasks.erase(id)
	_running -= 1
	busy_changed.emit(_running > 0)
	# Only answer if whoever asked still exists. A screen freed while its command was running
	# (e.g. the top bar's network check when FORGE quits) used to get the answer anyway,
	# which corrupted memory and crashed FORGE on every exit.
	if cb.is_valid() and (cb.get_object() == null or is_instance_valid(cb.get_object())):
		cb.call(text, code)

func has_cmd(name: String) -> bool:
	if not is_linux:
		return false
	for d in ["/usr/bin/", "/usr/local/bin/", "/bin/"]:
		if FileAccess.file_exists(d + name):
			return true
	return false

func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()

# ------------------------------------------------------------------ network
## cb(list: Array[{ssid, signal, secure, active}])
func wifi_scan(cb: Callable) -> void:
	run("nmcli", ["-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"], func(t: String, c: int):
		var seen := {}
		var list := []
		if c != 0:
			t = ""       # no Wi-Fi hardware / nmcli error: never show the error text as a network
		for line in t.split("\n", false):
			var parts := _split_nmcli(line)
			if parts.size() < 4 or parts[1] == "":
				continue
			var ssid: String = parts[1]
			var sig := int(parts[2])
			if seen.has(ssid) and seen[ssid].signal >= sig:
				continue
			var e := {"ssid": ssid, "signal": sig, "secure": parts[3] != "" and parts[3] != "--", "active": parts[0] == "*"}
			seen[ssid] = e
		list = seen.values()
		list.sort_custom(func(a, b): return (a.active and not b.active) or (a.active == b.active and a.signal > b.signal))
		_reply(cb, [list]))

func _split_nmcli(line: String) -> PackedStringArray:
	# nmcli -t escapes ':' as '\:'
	var out := PackedStringArray()
	var cur := ""
	var i := 0
	while i < line.length():
		var ch := line[i]
		if ch == "\\" and i + 1 < line.length():
			cur += line[i + 1]
			i += 2
			continue
		if ch == ":":
			out.append(cur)
			cur = ""
		else:
			cur += ch
		i += 1
	out.append(cur)
	return out

func wifi_connect(ssid: String, password: String, cb: Callable) -> void:
	var args := ["dev", "wifi", "connect", ssid]
	if password != "":
		args += ["password", password]
	run("nmcli", args, func(t, c): _reply(cb, [c == 0, t]))

func wifi_set(on: bool, cb := Callable()) -> void:
	run("nmcli", ["radio", "wifi", "on" if on else "off"], func(_t, _c): if cb.is_valid(): _reply(cb, []))

func wifi_forget(ssid: String, cb := Callable()) -> void:
	run("nmcli", ["connection", "delete", "id", ssid], func(_t, _c): if cb.is_valid(): _reply(cb, []))

## cb({wifi_on, wired, wifi_ssid, ip, online})
func net_status(cb: Callable) -> void:
	run("sh", ["-c", "nmcli -t -f WIFI radio 2>/dev/null; echo '--'; nmcli -t -f TYPE,STATE,CONNECTION dev 2>/dev/null; echo '--'; ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | head -n1"], func(t: String, _c):
		var sec := t.split("--")
		var st := {"wifi_on": false, "wired": false, "wifi_ssid": "", "ip": "", "online": false}
		if sec.size() >= 3:
			st.wifi_on = sec[0].strip_edges() == "enabled"
			for line in sec[1].split("\n", false):
				var p := _split_nmcli(line)
				if p.size() >= 3 and p[1] == "connected":
					if p[0] == "ethernet": st.wired = true
					if p[0] == "wifi": st.wifi_ssid = p[2]
			st.ip = sec[2].strip_edges()
			st.online = st.ip != ""
		_reply(cb, [st]))

# ------------------------------------------------------------------ audio (PipeWire / wpctl)
## cb({sinks:[{id,name,default}], volume:float, muted:bool})
func audio_status(cb: Callable) -> void:
	run("sh", ["-c", "wpctl status 2>/dev/null; echo '@@VOL@@'; wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"], func(t: String, _c):
		var parts := t.split("@@VOL@@")
		var sinks := []
		var in_audio := false
		var in_sinks := false
		for raw in parts[0].split("\n"):
			var line := raw.replace("│", " ").replace("├", " ").replace("└", " ").replace("─", " ")
			var s := line.strip_edges()
			if s.begins_with("Audio"): in_audio = true; continue
			if s.begins_with("Video") or s.begins_with("Settings"): in_audio = false
			if not in_audio: continue
			if s.begins_with("Sinks:"): in_sinks = true; continue
			if s.ends_with(":"): in_sinks = false; continue
			if in_sinks and s != "":
				var is_def := s.begins_with("*")
				s = s.trim_prefix("*").strip_edges()
				var dot := s.find(".")
				if dot > 0 and s.substr(0, dot).is_valid_int():
					var name := s.substr(dot + 1).strip_edges()
					var br := name.find("[vol:")
					if br > 0: name = name.substr(0, br).strip_edges()
					sinks.append({"id": int(s.substr(0, dot)), "name": name, "default": is_def})
		var vol := 0.5
		var muted := false
		if parts.size() > 1:
			var v := parts[1].strip_edges()
			muted = v.find("MUTED") != -1
			var sp := v.split(" ", false)
			if sp.size() >= 2: vol = float(sp[1])
		_reply(cb, [{"sinks": sinks, "volume": vol, "muted": muted}]))

func set_volume(v: float) -> void:
	run("wpctl", ["set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "%.2f" % clampf(v, 0.0, 1.0)])

func set_mute(m: bool) -> void:
	run("wpctl", ["set-mute", "@DEFAULT_AUDIO_SINK@", "1" if m else "0"])

func set_default_sink(id: int) -> void:
	run("wpctl", ["set-default", str(id)])

# ------------------------------------------------------------------ bluetooth
## cb(list: [{mac, name, paired, connected}])
func bt_devices(cb: Callable) -> void:
	run("sh", ["-c", "bluetoothctl devices 2>/dev/null; echo '@@P@@'; bluetoothctl devices Paired 2>/dev/null; echo '@@C@@'; bluetoothctl devices Connected 2>/dev/null"], func(t: String, _c):
		var a := t.split("@@P@@")
		var all := _bt_parse(a[0])
		var paired := {}
		var conn := {}
		if a.size() > 1:
			var b := a[1].split("@@C@@")
			for d in _bt_parse(b[0]): paired[d.mac] = true
			if b.size() > 1:
				for d in _bt_parse(b[1]): conn[d.mac] = true
		for d in all:
			d.paired = paired.has(d.mac)
			d.connected = conn.has(d.mac)
		all.sort_custom(func(x, y): return int(x.connected) * 2 + int(x.paired) > int(y.connected) * 2 + int(y.paired))
		_reply(cb, [all]))

func _bt_parse(t: String) -> Array:
	var out := []
	for line in t.split("\n", false):
		var p := line.split(" ", false, 2)
		if p.size() >= 2 and p[0] == "Device":
			var name := p[2] if p.size() > 2 else p[1]
			out.append({"mac": p[1], "name": name, "paired": false, "connected": false})
	return out

func bt_power(on: bool, cb := Callable()) -> void:
	run("bluetoothctl", ["power", "on" if on else "off"], func(_t, _c): if cb.is_valid(): _reply(cb, []))

func bt_scan(seconds: int, cb: Callable) -> void:
	run("bluetoothctl", ["--timeout", str(seconds), "scan", "on"], func(_t, _c): _reply(cb, []))

func bt_pair(mac: String, cb: Callable) -> void:
	# pair + trust + connect: trusted devices (controllers) reconnect on their own later.
	run("sh", ["-c", "bluetoothctl --timeout 20 pair %s; bluetoothctl trust %s; bluetoothctl --timeout 10 connect %s" % [mac, mac, mac]],
		func(t: String, _c): _reply(cb, [t.find("Connection successful") != -1 or t.find("already connected") != -1, t]))

func bt_connect(mac: String, cb: Callable) -> void:
	run("bluetoothctl", ["--timeout", "10", "connect", mac], func(t: String, _c): _reply(cb, [t.find("successful") != -1, t]))

func bt_disconnect(mac: String, cb := Callable()) -> void:
	run("bluetoothctl", ["disconnect", mac], func(_t, _c): if cb.is_valid(): _reply(cb, []))

func bt_forget(mac: String, cb := Callable()) -> void:
	run("bluetoothctl", ["remove", mac], func(_t, _c): if cb.is_valid(): _reply(cb, []))

# ------------------------------------------------------------------ power
func power(action: String) -> void:
	# The session script performs power actions after the shell exits cleanly,
	# so Steam is shut down first and games save their state.
	match action:
		"suspend":
			run("systemctl", ["suspend"])
		"poweroff":
			_quit(EXIT_POWEROFF)
		"reboot":
			_quit(EXIT_REBOOT)

func set_power_profile(mode: String) -> void:
	if has_cmd("powerprofilesctl"):
		run("powerprofilesctl", ["set", mode])

func restart_session() -> void:
	_quit(EXIT_RESTART_SESSION)

func switch_to_big_picture() -> void:
	_quit(EXIT_BIG_PICTURE)

func _quit(code: int) -> void:
	Config.save_now()
	# Tell the session what we're doing before closing, and arm a watchdog: if closing ever
	# hangs (a background job that never finishes), FORGE is force-closed after 6 seconds
	# and the session still carries out the restart / power off.
	var rt := OS.get_environment("XDG_RUNTIME_DIR")
	if rt != "":
		var f := FileAccess.open(rt + "/forge-intent", FileAccess.WRITE)
		if f:
			f.store_string(str(code))
			f.close()
	if OS.has_feature("linux") and not OS.has_feature("editor"):
		OS.create_process("sh", ["-c", "sleep 6; kill -9 %d 2>/dev/null" % OS.get_process_id()])
	get_tree().quit(code)

# ------------------------------------------------------------------ display
## Physical modes of the connected display, from the kernel (works under Gamescope).
func display_modes() -> Array:
	var out := []
	var seen := {}
	var d := DirAccess.open("/sys/class/drm")
	if d:
		for e in d.get_directories():
			var base := "/sys/class/drm/" + e
			if read_text(base + "/status").strip_edges() != "connected":
				continue
			for line in read_text(base + "/modes").split("\n", false):
				var m := line.strip_edges().split("x")
				if m.size() == 2 and m[0].is_valid_int():
					var key := line.strip_edges().rstrip("i")
					if not seen.has(key):
						seen[key] = true
						out.append(Vector2i(int(m[0]), int(m[1].rstrip("i"))))
	if out.is_empty():
		out = [Vector2i(3840, 2160), Vector2i(2560, 1440), Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720)]
	out.sort_custom(func(a, b): return a.x * a.y > b.x * b.y)
	return out

const REFRESH_RATES := [60, 75, 90, 100, 120, 144, 165, 170, 180, 200, 220, 240, 280, 300, 360]

var _native := Vector3i.ZERO     # x, y = native resolution, z = highest refresh at it
var _edid_modes := []            # Vector3i(w, h, hz) the screen reports

## The screen's own best mode (from its EDID): native resolution at its highest refresh rate.
func native_mode() -> Vector3i:
	if _native != Vector3i.ZERO:
		return _native
	var tool := "/usr/lib/forge/forge-display"
	if FileAccess.file_exists(tool):
		var out := []
		OS.execute(tool, ["--modes"], out)
		for line in (str(out[0]) if out.size() > 0 else "").split("\n", false):
			var p := line.strip_edges().split(" ", false)
			if p.size() == 3 and p[0].is_valid_int():
				_edid_modes.append(Vector3i(int(p[0]), int(p[1]), int(p[2])))
		out = []
		OS.execute(tool, ["--native"], out)
		var n := (str(out[0]) if out.size() > 0 else "").strip_edges().split(" ", false)
		if n.size() == 3 and n[0].is_valid_int():
			_native = Vector3i(int(n[0]), int(n[1]), int(n[2]))
	if _native == Vector3i.ZERO:
		var m := display_modes()
		_native = Vector3i(m[0].x, m[0].y, 60) if not m.is_empty() else Vector3i(1920, 1080, 60)
	return _native

## Settings › Display values in effect: 0 in the config means "the screen's own (native)".
func display_width() -> int:
	var v := Config.get_i("display.width")
	return v if v > 0 else native_mode().x

func display_height() -> int:
	var v := Config.get_i("display.height")
	return v if v > 0 else native_mode().y

func display_refresh() -> int:
	var v := Config.get_i("display.refresh")
	return v if v > 0 else native_mode().z

## Refresh rates to offer: every rate the screen reports, plus the common ones up to its
## highest (the screen's own top rate, e.g. 220 Hz, is always in the list).
func refresh_rates() -> Array:
	var top := native_mode().z
	var rates := {}
	# If the screen reported no fast modes at all, its list is probably incomplete: offer every
	# common rate so you can still pick yours (the default stays what the screen reported).
	var known_fast := false
	for m in _edid_modes:
		if (m as Vector3i).z > 60:
			known_fast = true
	for r in REFRESH_RATES:
		if r <= top or not known_fast:
			rates[r] = true
	for m in _edid_modes:
		rates[(m as Vector3i).z] = true
	rates[top] = true
	var cur := Config.get_i("display.refresh")
	if cur > 0:
		rates[cur] = true
	var out := rates.keys()
	out.sort()
	return out

## Writes the file the session reads before starting Gamescope.
## Returns true if the resolution or refresh rate changed from what the file said before.
func write_session_conf() -> bool:
	var before := read_text(conf_dir + "/session.conf")
	var f := FileAccess.open(conf_dir + "/session.conf", FileAccess.WRITE)
	if f == null:
		return false
	f.store_line("# Written by FORGE Settings. Applied when the session restarts.")
	f.store_line("WIDTH=%d" % display_width())
	f.store_line("HEIGHT=%d" % display_height())
	f.store_line("REFRESH=%d" % display_refresh())
	f.store_line("HDR=%d" % int(Config.get_b("display.hdr")))
	f.store_line("VRR=%d" % int(Config.get_b("display.vrr")))
	f.store_line("INTRO=%d" % int(Config.get_b("appearance.intro")))
	f.close()
	var mode := "WIDTH=%d\nHEIGHT=%d\nREFRESH=%d" % [display_width(), display_height(), display_refresh()]
	return before != "" and not before.contains(mode)

# ------------------------------------------------------------------ MangoHud
## In-game performance overlay and frame-time logging. Steam is started with
## MANGOHUD=1 by the session, so this file controls every game.
func write_mangohud_conf() -> void:
	var dir := home + "/.config/MangoHud"
	DirAccess.make_dir_recursive_absolute(dir)
	var mode := Config.get_s("perf.overlay")
	var lines := PackedStringArray()
	lines.append("# Generated by FORGE OS — edit in Settings › Performance")
	lines.append("legacy_layout=0")
	lines.append("round_corners=12")
	lines.append("background_alpha=0.35")
	lines.append("font_size=20")
	lines.append("position=" + Config.get_s("perf.overlay_position"))
	lines.append("toggle_hud=Shift_R+F12")
	lines.append("toggle_logging=Shift_L+F2")
	lines.append("output_folder=" + bench_dir)
	lines.append("log_interval=0")
	lines.append("log_versioning")
	lines.append("fps_limit=%d" % Config.get_i("perf.fps_limit"))
	if Config.get_b("perf.logging"):
		lines.append("autostart_log=1")
		if Config.get_i("perf.log_duration") > 0:
			lines.append("log_duration=%d" % Config.get_i("perf.log_duration"))
	match mode:
		"off":
			lines.append("no_display")
		"fps":
			lines += PackedStringArray(["fps", "frametime=0", "fps_only"])
		"detailed":
			lines += PackedStringArray(["fps", "frametime", "frame_timing", "gpu_stats", "gpu_temp", "cpu_stats", "cpu_temp", "vram", "ram"])
		"full":
			lines += PackedStringArray(["full", "fps", "frametime", "frame_timing", "histogram", "gpu_stats", "gpu_temp", "gpu_core_clock", "gpu_mem_clock", "gpu_power", "cpu_stats", "cpu_temp", "cpu_power", "cpu_mhz", "core_load", "vram", "ram", "swap", "procmem", "throttling_status", "engine_version", "vulkan_driver", "wine", "gamemode", "resolution", "show_fps_limit"])
	var f := FileAccess.open(dir + "/MangoHud.conf", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")

# ------------------------------------------------------------------ factory reset & presets
## full = also delete captures and sign Steam out. Games stay installed.
func factory_reset(full: bool) -> void:
	Config.save_now()
	var ud := ProjectSettings.globalize_path("user://")
	var cmds := ["rm -rf \"%s\"/*" % ud, "rm -f \"%s/session.conf\"" % conf_dir]
	if full:
		cmds += ["rm -rf \"$HOME/Pictures/FORGE\" \"$HOME/Videos/FORGE\"",
			"rm -f \"%s/config/loginusers.vdf\"" % SteamLib.root,
			"sed -i '/AutoLoginUser/d' \"$HOME/.steam/registry.vdf\""]
	OS.execute("sh", PackedStringArray(["-c", "; ".join(cmds)]))
	_quit(EXIT_RESTART_SESSION)

const PRESETS := {
	"ultra": {"appearance.glass_refraction": 1.0, "appearance.glass_dispersion": 1.0, "appearance.glow": true, "appearance.glow_motion": true, "appearance.wallpaper_animated": true, "appearance.parallax": true, "appearance.glow_strength": 1.0},
	"high": {"appearance.glass_refraction": 1.0, "appearance.glass_dispersion": 0.6, "appearance.glow": true, "appearance.glow_motion": false, "appearance.wallpaper_animated": true, "appearance.parallax": true, "appearance.glow_strength": 0.9},
	"balanced": {"appearance.glass_refraction": 0.6, "appearance.glass_dispersion": 0.0, "appearance.glow": true, "appearance.glow_motion": false, "appearance.wallpaper_animated": true, "appearance.parallax": false, "appearance.glow_strength": 0.7},
}

func apply_preset(name: String) -> void:
	for k in PRESETS.get(name, {}):
		Config.set_v(k, PRESETS[name][k])

# ------------------------------------------------------------------ USB drives
## cb([{path, label, size, mount}]) — removable partitions only.
func usb_drives(cb: Callable) -> void:
	run("lsblk", ["-J", "-b", "-o", "NAME,PATH,RM,HOTPLUG,MOUNTPOINT,LABEL,SIZE,TYPE,TRAN"], func(t: String, _c):
		var out := []
		var j = JSON.parse_string(t)
		if j is Dictionary:
			var stack: Array = (j.get("blockdevices", []) as Array).duplicate()
			while not stack.is_empty():
				var d: Dictionary = stack.pop_back()
				var removable := str(d.get("rm", "0")) in ["1", "true"] or str(d.get("hotplug", "0")) in ["1", "true"] or str(d.get("tran", "")) == "usb"
				for ch in d.get("children", []):
					if removable:
						ch["tran"] = "usb"
					stack.append(ch)
				if removable and str(d.get("type", "")) == "part":
					out.append({"path": str(d.get("path", "")), "label": str(d.get("label", "USB drive")) if d.get("label") != null else "USB drive",
						"size": int(d.get("size", 0)), "mount": str(d.get("mountpoint", "")) if d.get("mountpoint") != null else ""})
		_reply(cb, [out]))

## Mounts a USB partition (if needed) and copies files to <drive>/FORGE/. cb(ok, message)
func export_to_usb(files: Array, cb: Callable) -> void:
	usb_drives(func(list: Array):
		if list.is_empty():
			_reply(cb, [false, "Plug in a USB drive first"])
			return
		var d: Dictionary = list[0]
		var do_copy := func(mount: String):
			var dest := mount + "/FORGE"
			var args := ["-c", "mkdir -p \"$0\" && cp -n \"$@\" \"$0\" && sync", dest]
			args += files
			run("sh", args, func(_t, c: int):
				_reply(cb, [c == 0, ("Copied %d file%s to %s" % [files.size(), "" if files.size() == 1 else "s", d.label]) if c == 0 else "Copying failed. Is the drive full or read-only?"]))
		if d.mount != "":
			do_copy.call(d.mount)
		else:
			run("udisksctl", ["mount", "-b", d.path, "--no-user-interaction"], func(t: String, c: int):
				var at := t.find(" at ")
				if c != 0 or at == -1:
					_reply(cb, [false, "Couldn't open the USB drive"])
					return
				do_copy.call(t.substr(at + 4).strip_edges().trim_suffix("."))))

# ------------------------------------------------------------------ updates & info
func system_update(cb: Callable) -> void:
	run("sudo", ["-n", "/usr/lib/forge/forge-helper", "update"], func(t, c): _reply(cb, [c == 0, t]))

func storage(cb: Callable) -> void:
	run("df", ["-B1", "--output=target,size,used,avail", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay"], func(t: String, _c):
		var out := []
		var lines := t.split("\n", false)
		for i in range(1, lines.size()):
			var p := lines[i].split(" ", false)
			if p.size() >= 4 and (p[0] == "/" or p[0].begins_with("/home") or p[0].begins_with("/mnt") or p[0].begins_with("/run/media") or p[0].begins_with("/media")):
				out.append({"mount": p[0], "size": int(p[1]), "used": int(p[2]), "free": int(p[3])})
		_reply(cb, [out]))

func about() -> Dictionary:
	var info := {"os": Tokens.OS_NAME + " " + Tokens.OS_VERSION, "kernel": "", "cpu": OS.get_processor_name(), "threads": OS.get_processor_count(), "gpu": "", "driver": "", "ram": 0}
	info.gpu = RenderingServer.get_video_adapter_name()
	info.driver = RenderingServer.get_video_adapter_api_version()
	info.kernel = read_text("/proc/sys/kernel/osrelease").strip_edges()
	for line in read_text("/proc/meminfo").split("\n", false):
		if line.begins_with("MemTotal:"):
			info.ram = int(line.split(" ", false)[1]) * 1024
	return info


## On quit, collect commands that are still running (a few seconds at most: FORGE never
## quits in the middle of an update).
func _exit_tree() -> void:
	for id in _tasks:
		TaskWait.on_exit(_tasks[id])
	_tasks.clear()
