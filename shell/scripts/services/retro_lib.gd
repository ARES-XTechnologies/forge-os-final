extends RefCounted
class_name RetroLib
## Classic games through RetroArch. Put game files you own into ~/ROMs/<system>/
## (or import them from a USB stick in Settings › Classics). FORGE finds them, fetches
## box art from the libretro thumbnail library, and launches the right emulator core.
## FORGE never downloads games or BIOS files.

const SYSTEMS := {
	"nes":     {"name": "NES", "core": "nestopia", "ext": ["nes", "fds", "unf"], "thumb": "Nintendo - Nintendo Entertainment System"},
	"snes":    {"name": "Super Nintendo", "core": "snes9x", "ext": ["sfc", "smc"], "thumb": "Nintendo - Super Nintendo Entertainment System"},
	"n64":     {"name": "Nintendo 64", "core": "mupen64plus_next", "ext": ["n64", "z64", "v64"], "thumb": "Nintendo - Nintendo 64"},
	"gb":      {"name": "Game Boy", "core": "mgba", "ext": ["gb"], "thumb": "Nintendo - Game Boy"},
	"gbc":     {"name": "Game Boy Color", "core": "mgba", "ext": ["gbc"], "thumb": "Nintendo - Game Boy Color"},
	"gba":     {"name": "Game Boy Advance", "core": "mgba", "ext": ["gba"], "thumb": "Nintendo - Game Boy Advance"},
	"nds":     {"name": "Nintendo DS", "core": "melonds", "ext": ["nds"], "thumb": "Nintendo - Nintendo DS"},
	"genesis": {"name": "Mega Drive / Genesis", "core": "genesis_plus_gx", "ext": ["md", "gen", "smd", "bin"], "thumb": "Sega - Mega Drive - Genesis"},
	"psx":     {"name": "PlayStation", "core": "mednafen_psx_hw", "ext": ["cue", "chd", "pbp", "m3u"], "thumb": "Sony - PlayStation"},
	"psp":     {"name": "PSP", "core": "ppsspp", "ext": ["iso", "cso", "pbp"], "thumb": "Sony - PlayStation Portable"},
}
const CORE_DIRS := ["/usr/lib/libretro", "/usr/lib64/libretro", "/usr/local/lib/libretro"]

static func rom_root() -> String:
	return OS.get_environment("HOME") + "/ROMs"

static func ensure_folders() -> void:
	for s in SYSTEMS:
		DirAccess.make_dir_recursive_absolute(rom_root() + "/" + s)

static func available() -> bool:
	return Sys.has_cmd("retroarch")

static func core_path(core: String) -> String:
	for d in CORE_DIRS:
		var p := "%s/%s_libretro.so" % [d, core]
		if FileAccess.file_exists(p):
			return p
	return ""

static func _thumb_name(file_stem: String) -> String:
	var out := file_stem
	for ch in ["&", "*", "/", ":", "`", "<", ">", "?", "\\", "|", "\""]:
		out = out.replace(ch, "_")
	return out

static func scan() -> Array:
	var out := []
	for s in SYSTEMS:
		var sys: Dictionary = SYSTEMS[s]
		var dir: String = rom_root() + "/" + s
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			var ext := f.get_extension().to_lower()
			if not (ext in sys.ext):
				continue
			if s == "psx" and ext == "bin":
				continue
			var path: String = dir + "/" + f
			var stem := f.get_basename()
			var title := stem
			var paren := title.find(" (")
			if paren > 0:
				title = title.substr(0, paren)
			var id := -(absi(hash("retro:" + path)) % 900000000 + 1000)
			var thumb := "https://thumbnails.libretro.com/%s/Named_Boxarts/%s.png" % [sys.thumb.uri_encode(), _thumb_name(stem).uri_encode()]
			var snap := "https://thumbnails.libretro.com/%s/Named_Snaps/%s.png" % [sys.thumb.uri_encode(), _thumb_name(stem).uri_encode()]
			var title_img := "https://thumbnails.libretro.com/%s/Named_Titles/%s.png" % [sys.thumb.uri_encode(), _thumb_name(stem).uri_encode()]
			Art.register(id, {"portrait": thumb, "hero": snap, "header": title_img, "logo": ""})
			out.append({"appid": id, "name": title, "sort_name": title.to_lower(), "source": "retro", "system": s,
				"system_name": sys.name, "rom": path, "core": sys.core, "installdir": path, "library": dir,
				"size": _file_size(path), "installed": true,
				"updating": false, "progress": 0.0, "bytes_total": 0, "last_updated": FileAccess.get_modified_time(path),
				"last_played": 0, "playtime": 0, "flags": 4})
	return out

static func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return 0 if f == null else f.get_length()

static func launch(g: Dictionary) -> void:
	var core := core_path(str(g.core))
	if core == "":
		Shellbus.notify({"title": "Emulator core missing", "body": "The %s core isn't installed. Update the system in Settings." % str(g.system_name), "icon": "info", "color": Tokens.BAD})
		return
	Session.launch_external(g, "retroarch", ["-f", "-L", core, str(g.rom)], str(g.rom))

## USB import: copies every recognised game file from a folder tree into ~/ROMs/<system>/.
static func import_from(src: String) -> int:
	ensure_folders()
	var count := 0
	var stack := [src]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for sub in d.get_directories():
			stack.append(dir + "/" + sub)
		for f in d.get_files():
			var ext := f.get_extension().to_lower()
			for s in SYSTEMS:
				if ext in SYSTEMS[s].ext and not (ext in ["bin", "iso", "pbp", "cue", "m3u", "chd"] and s != _guess_disc_system(dir)):
					if DirAccess.copy_absolute(dir + "/" + f, rom_root() + "/" + s + "/" + f) == OK:
						count += 1
					break
	return count

static func _guess_disc_system(dir: String) -> String:
	var l := dir.to_lower()
	if l.find("psp") != -1: return "psp"
	if l.find("genesis") != -1 or l.find("mega") != -1: return "genesis"
	return "psx"
