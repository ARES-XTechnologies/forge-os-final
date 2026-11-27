extends Node
## Per-game settings.
##  • FPS limit and overlay: per-game MangoHud config, works from the next launch.
##  • Proton version and launch options: Steam keeps these in its own config files,
##    which it overwrites while running. FORGE queues the change and writes it while
##    Steam is closed (on "Apply now", or the next time the console starts).
##  • Steam account switching for profiles uses the same queue.

signal pending_changed()

const PENDING_PATH := "user://pending_steam.json"
var _pending := {}   # {"proton": {appid: name}, "launch": {appid: text}, "account": "name"}

func _ready() -> void:
	if FileAccess.file_exists(PENDING_PATH):
		var p = JSON.parse_string(FileAccess.get_file_as_string(PENDING_PATH))
		if p is Dictionary:
			_pending = p

func has_pending() -> bool:
	return not (_pending.get("proton", {}) as Dictionary).is_empty() \
		or not (_pending.get("launch", {}) as Dictionary).is_empty() \
		or str(_pending.get("account", "")) != ""

func _save() -> void:
	var f := FileAccess.open(PENDING_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_pending))
	pending_changed.emit()

# ------------------------------------------------------------------ Proton
## [[internal_name, "Display name"], ...] — first entry is Steam's default.
func proton_options() -> Array:
	var out := [["", "Steam default"]]
	var root: String = SteamLib.root
	if root == "":
		return out
	var seen := {}
	for lib in SteamLib._library_paths(root):
		var d := DirAccess.open(lib + "/steamapps/common")
		if d == null:
			continue
		for dir in d.get_directories():
			var n := _valve_proton_name(dir)
			if n != "" and not seen.has(n):
				seen[n] = true
				out.append([n, dir])
	for base in [root + "/compatibilitytools.d", OS.get_environment("HOME") + "/.steam/root/compatibilitytools.d"]:
		var d2 := DirAccess.open(base)
		if d2 == null:
			continue
		for dir in d2.get_directories():
			var vdf := VDF.parse_file(base + "/" + dir + "/compatibilitytool.vdf")
			var tools = VDF.dig(vdf, ["compatibilitytools", "compat_tools"], {})
			if tools is Dictionary:
				for internal in tools:
					if not seen.has(internal):
						seen[internal] = true
						var disp = (tools[internal] as Dictionary).get("display_name", internal) if tools[internal] is Dictionary else internal
						out.append([internal, str(disp)])
	return out

func _valve_proton_name(dir: String) -> String:
	if dir == "Proton - Experimental": return "proton_experimental"
	if dir == "Proton Hotfix": return "proton_hotfix"
	if dir.begins_with("Proton "):
		var v := dir.substr(7).split(".")[0]
		if v.is_valid_int():
			return "proton_%s" % v
	return ""

func set_proton(appid: int, internal: String) -> void:
	Config.game_set(appid, "proton", internal)
	var m: Dictionary = _pending.get("proton", {})
	m[str(appid)] = internal
	_pending["proton"] = m
	_save()

func set_launch_options(appid: int, text: String) -> void:
	Config.game_set(appid, "launch", text)
	var m: Dictionary = _pending.get("launch", {})
	m[str(appid)] = text
	_pending["launch"] = m
	_save()

func set_steam_account(account: String) -> void:
	_pending["account"] = account
	_save()

# ------------------------------------------------------------------ applying (Steam closed)
## Every Steam game starts through forge-fsr (FSR for all games). With FSR off it runs the
## game exactly as before. Your own launch options are kept: "%command%" just gets FORGE's
## launcher in front of it.
const FSR_PREFIX := "/usr/lib/forge/forge-fsr %command%"

static func with_fsr(opts: String) -> String:
	if opts.contains("forge-fsr"):
		return opts
	if opts.strip_edges() == "":
		return FSR_PREFIX
	if opts.contains("%command%"):
		return opts.replace("%command%", FSR_PREFIX)
	return FSR_PREFIX + " " + opts         # bare game arguments go after %command%

## Installed Steam games (app ids), from every library's app manifests.
func _installed_appids(root: String) -> Array:
	var ids := []
	for lib in SteamLib._library_paths(root):
		var d := DirAccess.open(lib + "/steamapps")
		if d == null:
			continue
		for f in d.get_files():
			if f.begins_with("appmanifest_") and f.ends_with(".acf"):
				var id := f.trim_prefix("appmanifest_").trim_suffix(".acf")
				if id.is_valid_int():
					ids.append(id)
	return ids

## Adds FORGE's launcher to every installed game that doesn't have it yet. Saves only if
## something changed.
func _ensure_fsr_launchers(root: String) -> void:
	if not FileAccess.file_exists("/usr/lib/forge/forge-fsr"):
		return
	var ids := _installed_appids(root)
	var ud := DirAccess.open(root + "/userdata")
	if ud == null or ids.is_empty():
		return
	for u in ud.get_directories():
		var lpath := root + "/userdata/" + u + "/config/localconfig.vdf"
		if not FileAccess.file_exists(lpath):
			continue
		var lc := VDF.parse_file_raw(lpath)
		var apps := VDF.ensure(lc, ["UserLocalConfigStore", "Software", "Valve", "Steam", "apps"])
		var changed := false
		for id in ids:
			var app := VDF.ensure(apps, [str(id)])
			var cur := ""
			for k in app.keys():
				if str(k).to_lower() == "launchoptions":
					cur = str(app[k])
			var want := with_fsr(cur)
			if want != cur:
				VDF.set_ci(app, "LaunchOptions", want)
				changed = true
		if changed:
			VDF.save_file(lpath, lc)

## Runs headless before Steam starts (forge-inner / forge-game steam-restart).
func apply_pending() -> void:
	var root: String = SteamLib.find_root()
	if root == "":
		return
	_ensure_fsr_launchers(root)
	if not has_pending():
		return
	var proton: Dictionary = _pending.get("proton", {})
	if not proton.is_empty():
		var cpath := root + "/config/config.vdf"
		var cfg := VDF.parse_file_raw(cpath)
		var map := VDF.ensure(cfg, ["InstallConfigStore", "Software", "Valve", "Steam", "CompatToolMapping"])
		for appid in proton:
			var name: String = proton[appid]
			if name == "":
				for k in map.keys():
					if str(k) == str(appid):
						map.erase(k)
			else:
				map[str(appid)] = {"name": name, "config": "", "priority": "250"}
		VDF.save_file(cpath, cfg)
	var launch: Dictionary = _pending.get("launch", {})
	if not launch.is_empty():
		var ud := DirAccess.open(root + "/userdata")
		if ud:
			for u in ud.get_directories():
				var lpath := root + "/userdata/" + u + "/config/localconfig.vdf"
				if not FileAccess.file_exists(lpath):
					continue
				var lc := VDF.parse_file_raw(lpath)
				var apps := VDF.ensure(lc, ["UserLocalConfigStore", "Software", "Valve", "Steam", "apps"])
				for appid in launch:
					var app := VDF.ensure(apps, [str(appid)])
					VDF.set_ci(app, "LaunchOptions", with_fsr(str(launch[appid])))
				VDF.save_file(lpath, lc)
	var account := str(_pending.get("account", ""))
	if account != "":
		var rpath := OS.get_environment("HOME") + "/.steam/registry.vdf"
		var reg := VDF.parse_file_raw(rpath)
		var steam := VDF.ensure(reg, ["Registry", "HKCU", "Software", "Valve", "Steam"])
		VDF.set_ci(steam, "AutoLoginUser", account)
		VDF.set_ci(steam, "RememberPassword", "1")
		VDF.save_file(rpath, reg)
	_pending = {}
	_save()

## Restart Steam now so queued changes take effect (only when no game is running).
func apply_now() -> bool:
	if Session.is_playing():
		return false
	Sys.run(Session.forge_game, ["steam-restart", ProjectSettings.globalize_path("res://")])
	return true

## Steam accounts that have signed in on this console: [[account_name, persona], ...]
func steam_accounts() -> Array:
	var out := []
	var lu := VDF.parse_file(SteamLib.root + "/config/loginusers.vdf")
	var users = lu.get("users", {})
	if users is Dictionary:
		for sid in users:
			var u = users[sid]
			if u is Dictionary:
				out.append([str(u.get("accountname", "")), str(u.get("personaname", u.get("accountname", "")))])
	return out

## SteamID64 of the account Steam last signed in with.
func current_steam_id() -> String:
	var lu := VDF.parse_file(SteamLib.root + "/config/loginusers.vdf")
	var users = lu.get("users", {})
	var best := ""
	var best_t := 0
	if users is Dictionary:
		for sid in users:
			var u = users[sid]
			if u is Dictionary:
				if str(u.get("mostrecent", "0")) == "1":
					return str(sid)
				var t := int(u.get("timestamp", "0"))
				if t > best_t:
					best_t = t
					best = str(sid)
	return best

# ------------------------------------------------------------------ MangoHud per game
## Writes a per-game MangoHud file (FPS cap / overlay) once we know the game's process name.
func write_per_game_mangohud(appid: int) -> void:
	var exe: String = (Config.get_v("games.exe") as Dictionary).get(str(appid), "")
	if exe == "":
		return
	var fps = Config.game_get(appid, "fps", null)
	var overlay = Config.game_get(appid, "overlay", null)
	var dir := OS.get_environment("HOME") + "/.config/MangoHud"
	var base := exe.trim_suffix(".exe").trim_suffix(".EXE")
	var names := [base + ".conf", "wine-" + base + ".conf"]
	if fps == null and overlay == null:
		for n in names:
			DirAccess.remove_absolute(dir + "/" + n)
		return
	var global := FileAccess.get_file_as_string(dir + "/MangoHud.conf")
	var lines := PackedStringArray()
	for line in global.split("\n", false):
		if line.begins_with("fps_limit") or (overlay != null and (line == "no_display" or line == "fps_only")):
			continue
		lines.append(line)
	if fps != null:
		lines.append("fps_limit=%d" % int(fps))
	if overlay != null:
		match str(overlay):
			"off": lines.append("no_display")
			"fps": lines.append("fps_only")
	for n in names:
		var f := FileAccess.open(dir + "/" + n, FileAccess.WRITE)
		if f:
			f.store_string("# FORGE per-game settings for " + str(appid) + "\n" + "\n".join(lines) + "\n")
