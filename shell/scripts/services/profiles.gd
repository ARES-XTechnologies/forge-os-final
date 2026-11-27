extends Node
## Player profiles. Each profile has its own settings, favourites, theme and (optionally)
## its own Steam account. Switching account restarts Steam in the background.

signal profiles_changed()

const PATH := "user://profiles.json"
const COLORS := ["7cc8ff", "b58cff", "ff8fb8", "ffc76b", "6ff2b5", "ff7a5c", "9fe0ff", "e6e9ff"]

var list: Array = []          # [{id, name, color, steam}]
var active := ""

func _ready() -> void:
	_load()
	if list.is_empty():
		# First profile adopts the old single-user settings file.
		var p := {"id": "p1", "name": "Player 1", "color": COLORS[0], "steam": ""}
		list.append(p)
		active = "p1"
		var legacy := "user://settings.json"
		if FileAccess.file_exists(legacy):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_settings_path("p1")).get_base_dir())
			DirAccess.copy_absolute(ProjectSettings.globalize_path(legacy), ProjectSettings.globalize_path(_settings_path("p1")))
		_save()
	Config.load_profile_file(_settings_path(active))

func _settings_path(id: String) -> String:
	return "user://profiles/%s/settings.json" % id

func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var j = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if j is Dictionary:
		list = j.get("list", [])
		active = str(j.get("active", ""))
		if find(active).is_empty() and not list.is_empty():
			active = list[0].id

func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"list": list, "active": active}, "\t"))
	profiles_changed.emit()

func find(id: String) -> Dictionary:
	for p in list:
		if p.id == id:
			return p
	return {}

func current() -> Dictionary:
	return find(active)

func add(name: String) -> Dictionary:
	var n := 1
	while not find("p%d" % n).is_empty():
		n += 1
	var p := {"id": "p%d" % n, "name": name if name.strip_edges() != "" else "Player %d" % n, "color": COLORS[(n - 1) % COLORS.size()], "steam": ""}
	list.append(p)
	_save()
	return p

func rename(id: String, name: String) -> void:
	var p := find(id)
	if not p.is_empty() and name.strip_edges() != "":
		p.name = name.strip_edges()
		_save()

func set_color(id: String, hex: String) -> void:
	var p := find(id)
	if not p.is_empty():
		p.color = hex
		_save()

func set_steam(id: String, account: String) -> void:
	var p := find(id)
	if p.is_empty():
		return
	p.steam = account
	_save()
	if id == active and account != "":
		GameSettings.set_steam_account(account)
		GameSettings.apply_now()

func remove(id: String) -> bool:
	if list.size() <= 1 or id == active:
		return false
	list = list.filter(func(p): return p.id != id)
	OS.execute("rm", PackedStringArray(["-rf", ProjectSettings.globalize_path("user://profiles/" + id)]))
	_save()
	return true

func switch_to(id: String) -> void:
	if id == active or find(id).is_empty():
		return
	Config.save_now()
	active = id
	_save()
	Config.load_profile_file(_settings_path(id))
	var acc := str(current().get("steam", ""))
	if acc != "":
		GameSettings.set_steam_account(acc)
		GameSettings.apply_now()

func initials(p: Dictionary) -> String:
	var words := str(p.get("name", "?")).split(" ", false)
	var s := ""
	for w in words.slice(0, 2):
		s += w.substr(0, 1).to_upper()
	return s if s != "" else "?"

const COLOR_NAMES := {"7cc8ff": "Sky", "b58cff": "Violet", "ff8fb8": "Rose", "ffc76b": "Gold", "6ff2b5": "Mint", "ff7a5c": "Ember", "9fe0ff": "Ice", "e6e9ff": "Pearl"}

func color_name(hex: String) -> String:
	return COLOR_NAMES.get(hex, hex)
