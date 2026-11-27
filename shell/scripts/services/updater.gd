extends Node
## FORGE self-update from GitHub Releases. No reinstall needed: publish a new release
## (a tag like v1.4.0) and every console shows "Update available". One press updates the
## whole OS: the FORGE app, its system parts and every package (kernel, drivers, Steam),
## pinned to the snapshot that release was tested with. Undo restores all of it.

signal state_changed()

var latest := ""             # newest version tag found, "" if none / up to date
var notes := ""
var busy := false
var progress := 0.0
var status := ""
var _zip_url := ""
var _check_t := 0.0
var staging := OS.get_environment("HOME") + "/.local/share/forge/update"

func _ready() -> void:
	if Config.get_s("update.repo") == "":
		var ch := "/opt/forge/channel.json"
		if FileAccess.file_exists(ch):
			var j = JSON.parse_string(FileAccess.get_file_as_string(ch))
			if j is Dictionary and str(j.get("repo", "")) != "":
				Config.set_v("update.repo", str(j.repo))
	latest = Config.get_s("update.available")
	if latest != "" and not _newer(latest, Tokens.OS_VERSION):
		latest = ""
		Config.set_v("update.available", "")
	await get_tree().create_timer(30.0).timeout
	if Config.get_b("update.auto_check"):
		check()

func _process(dt: float) -> void:
	_check_t += dt
	if _check_t > 6.0 * 3600.0:
		_check_t = 0.0
		if Config.get_b("update.auto_check") and not Session.is_playing():
			check()

func repo() -> String:
	return Config.get_s("update.repo").strip_edges()

func _headers() -> PackedStringArray:
	var h := PackedStringArray(["User-Agent: FORGE-OS", "Accept: application/vnd.github+json"])
	var tok := Config.get_s("update.token").strip_edges()
	if tok != "":
		h.append("Authorization: Bearer " + tok)
	return h

static func _ver(v: String) -> Array:
	var parts := v.strip_edges().trim_prefix("v").trim_prefix("V").split("-")[0].split(".")
	var out := []
	for p in parts:
		out.append(int(p) if p.is_valid_int() else 0)
	while out.size() < 3:
		out.append(0)
	return out

static func _newer(a: String, b: String) -> bool:
	var x := _ver(a)
	var y := _ver(b)
	for i in 3:
		if x[i] != y[i]:
			return x[i] > y[i]
	return false

func check(cb := Callable()) -> void:
	if repo() == "" or busy:
		status = "No update source set" if repo() == "" else status
		state_changed.emit()
		if cb.is_valid(): cb.call(false)
		return
	status = "Checking…"
	state_changed.emit()
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	req.request_completed.connect(func(result, code, _h, body: PackedByteArray):
		req.queue_free()
		Config.set_v("update.last_check", int(Time.get_unix_time_from_system()))
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			status = "Couldn't reach GitHub" if code != 404 else "No releases published yet"
			state_changed.emit()
			if cb.is_valid(): cb.call(false)
			return
		var j = JSON.parse_string(body.get_string_from_utf8())
		if not (j is Dictionary):
			status = "Unexpected reply from GitHub"
			state_changed.emit()
			if cb.is_valid(): cb.call(false)
			return
		var tag := str(j.get("tag_name", ""))
		_zip_url = str(j.get("zipball_url", ""))
		notes = str(j.get("body", "")).substr(0, 600)
		if tag != "" and _newer(tag, Tokens.OS_VERSION):
			var fresh := latest != tag
			latest = tag
			Config.set_v("update.available", tag)
			status = "Version %s is ready to install" % tag.trim_prefix("v")
			if fresh:
				Shellbus.notify({"title": "Update available", "body": "FORGE %s · Settings › System to install" % tag.trim_prefix("v"), "icon": "update", "color": Tokens.ACCENT, "sound": "notify", "duration": 7.0})
		else:
			latest = ""
			Config.set_v("update.available", "")
			status = "FORGE is up to date (%s)" % Tokens.OS_VERSION
		state_changed.emit()
		if cb.is_valid(): cb.call(latest != ""))
	if req.request("https://api.github.com/repos/%s/releases/latest" % repo(), _headers()) != OK:
		req.queue_free()
		status = "Couldn't reach GitHub"
		state_changed.emit()

## Download, unpack, swap in, restart.
func install() -> void:
	if busy or latest == "" or _zip_url == "":
		if latest != "" and _zip_url == "":
			check(func(ok): if ok: install())
		return
	busy = true
	status = "Downloading %s…" % latest
	progress = 0.0
	state_changed.emit()
	DirAccess.make_dir_recursive_absolute(staging)
	var zip_path := staging + "/update.zip"
	var req := HTTPRequest.new()
	req.timeout = 600.0
	req.download_file = zip_path
	add_child(req)
	var poll := Timer.new()
	poll.wait_time = 0.25
	add_child(poll)
	poll.timeout.connect(func():
		var total := req.get_body_size()
		if total > 0:
			progress = clampf(float(req.get_downloaded_bytes()) / total, 0.0, 1.0)
			state_changed.emit())
	poll.start()
	req.request_completed.connect(func(result, code, _h, _b):
		poll.queue_free()
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_fail("Download failed. Check the internet connection.")
			return
		status = "Unpacking…"
		state_changed.emit()
		var me := weakref(self)
		_bg.append(WorkerThreadPool.add_task(func():
			var err: String = me.get_ref()._unpack(zip_path, staging + "/staged") if me.get_ref() else "FORGE closed"
			var o = me.get_ref()
			if o:
				o._unpacked.call_deferred(err))))
	if req.request(_zip_url, _headers()) != OK:
		poll.queue_free()
		req.queue_free()
		_fail("Couldn't start the download.")

func _unpack(zip_path: String, dest: String) -> String:
	OS.execute("rm", PackedStringArray(["-rf", dest]))
	DirAccess.make_dir_recursive_absolute(dest)
	var z := ZIPReader.new()
	if z.open(zip_path) != OK:
		return "The download was damaged."
	var files := z.get_files()
	for f in files:
		# GitHub zips have one top folder: owner-repo-sha/
		var slash := f.find("/")
		if slash < 0:
			continue
		var rel := f.substr(slash + 1)
		if rel == "" or rel.find("..") != -1:
			continue
		var out := dest + "/" + rel
		if f.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(out)
			continue
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var fh := FileAccess.open(out, FileAccess.WRITE)
		if fh:
			fh.store_buffer(z.read_file(f))
	z.close()
	if not FileAccess.file_exists(dest + "/shell/project.godot"):
		return "That release doesn't contain FORGE."
	for s in ["forge-session", "forge-inner", "forge-game", "forge-recovery", "forge-run"]:
		if FileAccess.file_exists(dest + "/system/" + s):
			OS.execute("chmod", PackedStringArray(["+x", dest + "/system/" + s]))
	return ""

func _unpacked(err: String) -> void:
	_collect_bg()
	if err != "":
		_fail(err)
		return
	status = "Updating the system: FORGE, drivers, Steam and packages. This can take a few minutes…"
	state_changed.emit()
	Shellbus.notify({"title": "Updating FORGE OS", "body": "Keep the console on. It restarts by itself when done.", "icon": "update", "color": Tokens.ACCENT, "duration": 8.0})
	Sys.run("sudo", ["-n", "/usr/lib/forge/forge-helper", "apply-update"], func(t: String, c: int):
		if c != 0:
			_fail("The update couldn't finish, so FORGE stayed on the previous version. Check the internet connection and try again.")
			return
		busy = false
		Config.set_v("update.available", "")
		Config.save_now()
		var reboot := t.contains("REBOOT")
		status = "Updated. Restarting…"
		state_changed.emit()
		var later := t.contains("PACKAGES_LATER")
		Shellbus.notify({"title": "FORGE OS updated", "body": ("Drivers update next time. " if later else "") + ("Restarting the console…" if reboot else "Restarting the console UI…"), "icon": "check", "color": Tokens.OK})
		await get_tree().create_timer(2.5).timeout
		if reboot:
			Sys.power("reboot")         # new kernel or drivers: a full restart loads them
		else:
			Sys.restart_session())

func _fail(msg: String) -> void:
	busy = false
	status = msg
	state_changed.emit()
	Shellbus.notify({"title": "Update didn't finish", "body": msg, "icon": "update", "color": Tokens.BAD})

func rollback() -> void:
	Shellbus.notify({"title": "Going back to the previous version", "body": "This can take a few minutes. The console restarts by itself.", "icon": "restart", "color": Tokens.ACCENT})
	Sys.run("sudo", ["-n", "/usr/lib/forge/forge-helper", "rollback"], func(_t, c: int):
		if c == 0:
			Shellbus.notify({"title": "Went back to the previous version", "body": "Restarting…", "icon": "restart", "color": Tokens.OK})
			Config.save_now()
			await get_tree().create_timer(1.5).timeout
			Sys.power("reboot")
		else:
			Shellbus.notify({"title": "No previous version to go back to", "body": "", "icon": "info", "color": Tokens.WARN}))


# ------------------------------------------------------------------ background tasks
## Godot needs every background task collected once it's done, or quitting crashes the
## engine. Finished ones are collected as results arrive; the rest on exit.
var _bg: Array = []

func _collect_bg() -> void:
	for t in _bg.duplicate():
		if WorkerThreadPool.is_task_completed(t):
			WorkerThreadPool.wait_for_task_completion(t)
			_bg.erase(t)

func _exit_tree() -> void:
	for t in _bg:
		TaskWait.on_exit(t)
	_bg.clear()
