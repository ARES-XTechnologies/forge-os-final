class_name FilePicker
extends Overlay
## Controller-friendly file browser. Starts at a list of places (home, every drive and
## USB stick, unmounted drives that can be opened), shows folders and only the files that
## can be played, and hands the chosen path back.

var on_pick: Callable
var title := "Choose a game"
var show_all := false
## When set, only these file types are shown (e.g. photos for a wallpaper) instead of games.
var accept_exts: PackedStringArray = []
var _card: GlassPanel
var _title: Label
var _crumb: Label
var _list: RowList
var _dir := ""                # "" = places list
var _history := {}            # dir -> last focused index

func build() -> void:
	from_offset = Vector2(0, 80)
	_card = GlassPanel.new()
	_card.name = "content"
	_card.radius = 44
	_card.body_dim = 0.95
	_card.size = Vector2(1240, 820)
	add_child(_card)
	_title = Tokens.label(title, 40, 700)
	_title.position = Vector2(48, 36)
	_card.add_child(_title)
	_crumb = Tokens.label("", 19, 500, Tokens.INK_DIM)
	_crumb.position = Vector2(50, 92)
	_crumb.size = Vector2(1140, 26)
	_crumb.clip_text = true
	_card.add_child(_crumb)
	_list = RowList.new()
	_list.position = Vector2(18, 136)
	_list.size = Vector2(1204, 666)
	_card.add_child(_list)
	var last := Config.get_s("library.last_folder")
	if last != "" and DirAccess.dir_exists_absolute(last):
		_open_dir(last)
	else:
		_places()

func _places() -> void:
	_dir = ""
	_crumb.text = "Where is the game?"
	_list.set_rows(_place_rows())
	_list.set_active(true)
	_scan_unmounted()

func _place_rows() -> Array:
	var home := OS.get_environment("HOME")
	var rows: Array = [SettingRow.action("Home folder", func(): _open_dir(home), "home", home)]
	for base in ["/run/media/" + OS.get_environment("USER"), "/media", "/mnt"]:
		var d := DirAccess.open(base)
		if d == null:
			continue
		for m in d.get_directories():
			var p: String = base + "/" + m
			rows.append(SettingRow.action(m.replace("_", " "), func(): _open_dir(p), "storage", ("USB or extra drive · " + p) if base != "/mnt" else ("Drive · " + p)))
	return rows

func _scan_unmounted() -> void:
	# Drives that aren't mounted yet (e.g. a second SSD or a Windows partition)
	Sys.run("lsblk", ["-J", "-b", "-o", "PATH,LABEL,FSTYPE,MOUNTPOINT,SIZE,TYPE"], func(t: String, _c):
		var j = JSON.parse_string(t)
		if not (j is Dictionary) or _dir != "":
			return
		var extra := []
		var stack: Array = (j.get("blockdevices", []) as Array).duplicate()
		while not stack.is_empty():
			var dev: Dictionary = stack.pop_back()
			for ch in dev.get("children", []):
				stack.append(ch)
			var fs := str(dev.get("fstype", "")) if dev.get("fstype") != null else ""
			var mp = dev.get("mountpoint")
			if str(dev.get("type", "")) == "part" and fs in ["ntfs", "ext4", "btrfs", "exfat", "vfat", "xfs", "f2fs"] and (mp == null or str(mp) == "") and int(dev.get("size", 0)) > 4 * 1073741824:
				var label := str(dev.get("label", "")) if dev.get("label") != null else ""
				var path := str(dev.get("path", ""))
				extra.append(SettingRow.action("Open " + (label if label != "" else "drive " + path.get_file()), func(): _mount_and_open(path), "storage", "%s · %s" % [fs.to_upper(), SteamLib.fmt_size(int(dev.get("size", 0)))]))
		if not extra.is_empty():
			_list.set_rows(_place_rows() + [SettingRow.header("Other drives")] + extra)
			_list.set_active(true))

func _mount_and_open(path: String) -> void:
	shell.toast("Opening the drive…", "storage")
	# Same root step FORGE runs at start-up: mounts every drive under /mnt/<name>.
	Sys.run("sudo", ["-n", "/usr/lib/forge/forge-helper", "mount-drives"], func(out: String, code: int):
		Sys.run("findmnt", ["-rn", "-o", "TARGET", "-S", path], func(t: String, c: int):
			var at := t.strip_edges().split("\n")[0] if c == 0 else ""
			if at != "" and DirAccess.dir_exists_absolute(at):
				_open_dir(at)
			else:
				# Show the real reason the system gave (kept by forge-drives), so it can be fixed.
				var why := Sys.read_text("/run/forge-drives/" + path.get_file()).strip_edges()
				# What the drive helper said about this drive, or why the helper didn't run.
				for line in out.split("\n", false):
					if line.begins_with(path.get_file() + ":"):
						why = line.substr(path.get_file().length() + 1).strip_edges()
				if why == "":
					var lines := out.strip_edges().split("\n", false)
					why = ("helper error %d: %s" % [code, lines[-1]]) if code != 0 and not lines.is_empty() else ("helper error %d" % code if code != 0 else "the drive helper skipped it")
				if why.length() > 90:
					why = why.substr(0, 90) + "…"
				shell.toast("Couldn't open that drive" + (": " + why if why != "" else ". If it's a Windows drive, shut Windows down fully and try again."), "info", Tokens.BAD)
				if _dir == "":
					_places()))

func _open_dir(dir: String) -> void:
	if _dir != "":
		_history[_dir] = _list.index
	var d := DirAccess.open(dir)
	if d == null:
		shell.toast("Can't open that folder", "info", Tokens.BAD)
		return
	d.include_hidden = false
	_dir = dir
	_crumb.text = dir
	var rows: Array = [SettingRow.action("Back", func(): _up(), "chevron_left", "", func(): return dir.get_base_dir() if dir.get_base_dir() != dir else "Places")]
	var dirs := Array(d.get_directories())
	dirs.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	var files := Array(d.get_files())
	files.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	var shown := 0
	for f in files:
		var full: String = dir + "/" + f
		if not accept_exts.is_empty():
			if not (f.get_extension().to_lower() in accept_exts):
				continue
			rows.append(SettingRow.action(f, func(): _pick(full), "image", "Photo", func(): return SteamLib.fmt_size(_size(full))))
			shown += 1
			continue
		if not show_all and not LocalGames.is_runnable(f):
			continue
		var kind := "Windows game" if LocalGames.kind_for(full) == "windows" else "Linux game"
		rows.append(SettingRow.action(f, func(): _pick(full), "play", kind, func(): return SteamLib.fmt_size(_size(full))))
		shown += 1
		if shown > 300:
			break
	for sub in dirs.slice(0, 400):
		var p: String = dir + "/" + sub
		rows.append(SettingRow.action(sub, func(): _open_dir(p), "grid"))
	if rows.size() == 1:
		rows.append(SettingRow.info("Nothing playable here", func(): return "Y shows all files", "info"))
	_list.set_rows(rows)
	_list.index = mini(int(_history.get(dir, 1 if rows.size() > 1 else 0)), rows.size() - 1)
	_list.set_active(true)
	Sfx.play("tab")

func _size(p: String) -> int:
	var f := FileAccess.open(p, FileAccess.READ)
	return 0 if f == null else f.get_length()

func _up() -> void:
	if _dir == "" :
		close()
		return
	var parent := _dir.get_base_dir()
	if parent == _dir or parent == "" or parent == "/":
		_places()
	else:
		_open_dir(parent)

func _pick(path: String) -> void:
	Config.set_v("library.last_folder", path.get_base_dir())
	var cb := on_pick
	close()
	if cb.is_valid():
		cb.call(path)

func nav_action(a: StringName) -> bool:
	match a:
		&"back":
			if _dir == "":
				close()
			else:
				_up()
				Sfx.back()
		&"menu":
			show_all = not show_all
			shell.toast("Showing all files" if show_all else "Showing games only", "filter")
			if _dir != "":
				_open_dir(_dir)
		&"alt":
			_places()
		_:
			_list.handle(a)
	return true

func hints() -> Array:
	return [["A", "Open / choose"], ["B", "Up"], ["X", "Drives"], ["Y", "All files"]]
