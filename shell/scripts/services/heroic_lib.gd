extends RefCounted
class_name HeroicLib
## Epic Games and GOG games installed through Heroic Games Launcher (Flatpak or native).
## Sign-in and installs happen in Heroic (Settings › Stores › Open Heroic); installed
## games then appear in FORGE with their store art and launch straight from Home.

const FLATPAK_ID := "com.heroicgameslauncher.hgl"

static func config_dir() -> String:
	var home := OS.get_environment("HOME")
	for d in [home + "/.var/app/" + FLATPAK_ID + "/config/heroic", home + "/.config/heroic"]:
		if DirAccess.dir_exists_absolute(d):
			return d
	return ""

static func is_flatpak() -> bool:
	return config_dir().find("/.var/app/") != -1

static func available() -> bool:
	return Sys.has_cmd("flatpak") or Sys.has_cmd("heroic")

static func uid(runner: String, app_name: String) -> int:
	# Stable negative ids keep non-Steam games apart from Steam app ids.
	return -(absi(hash(runner + ":" + app_name)) % 900000000 + 1000)

static func _json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

## Returns game dicts in the same shape SteamLib uses.
static func scan() -> Array:
	var base := config_dir()
	if base == "":
		return []
	var out := []
	# --- art/metadata from Heroic's library caches
	var meta := {}
	for lib in [base + "/store_cache/legendary_library.json", base + "/store_cache/gog_library.json",
			base + "/lib-cache/library.json", base + "/gog_store/library.json"]:
		var j = _json(lib)
		var arr = null
		if j is Dictionary:
			arr = j.get("library", j.get("games", null))
		elif j is Array:
			arr = j
		if arr is Array:
			for g in arr:
				if g is Dictionary:
					meta[str(g.get("app_name", g.get("appName", "")))] = g
	# --- Epic (Legendary)
	var leg = _json(base + "/legendaryConfig/legendary/installed.json")
	if leg == null:
		leg = _json(OS.get_environment("HOME") + "/.config/legendary/installed.json")
	if leg is Dictionary:
		for app in leg:
			var e = leg[app]
			if e is Dictionary:
				out.append(_make("legendary", "epic", str(app), str(e.get("title", app)), str(e.get("install_path", "")), int(e.get("install_size", 0)), meta.get(str(app), {})))
	# --- GOG
	var gog = _json(base + "/gog_store/installed.json")
	if gog is Dictionary:
		var arr2 = gog.get("installed", [])
		if arr2 is Array:
			for e in arr2:
				if e is Dictionary:
					var app := str(e.get("appName", ""))
					var m: Dictionary = meta.get(app, {})
					out.append(_make("gog", "gog", app, str(m.get("title", e.get("title", app))), str(e.get("install_path", "")), int(e.get("install_size", 0)), m))
	return out

static func _make(runner: String, source: String, app: String, title: String, path: String, size: int, m: Dictionary) -> Dictionary:
	var id := uid(runner, app)
	Art.register(id, {
		"portrait": str(m.get("art_cover", m.get("art_square", ""))),
		"hero": str(m.get("art_background", m.get("art_cover", ""))),
		"logo": str(m.get("art_logo", "")),
		"header": str(m.get("art_square", m.get("art_cover", ""))),
	})
	return {"appid": id, "name": title, "sort_name": title.to_lower(), "source": source, "runner": runner, "app_name": app,
		"installdir": path, "library": path.get_base_dir(), "size": size, "installed": true, "updating": false,
		"progress": 0.0, "bytes_total": 0, "last_updated": 0, "last_played": 0, "playtime": 0, "flags": 4}

static func launch(g: Dictionary) -> void:
	var url := "heroic://launch/%s/%s" % [g.runner, g.app_name]
	var match_text: String = g.installdir if str(g.installdir).length() > 8 else str(g.app_name)
	if is_flatpak() or not Sys.has_cmd("heroic"):
		Session.launch_external(g, "flatpak", ["run", FLATPAK_ID, "--no-gui", url], match_text)
	else:
		Session.launch_external(g, "heroic", ["--no-gui", url], match_text)

## Opens Heroic itself for signing in to Epic / GOG and installing games.
static func open_launcher() -> void:
	if Sys.has_cmd("heroic"):
		OS.create_process("heroic", PackedStringArray([]))
	else:
		OS.create_process("flatpak", PackedStringArray(["run", FLATPAK_ID]))
