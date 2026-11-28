extends Node
## Built-in apps that come with every FORGE console: Steam, Heroic, RetroArch and Firefox.
## They appear on Home and in Library next to your games, with each app's own icon (read
## from the app itself as installed on the system). An app is only shown if it's installed.
##
## Launching:
##   Steam      opens Steam Big Picture (Steam's own controller mode); FORGE returns when
##              you exit Steam.
##   Heroic     opens Heroic (Epic / GOG / Amazon). The controller works as a mouse.
##   RetroArch  opens RetroArch, which has its own controller menus.
##   Firefox    opens Firefox full screen. The controller works as a mouse, with an
##              on-screen keyboard for typing.

const HEROIC_FLATPAK := "com.heroicgameslauncher.hgl"

## id, name, how to tell it's installed, how to start it, process to watch, controller mouse
const APPS := [
	{"appid": -11, "app": "steam", "name": "Steam", "pointer": false,
		"icons": ["/usr/share/icons/hicolor/256x256/apps/steam.png", "/usr/share/icons/hicolor/128x128/apps/steam.png", "/usr/share/pixmaps/steam.png"],
		"tint": [Color("1b2838"), Color("2a475e")]},
	{"appid": -12, "app": "heroic", "name": "Heroic", "pointer": true,
		"icons": ["/var/lib/flatpak/exports/share/icons/hicolor/512x512/apps/com.heroicgameslauncher.hgl.png",
			"/var/lib/flatpak/exports/share/icons/hicolor/256x256/apps/com.heroicgameslauncher.hgl.png",
			"/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps/com.heroicgameslauncher.hgl.svg"],
		"tint": [Color("2b2238"), Color("4b3a6b")]},
	{"appid": -13, "app": "retroarch", "name": "RetroArch", "pointer": false,
		"icons": ["/usr/share/icons/hicolor/scalable/apps/com.libretro.RetroArch.svg", "/usr/share/pixmaps/retroarch.svg",
			"/usr/share/icons/hicolor/128x128/apps/retroarch.png", "/usr/share/pixmaps/retroarch.png"],
		"tint": [Color("1e1e24"), Color("3b3b48")]},
	{"appid": -14, "app": "firefox", "name": "Firefox", "pointer": true,
		"icons": ["/usr/share/icons/hicolor/256x256/apps/firefox.png", "/usr/share/icons/hicolor/128x128/apps/firefox.png",
			"/usr/lib/firefox/browser/chrome/icons/default/default128.png"],
		"tint": [Color("20123a"), Color("5a1f4a")]},
]

var _icons := {}      # appid -> Texture2D (or null if none found)

func is_installed(a: Dictionary) -> bool:
	match str(a.app):
		"steam": return Sys.has_cmd("steam")
		"heroic": return DirAccess.dir_exists_absolute("/var/lib/flatpak/app/" + HEROIC_FLATPAK) \
				or DirAccess.dir_exists_absolute(OS.get_environment("HOME") + "/.local/share/flatpak/app/" + HEROIC_FLATPAK)
		"retroarch": return Sys.has_cmd("retroarch")
		"firefox": return Sys.has_cmd("firefox")
	return false

func info(appid: int) -> Dictionary:
	for a in APPS:
		if int(a.appid) == appid:
			return a
	return {}

## Library entries in SteamLib's shape, for the apps that are installed.
func scan() -> Array:
	var out := []
	for a in APPS:
		if not is_installed(a):
			continue
		# No cover art to look up for apps (their icon is drawn instead), so tell the art
		# service there's none: otherwise it would try Steam's image servers.
		Art.register(int(a.appid), {"portrait": "", "hero": "", "logo": "", "header": ""})
		out.append({"appid": int(a.appid), "name": str(a.name), "sort_name": str(a.name).to_lower(), "source": "app",
			"app": str(a.app), "is_app": true, "pointer": bool(a.pointer),
			"installdir": "", "library": "", "size": 0, "installed": true, "missing": false, "updating": false,
			"progress": 0.0, "bytes_total": 0, "last_updated": 0, "last_played": 0, "playtime": 0, "flags": 4})
	return out

## The app's own icon from the system (PNG or SVG), cached.
func icon_tex(appid: int) -> Texture2D:
	if _icons.has(appid):
		return _icons[appid]
	var tex: Texture2D = null
	var a := info(appid)
	for p in a.get("icons", []):
		if not FileAccess.file_exists(p):
			continue
		var img := Image.new()
		var err := OK
		if str(p).ends_with(".svg"):
			err = img.load_svg_from_buffer(FileAccess.get_file_as_bytes(p), 4.0)
		else:
			err = img.load(p)
		if err == OK and not img.is_empty():
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
			break
	_icons[appid] = tex
	return tex

func tint(appid: int) -> Array:
	return info(appid).get("tint", [Color("1a1f33"), Color("2c3557")])

func launch(entry: Dictionary) -> void:
	match str(entry.get("app", "")):
		"steam":
			Sys.switch_to_big_picture()
		"heroic":
			Session.launch_external(entry, "flatpak", ["run", HEROIC_FLATPAK], "heroic")
		"retroarch":
			Session.launch_external(entry, "retroarch", [], "retroarch")
		"firefox":
			Session.launch_external(entry, "firefox", ["--new-window", "https://www.google.com"], "firefox")
