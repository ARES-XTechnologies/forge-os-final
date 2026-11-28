extends Node
## Games you add yourself: Windows .exe (run through Proton via umu-launcher) and Linux
## games (.sh, .AppImage, binaries) from any drive or USB stick. Shared by all profiles.
##
## Art: FORGE searches Steam's public store for the game's name and uses the official
## cover, background and logo. If the game isn't on Steam, it pulls the icon out of the
## .exe and builds a glass card around it. You can always pick different art later.

signal changed()

const PATH := "user://local_games.json"
const RUNNABLE := ["exe", "bat", "cmd", "msi", "sh", "appimage", "x86_64", "bin", "run", ""]
const GENERIC_NAMES := ["game", "launcher", "start", "play", "setup", "main", "run", "client", "bin", "win64", "win32", "x64", "binaries", "shipping"]

var games: Array = []        # [{id, name, path, kind, proton, args, art:{}, steam_appid, added}]
var forge_run := "/opt/forge/system/forge-run"
var prefixes := OS.get_environment("HOME") + "/.local/share/forge/prefixes"

func _ready() -> void:
	if not FileAccess.file_exists(forge_run):
		forge_run = ProjectSettings.globalize_path("res://").path_join("../system/forge-run").simplify_path()
	if FileAccess.file_exists(PATH):
		var j = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if j is Array:
			games = j
	_register_all()

func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(games, "\t"))
	_register_all()
	changed.emit()

static func id_for(path: String) -> int:
	return -(absi(hash("local:" + path)) % 900000000 + 1000)

static func kind_for(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if ext in ["exe", "bat", "cmd", "msi"]:
		return "windows"
	return "linux"

static func is_runnable(file: String) -> bool:
	var ext := file.get_extension().to_lower()
	if ext in ["exe", "bat", "cmd", "msi", "sh", "appimage", "x86_64", "run"]:
		return true
	return false

## The name a person would recognise: the file name, or its folder if the file is
## called something generic like "Game.exe" or "Launcher.exe".
static func suggest_name(path: String) -> String:
	var stem := path.get_file().get_basename()
	var parts := path.get_base_dir().split("/", false)
	var candidate := stem
	var i := parts.size() - 1
	var low := stem.to_lower()
	for suffix in ["-shipping", "_shipping", "-win64", "_win64", "-win32", "_win32", "_x64", "-x64", "x64", "win64", "_dx12", "_dx11", "-dx12", "-dx11"]:
		low = low.replace(suffix, "")
	low = low.replace("_", "").replace("-", "").replace(" ", "")
	var generic := low in GENERIC_NAMES or low.length() <= 3 or low.ends_with("launcher") or low.ends_with("game")
	while generic and i >= 0:
		var p: String = parts[i]
		var pl := p.to_lower()
		i -= 1
		if pl in GENERIC_NAMES or pl in ["binaries", "win64", "win32", "x64", "x86", "bin", "game", "games", "common", "steamapps", "program files", "program files (x86)"]:
			continue
		candidate = p
		generic = false
	# tidy: "Hollow_Knight-v1.5" -> "Hollow Knight"
	candidate = candidate.replace("_", " ").replace(".", " ")
	var cut := candidate.find(" v1")
	if cut > 0:
		candidate = candidate.substr(0, cut)
	var words := []
	for w in candidate.split(" ", false):
		words.append(w if w.to_upper() == w and w.length() <= 4 else w.substr(0, 1).to_upper() + w.substr(1))
	return " ".join(words).strip_edges()

func find(id: int) -> Dictionary:
	for g in games:
		if int(g.id) == id:
			return g
	return {}

func add(path: String, name: String, steam_appid: int, art: Dictionary) -> Dictionary:
	var id := id_for(path)
	var existing := find(id)
	if not existing.is_empty():
		return existing
	var g := {"id": id, "name": name, "path": path, "kind": kind_for(path), "proton": "", "args": "",
		"art": art, "steam_appid": steam_appid, "added": int(Time.get_unix_time_from_system())}
	games.append(g)
	_save()
	return g

func update(id: int, key: String, value) -> void:
	var g := find(id)
	if g.is_empty():
		return
	g[key] = value
	if key in ["art", "steam_appid"]:
		# New artwork: register its sources and drop the old pictures right away.
		Art.register(id, _art_for(g))
		Art.forget(id)
	_save()

func remove(id: int) -> void:
	games = games.filter(func(g): return int(g.id) != id)
	_save()

## Art sources: Steam CDN for a matched game, otherwise the extracted icon / custom files.
func _art_for(g: Dictionary) -> Dictionary:
	var art: Dictionary = g.get("art", {})
	var sid := int(g.get("steam_appid", 0))
	if sid > 0:
		var base := "https://shared.steamstatic.com/store_item_assets/steam/apps/%d/" % sid
		return {"portrait": art.get("portrait", base + "library_600x900_2x.jpg"), "hero": art.get("hero", base + "library_hero.jpg"),
			"logo": art.get("logo", base + "logo.png"), "header": art.get("header", base + "header.jpg")}
	return {"portrait": art.get("portrait", ""), "hero": art.get("hero", ""), "logo": art.get("logo", ""), "header": art.get("header", art.get("icon", ""))}

func _register_all() -> void:
	for g in games:
		Art.register(int(g.id), _art_for(g))

## Library entries in SteamLib's shape.
func scan() -> Array:
	var out := []
	for g in games:
		var path: String = g.path
		var present := FileAccess.file_exists(path)
		var on_usb := path.begins_with("/run/media/") or path.begins_with("/media/")
		out.append({"appid": int(g.id), "name": str(g.name), "sort_name": str(g.name).to_lower(), "source": "usb" if on_usb else "local",
			"kind": g.kind, "path": path, "installdir": path.get_base_dir(), "library": path.get_base_dir(),
			"size": 0, "installed": present, "missing": not present, "updating": false, "progress": 0.0, "bytes_total": 0,
			"last_updated": int(g.get("added", 0)), "last_played": 0, "playtime": 0, "flags": 4 if present else 0,
			"steam_appid": int(g.get("steam_appid", 0)),
			"is_app": str(g.get("type", "game")) == "app", "pointer": str(g.get("type", "game")) == "app"})
	return out

# ------------------------------------------------------------------ launching
func launch(lib_entry: Dictionary) -> void:
	var g := find(int(lib_entry.appid))
	if g.is_empty():
		return
	if not FileAccess.file_exists(str(g.path)):
		Shellbus.notify({"title": "Can't find " + str(g.name), "body": "Plug in the drive it's on, then try again.", "icon": "storage", "color": Tokens.WARN})
		return
	var args: Array = []
	var extra := str(g.get("args", "")).strip_edges()
	if g.kind == "windows":
		if not Sys.has_cmd("umu-run") and Sys.is_linux:
			Shellbus.notify({"title": "Proton isn't set up yet", "body": "Run Settings › System › Update drivers & Steam once.", "icon": "wrench", "color": Tokens.BAD})
			return
		var sid := int(g.get("steam_appid", 0))
		var game_id := ("umu-%d" % sid) if sid > 0 else "umu-default"
		args = ["windows", prefixes + "/" + str(absi(int(g.id))), proton_path(str(g.get("proton", ""))), game_id, str(g.path)]
		# The very first Windows game downloads Proton (~500 MB) before anything appears.
		if not DirAccess.dir_exists_absolute(OS.get_environment("HOME") + "/.local/share/umu"):
			Shellbus.notify({"title": "Getting Proton ready", "body": "First Windows game: this download takes a few minutes. The game opens by itself.", "icon": "update", "color": Tokens.ACCENT})
	else:
		args = ["linux", str(g.path)]
	if extra != "":
		args += Array(extra.split(" ", false))
	Session.launch_external(lib_entry, forge_run, args, str(g.path))

## Proton choices for your own games: [[value, label], ...]
func proton_options() -> Array:
	var out := [["", "UMU-Proton (recommended)"], ["GE-Proton", "GE-Proton (latest)"]]
	for o in GameSettings.proton_options():
		if o[0] == "":
			continue
		out.append(["steam:" + str(o[1]), str(o[1]) + " (from Steam)"])
	return out

func proton_path(choice: String) -> String:
	if choice == "" or choice == "GE-Proton":
		return choice
	if choice.begins_with("steam:"):
		var dir := choice.substr(6)
		for lib in SteamLib._library_paths(SteamLib.root):
			var p: String = lib + "/steamapps/common/" + dir
			if DirAccess.dir_exists_absolute(p):
				return p
		var custom: String = SteamLib.root + "/compatibilitytools.d/" + dir
		if DirAccess.dir_exists_absolute(custom):
			return custom
	return ""

func prepare_proton(choice: String, cb: Callable) -> void:
	Sys.run(forge_run, ["prepare", proton_path(choice)], func(_t, c: int): cb.call(c == 0))

# ------------------------------------------------------------------ art lookup
## Searches Steam's public store. cb([{appid, name, image}]) — up to 6 matches.
func search_steam(term: String, cb: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 12.0
	add_child(req)
	req.request_completed.connect(func(result, code, _h, body: PackedByteArray):
		req.queue_free()
		var out := []
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var j = JSON.parse_string(body.get_string_from_utf8())
			if j is Dictionary:
				for it in j.get("items", []).slice(0, 6):
					out.append({"appid": int(it.get("id", 0)), "name": str(it.get("name", "")), "image": str(it.get("tiny_image", ""))})
		cb.call(out))
	var url := "https://store.steampowered.com/api/storesearch/?term=%s&l=english&cc=US" % term.uri_encode()
	if req.request(url) != OK:
		req.queue_free()
		cb.call([])

## Pulls the biggest icon out of a Windows .exe as a PNG (needs icoutils). cb(png_path or "")
func extract_icon(exe: String, cb: Callable) -> void:
	if not exe.get_extension().to_lower() == "exe" or not Sys.has_cmd("wrestool"):
		cb.call("")
		return
	var dir := ProjectSettings.globalize_path("user://art/icons")
	DirAccess.make_dir_recursive_absolute(dir)
	var out := "%s/%s.png" % [dir, str(absi(hash(exe)))]
	var script := "t=$(mktemp -d); wrestool -x -t 14 -o \"$t\" \"$1\" 2>/dev/null; ico=$(ls -S \"$t\"/*.ico 2>/dev/null | head -n1); [ -n \"$ico\" ] || exit 1; icotool -x -o \"$t\" \"$ico\" 2>/dev/null; png=$(ls -S \"$t\"/*.png 2>/dev/null | head -n1); [ -n \"$png\" ] && cp \"$png\" \"$2\"; rm -rf \"$t\"; [ -f \"$2\" ]"
	Sys.run("sh", ["-c", script, "icon", exe, out], func(_t, c: int): cb.call(out if c == 0 else ""))
