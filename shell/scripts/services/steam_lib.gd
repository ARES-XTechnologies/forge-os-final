extends Node
## Steam library service. Reads Steam's own local files (no API key, no servers):
##   steamapps/libraryfolders.vdf     -> every library drive
##   steamapps/appmanifest_*.acf      -> installed games, size, download progress
##   userdata/<id>/config/localconfig.vdf -> last played + playtime
##   registry.vdf                     -> which game is running right now
## Games launch through the Steam client running silently in the background.

signal library_changed()
signal running_changed(appid: int)
signal scan_state(scanning: bool)

const TOOL_IDS := [228980, 1070560, 1391110, 1628350, 1493710, 2180100, 2348590, 1826330, 1161040, 1887720, 1420170, 961940, 1054830, 1113280, 1245040, 1580130, 2805730, 3658110]
const TOOL_PREFIXES := ["proton", "steam linux runtime", "steamworks common", "steamvr", "steam audio", "linux runtime"]

var games: Array = []            # Array[Dictionary]
var by_id := {}                  # appid -> Dictionary
var running_appid := 0
var root := ""
var scanning := false
var _stamp := ""
var _poll_t := 0.0
var _scan_t := 0.0
var _launching := {}             # appid -> ms timestamp

func _ready() -> void:
	root = find_root()
	rescan()
	Config.changed.connect(func(k):
		if k in ["library.show_uninstalled", "library.heroic", "library.retro", "library.external_stats"]:
			rescan())
	SteamWeb.owned_changed.connect(rescan)
	LocalGames.changed.connect(rescan)
	if Config.get_b("library.retro"):
		RetroLib.ensure_folders()

func find_root() -> String:
	var env := OS.get_environment("FORGE_STEAM_ROOT")
	if env != "" and DirAccess.dir_exists_absolute(env):
		return env
	var home := OS.get_environment("HOME")
	# Windows paths let you preview FORGE on a normal PC with your real library.
	for c in [home + "/.local/share/Steam", home + "/.steam/steam", home + "/.steam/root",
			home + "/.var/app/com.valvesoftware.Steam/.local/share/Steam",
			"C:/Program Files (x86)/Steam", "C:/Program Files/Steam", "D:/Steam", "D:/SteamLibrary"]:
		if DirAccess.dir_exists_absolute(c + "/steamapps"):
			return c
	return ""

func has_steam() -> bool:
	return root != ""

func _process(dt: float) -> void:
	_poll_t += dt
	_scan_t += dt
	if _poll_t > 1.2:
		_poll_t = 0.0
		_poll_running()
	if _scan_t > 6.0 and not scanning:
		_scan_t = 0.0
		if root == "":
			root = find_root()
		var s := _stamp_now()
		if s != _stamp:
			rescan()

# ------------------------------------------------------------------ scanning
func rescan() -> void:
	if scanning:
		return
	scanning = true
	scan_state.emit(true)
	var r := root
	var me := weakref(self)          # FORGE may quit mid-scan: never call back into a freed node
	_scan_task = WorkerThreadPool.add_task(func():
		var result := _scan(r)
		var o = me.get_ref()
		if o:
			o._apply_scan.call_deferred(result))

func _apply_scan(result: Dictionary) -> void:
	if _scan_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_scan_task)  # collect the finished task
		_scan_task = -1
	scanning = false
	_stamp = result.get("stamp", "")
	games = result.get("games", [])
	by_id.clear()
	for g in games:
		g["source"] = "steam"
		by_id[g.appid] = g
	# Owned on Steam but not installed (needs the Web API key)
	if Config.get_b("library.show_uninstalled"):
		for o in SteamWeb.owned:
			var id := int(o.appid)
			if by_id.has(id) or id in TOOL_IDS or _is_tool(id, str(o.name)):
				continue
			var g2 := {"appid": id, "name": str(o.name), "sort_name": _sort_name(str(o.name)), "source": "steam",
				"installdir": "", "library": "", "size": 0, "last_updated": 0, "last_played": int(o.last_played),
				"playtime": int(o.playtime), "flags": 0, "installed": false, "updating": false, "progress": 0.0, "bytes_total": 0}
			games.append(g2)
			by_id[id] = g2
	# Epic / GOG via Heroic, and RetroArch classics
	var extra := []
	if Config.get_b("library.heroic"):
		extra += HeroicLib.scan()
	if Config.get_b("library.retro"):
		extra += RetroLib.scan()
	extra += LocalGames.scan()
	var stats: Dictionary = Config.get_v("library.external_stats")
	for g3 in extra:
		var st: Dictionary = stats.get(str(g3.appid), {})
		g3.playtime = int(st.get("playtime", 0))
		g3.last_played = int(st.get("last_played", 0))
		games.append(g3)
		by_id[g3.appid] = g3
	scan_state.emit(false)
	library_changed.emit()

func _library_paths(r: String) -> PackedStringArray:
	var out := PackedStringArray()
	if r == "":
		return out
	var lf := VDF.parse_file(r + "/steamapps/libraryfolders.vdf")
	var folders = lf.get("libraryfolders", {})
	if folders is Dictionary:
		for k in folders:
			var v = folders[k]
			var p := ""
			if v is Dictionary:
				p = str(v.get("path", ""))
			elif v is String and k.is_valid_int():
				p = v
			if p != "" and DirAccess.dir_exists_absolute(p + "/steamapps") and not out.has(p):
				out.append(p)
	if not out.has(r):
		out.insert(0, r)
	return out

func _stamp_now() -> String:
	var parts := PackedStringArray()
	if Config.get_b("library.retro"):
		for s in RetroLib.SYSTEMS:
			parts.append(str(FileAccess.get_modified_time(RetroLib.rom_root() + "/" + s)))
	var hb := HeroicLib.config_dir()
	if hb != "" and Config.get_b("library.heroic"):
		parts.append(str(FileAccess.get_modified_time(hb + "/legendaryConfig/legendary/installed.json")))
		parts.append(str(FileAccess.get_modified_time(hb + "/gog_store/installed.json")))
	for p in _library_paths(root):
		var d := DirAccess.open(p + "/steamapps")
		if d == null:
			continue
		for f in d.get_files():
			if f.begins_with("appmanifest_"):
				parts.append("%s:%d" % [f, FileAccess.get_modified_time(p + "/steamapps/" + f)])
	return str(hash("|".join(parts)))

func _scan(r: String) -> Dictionary:
	var list: Array = []
	var stamp_parts := PackedStringArray()
	var meta := _read_localconfig(r)
	for lib in _library_paths(r):
		var dir := DirAccess.open(lib + "/steamapps")
		if dir == null:
			continue
		for f in dir.get_files():
			if not (f.begins_with("appmanifest_") and f.ends_with(".acf")):
				continue
			var path := lib + "/steamapps/" + f
			stamp_parts.append("%s:%d" % [f, FileAccess.get_modified_time(path)])
			var acf: Dictionary = VDF.parse_file(path).get("appstate", {})
			if acf.is_empty():
				continue
			var appid := int(acf.get("appid", "0"))
			var name := str(acf.get("name", ""))
			if appid == 0 or _is_tool(appid, name):
				continue
			var flags := int(acf.get("stateflags", "0"))
			var to_dl := int(acf.get("bytestodownload", "0"))
			var done_dl := int(acf.get("bytesdownloaded", "0"))
			var m: Dictionary = meta.get(appid, {})
			list.append({
				"appid": appid,
				"name": name if name != "" else "App %d" % appid,
				"sort_name": _sort_name(name),
				"installdir": str(acf.get("installdir", "")),
				"library": lib,
				"size": int(acf.get("sizeondisk", "0")),
				"last_updated": int(acf.get("lastupdated", "0")),
				"last_played": int(m.get("lastplayed", acf.get("lastplayed", "0"))),
				"playtime": int(m.get("playtime", "0")),
				"flags": flags,
				"installed": (flags & 4) != 0 and (flags & 2) == 0,
				"updating": (flags & 2) != 0 or (flags & 1024) != 0 or (to_dl > 0 and done_dl < to_dl),
				"progress": 0.0 if to_dl <= 0 else clampf(float(done_dl) / float(to_dl), 0.0, 1.0),
				"bytes_total": to_dl,
			})
	return {"games": list, "stamp": str(hash("|".join(stamp_parts)))}

func _is_tool(appid: int, name: String) -> bool:
	if appid in TOOL_IDS:
		return true
	var n := name.to_lower()
	for p in TOOL_PREFIXES:
		if n.begins_with(p):
			return true
	return false

func _sort_name(n: String) -> String:
	var s := n.to_lower().strip_edges()
	for a in ["the ", "a "]:
		if s.begins_with(a):
			s = s.substr(a.length())
	return s

func _read_localconfig(r: String) -> Dictionary:
	# Pick the most recently used Steam account on this machine.
	var out := {}
	if r == "":
		return out
	var ud := DirAccess.open(r + "/userdata")
	if ud == null:
		return out
	var best := ""
	var best_t := 0
	for u in ud.get_directories():
		var p := r + "/userdata/" + u + "/config/localconfig.vdf"
		if FileAccess.file_exists(p):
			var t := FileAccess.get_modified_time(p)
			if t > best_t:
				best_t = t
				best = p
	if best == "":
		return out
	var lc := VDF.parse_file(best)
	var apps = VDF.dig(lc, ["userlocalconfigstore", "software", "valve", "steam", "apps"], {})
	if apps is Dictionary:
		for k in apps:
			if str(k).is_valid_int() and apps[k] is Dictionary:
				out[int(k)] = apps[k]
	return out

# ------------------------------------------------------------------ running game
func _poll_running() -> void:
	var id := 0
	if root != "":
		var home := OS.get_environment("HOME")
		for p in [home + "/.steam/registry.vdf", root + "/registry.vdf"]:
			if FileAccess.file_exists(p):
				var reg := VDF.parse_file(p)
				id = int(VDF.dig(reg, ["registry", "hkcu", "software", "valve", "steam", "runningappid"], "0"))
				break
	if id != running_appid:
		running_appid = id
		running_changed.emit(id)

func is_running() -> bool:
	return running_appid != 0

# ------------------------------------------------------------------ actions
func launch(appid: int) -> void:
	_launching[appid] = Time.get_ticks_msec()
	_steam_url("steam://rungameid/%d" % appid)

func is_launching(appid: int) -> bool:
	return _launching.has(appid) and Time.get_ticks_msec() - int(_launching[appid]) < 25000 and running_appid != appid

func uninstall(appid: int) -> void:
	_steam_url("steam://uninstall/%d" % appid)

func verify(appid: int) -> void:
	_steam_url("steam://validate/%d" % appid)

func install(appid: int) -> void:
	_steam_url("steam://install/%d" % appid)

func open_downloads() -> void:
	_steam_url("steam://open/downloads")

func _steam_url(url: String) -> void:
	if OS.get_name() != "Linux":
		OS.shell_open(url)
		return
	var pid := OS.create_process("steam", [url])
	if pid <= 0:
		push_warning("FORGE: could not reach Steam for " + url)

# ------------------------------------------------------------------ queries
func sorted(mode: String, filter := "all") -> Array:
	var list := games.filter(func(g): return _passes(g, filter))
	match mode:
		"recent":
			list.sort_custom(func(a, b):
				if a.last_played == b.last_played:
					return a.sort_name < b.sort_name
				return a.last_played > b.last_played)
		"name":
			list.sort_custom(func(a, b): return a.sort_name < b.sort_name)
		"size":
			list.sort_custom(func(a, b): return a.size > b.size)
		"playtime":
			list.sort_custom(func(a, b): return a.playtime > b.playtime)
		"installed_date":
			list.sort_custom(func(a, b): return a.last_updated > b.last_updated)
	return list

func _passes(g: Dictionary, filter: String) -> bool:
	var favs: Array = Config.get_v("library.favorites")
	var hidden: Array = Config.get_v("library.hidden")
	match filter:
		"all": return not hidden.has(g.appid)
		"installed": return g.get("installed", true) and not hidden.has(g.appid)
		"uninstalled": return not g.get("installed", true) and not g.get("updating", false) and not g.get("missing", false) and not hidden.has(g.appid)
		"stores": return g.get("source", "steam") in ["epic", "gog"] and not hidden.has(g.appid)
		"classics": return g.get("source", "steam") == "retro" and not hidden.has(g.appid)
		"local": return g.get("source", "steam") in ["local", "usb"] and not hidden.has(g.appid)
		"favorites": return favs.has(g.appid)
		"played": return g.last_played > 0 and not hidden.has(g.appid)
		"unplayed": return g.last_played == 0 and not hidden.has(g.appid)
		"updating": return g.updating
		"hidden": return hidden.has(g.appid)
	return true

func recent(limit := 12) -> Array:
	# Home: games you've played (installed or not) first, then the rest of your installed games.
	var list := sorted("recent").filter(func(g): return g.get("installed", true) or g.last_played > 0 or g.get("updating", false))
	return list.slice(0, limit)

func total_installed() -> int:
	return games.filter(func(g): return g.get("installed", true)).size()

func search(q: String) -> Array:
	var s := q.to_lower().strip_edges()
	if s == "":
		return []
	var scored := []
	for g in games:
		var n: String = g.name.to_lower()
		var score := -1
		if n.begins_with(s): score = 0
		elif n.find(" " + s) != -1: score = 1
		elif n.find(s) != -1: score = 2
		else:
			# initials, e.g. "rdr" -> Red Dead Redemption
			var initials := ""
			for w in n.split(" ", false):
				initials += w[0]
			if initials.begins_with(s): score = 3
		if score >= 0:
			scored.append([score, g])
	scored.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1].sort_name < b[1].sort_name))
	return scored.map(func(x): return x[1])

func total_size() -> int:
	var t := 0
	for g in games:
		if g.get("source", "steam") == "steam":
			t += int(g.size)
	return t

## Starts a game from any source, or installs it if it isn't installed yet.
func play(g: Dictionary) -> void:
	match str(g.get("source", "steam")):
		"epic", "gog":
			HeroicLib.launch(g)
		"retro":
			RetroLib.launch(g)
		"local", "usb":
			LocalGames.launch(g)
		_:
			launch(int(g.appid))

## Install a Steam game without opening Steam's window: FORGE writes the install request
## Steam reads at start-up, then restarts Steam quietly in the background.
func install_quiet(appid: int) -> void:
	var g: Dictionary = by_id.get(appid, {})
	if root == "" or g.is_empty():
		install(appid)
		return
	var safe := ""
	for ch in str(g.name):
		safe += ch if (ch.is_valid_identifier() or ch in " -0123456789") else ""
	safe = safe.strip_edges()
	if safe == "":
		safe = "App%d" % appid
	var acf := {"AppState": {"appid": str(appid), "Universe": "1", "name": str(g.name), "StateFlags": "1026",
		"installdir": safe, "LastUpdated": "0", "UpdateResult": "0", "SizeOnDisk": "0", "buildid": "0",
		"LastOwner": GameSettings.current_steam_id(), "BytesToDownload": "0", "BytesDownloaded": "0",
		"AutoUpdateBehavior": "0", "AllowOtherDownloadsWhileRunning": "0", "ScheduledAutoUpdate": "0"}}
	if VDF.save_file(root + "/steamapps/appmanifest_%d.acf" % appid, acf):
		if not GameSettings.apply_now():
			install(appid)

## Short label for where a game comes from (card badges, game page).
static func source_label(g: Dictionary) -> String:
	match str(g.get("source", "steam")):
		"steam": return "Steam"
		"epic": return "Epic Games"
		"gog": return "GOG"
		"local": return "Local disk"
		"usb": return "USB drive"
		"retro": return str(g.get("system_name", "Classic"))
	return ""

static func source_short(g: Dictionary) -> String:
	match str(g.get("source", "steam")):
		"steam": return "STEAM"
		"epic": return "EPIC"
		"gog": return "GOG"
		"local": return "LOCAL"
		"usb": return "USB"
		"retro": return str(g.get("system", "")).to_upper()
	return ""

static func fmt_size(bytes: int) -> String:
	var b := float(bytes)
	if b >= 1099511627776.0: return "%.2f TB" % (b / 1099511627776.0)
	if b >= 1073741824.0: return "%.1f GB" % (b / 1073741824.0)
	if b >= 1048576.0: return "%.0f MB" % (b / 1048576.0)
	return "%.0f KB" % (b / 1024.0)

static func fmt_playtime(minutes: int) -> String:
	if minutes <= 0: return "Not played yet"
	if minutes < 60: return "%d min played" % minutes
	var h := minutes / 60.0
	if h < 10: return "%.1f hours played" % h
	return "%d hours played" % int(h)

static func fmt_last_played(ts: int) -> String:
	if ts <= 0: return "Never played"
	var now := int(Time.get_unix_time_from_system())
	var d := now - ts
	if d < 3600: return "Played just now"
	if d < 86400: return "Played %d h ago" % (d / 3600)
	if d < 86400 * 2: return "Played yesterday"
	if d < 86400 * 30: return "Played %d days ago" % (d / 86400)
	var dt := Time.get_datetime_dict_from_unix_time(ts)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "Played %d %s %d" % [dt.day, months[dt.month - 1], dt.year]


# ------------------------------------------------------------------ shutdown
var _scan_task := -1

## The scan runs on another thread using this node; quitting mid-scan freed memory it was
## still using and crashed FORGE on exit (seen on every restart). Let it finish first.
func _exit_tree() -> void:
	if _scan_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_scan_task)
		_scan_task = -1
