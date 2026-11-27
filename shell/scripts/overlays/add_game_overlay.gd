class_name AddGameOverlay
extends Overlay
## Add a game you have on disk. FORGE suggests the name, finds the official art on
## Steam's store (or uses the .exe icon), and lets you choose Proton and launch options.
## Also used to edit a game you already added (edit_id set).

var path := ""
var edit_id := 0                     # non-zero = editing an existing local game
var _name := ""
var _matches: Array = []             # Steam store matches
var _choice := -1                    # index into _matches, -1 = icon / none
var _icon := ""
var _proton := ""
var _args := ""
var _card: GlassPanel
var _list: RowList
var _preview: TextureRect
var _preview_glass: GlassPanel
var _preview_name: Label
var _pop: Spring
var _searching := false

func build() -> void:
	from_offset = Vector2(0, 80)
	if edit_id != 0:
		var g := LocalGames.find(edit_id)
		path = str(g.get("path", ""))
		_name = str(g.get("name", ""))
		_proton = str(g.get("proton", ""))
		_args = str(g.get("args", ""))
	else:
		_name = LocalGames.suggest_name(path)
	_card = GlassPanel.new()
	_card.name = "content"
	_card.radius = 46
	_card.body_dim = 0.95
	_card.size = Vector2(1400, 820)
	add_child(_card)
	var t := Tokens.label("Edit game" if edit_id != 0 else "Add to your library", 40, 700)
	t.position = Vector2(52, 38)
	_card.add_child(t)
	# preview card
	_preview_glass = GlassPanel.new()
	_preview_glass.radius = 28
	_preview_glass.size = Vector2(300, 450)
	_preview_glass.position = Vector2(56, 128)
	_preview_glass.nested = true
	_preview_glass.focus = 0.6
	_card.add_child(_preview_glass)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview.position = Vector2(10, 10)
	_preview.size = Vector2(280, 430)
	_preview.clip_contents = true
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_glass.add_child(_preview)
	_preview_name = Tokens.label("", 26, 700)
	_preview_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_name.position = Vector2(20, 0)
	_preview_name.size = Vector2(260, 450)
	_preview_glass.add_child(_preview_name)
	_pop = Spring.preset(1.0, &"jelly")
	var src := Tokens.label("", 16, 600, Tokens.INK_FAINT)
	src.name = "src"
	src.position = Vector2(58, 596)
	src.size = Vector2(300, 60)
	src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(src)
	src.text = ("On a USB drive" if path.begins_with("/run/media/") else "On this console") + "\n" + path.get_file()
	_list = RowList.new()
	_list.position = Vector2(390, 118)
	_list.size = Vector2(990, 690)
	_card.add_child(_list)
	Art.url_ready.connect(func(_u): _refresh_preview())
	_rebuild()
	LocalGames.extract_icon(path, func(p: String):
		_icon = p
		_refresh_preview())
	if edit_id != 0:
		var g2 := LocalGames.find(edit_id)
		if int(g2.get("steam_appid", 0)) > 0:
			_matches = [{"appid": int(g2.steam_appid), "name": _name, "image": ""}]
			_choice = 0
	_search(_name)

func _search(term: String) -> void:
	_searching = true
	_rebuild()
	LocalGames.search_steam(term, func(list: Array):
		_searching = false
		var keep = _matches[_choice] if _choice >= 0 and _choice < _matches.size() else null
		_matches = list
		_choice = -1
		if keep != null:
			for i in _matches.size():
				if int(_matches[i].appid) == int(keep.appid):
					_choice = i
		if _choice < 0 and not _matches.is_empty() and edit_id == 0 and _similar(_matches[0].name, _name):
			_choice = 0
		_rebuild()
		_refresh_preview())

func _similar(a: String, b: String) -> bool:
	var x := a.to_lower().replace(":", "").replace("-", " ").strip_edges()
	var y := b.to_lower().replace(":", "").replace("-", " ").strip_edges()
	return x == y or x.begins_with(y) or y.begins_with(x) or x.similarity(y) > 0.72

func _portrait_url() -> String:
	if _choice >= 0 and _choice < _matches.size():
		return "https://shared.steamstatic.com/store_item_assets/steam/apps/%d/library_600x900_2x.jpg" % int(_matches[_choice].appid)
	return ""

func _refresh_preview() -> void:
	var url := _portrait_url()
	var tex: Texture2D = null
	if url != "":
		tex = Art.get_url_tex(url)
		if tex == null:
			# no tall cover for this game: fall back to its wide header
			tex = Art.get_url_tex(url.replace("library_600x900_2x.jpg", "header.jpg"))
	elif _icon != "":
		var img := Image.new()
		if img.load(_icon) == OK:
			tex = ImageTexture.create_from_image(img)
	_preview.texture = tex
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if url != "" else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.size = Vector2(280, 430) if url != "" else Vector2(140, 140)
	_preview.position = Vector2(10, 10) if url != "" else Vector2(80, 110)
	_preview_name.text = "" if url != "" else _name
	_preview_name.position.y = 70 if url == "" and _icon != "" else 0

func _rebuild() -> void:
	var rows: Array = []
	rows.append(SettingRow.action("Name", func():
		shell.open_keyboard("Game name", _name, false, func(t: String):
			if t.strip_edges() != "":
				_name = t.strip_edges()
				_refresh_preview()
				_search(_name)), "keyboard", "", func(): return _name))
	var windows := LocalGames.kind_for(path) == "windows"
	rows.append(SettingRow.info("Runs with", func(): return "Proton (Windows game)" if windows else "Linux (native)", "wrench"))
	if windows:
		var pr := SettingRow.choice("Proton version", "", LocalGames.proton_options(), "wrench", "UMU-Proton downloads by itself the first time")
		pr.getter = func(): return _proton
		pr.setter = func(v): _proton = v
		rows.append(pr)
	rows.append(SettingRow.action("Launch options", func():
		shell.open_keyboard("Launch options (optional)", _args, false, func(t: String):
			_args = t.strip_edges()
			_list.refresh_all()), "keyboard", "", func(): return _args if _args != "" else "None"))
	rows.append(SettingRow.header("Artwork"))
	if _searching:
		rows.append(SettingRow.info("Looking for official art…", func(): return "", "search"))
	for i in _matches.size():
		var idx := i
		var m: Dictionary = _matches[i]
		rows.append(SettingRow.action(str(m.name), func():
			_choice = idx
			_pop.kick(-3.0)
			_refresh_preview()
			_list.refresh_all(), "image", "Official Steam art", func(): return "✓ Using this" if _choice == idx else ""))
	rows.append(SettingRow.action("Use the game's own icon", func():
		_choice = -1
		_refresh_preview()
		_list.refresh_all(), "sparkle", "", func(): return "✓ Using this" if _choice == -1 else ""))
	rows.append(SettingRow.action("Search with a different name", func():
		shell.open_keyboard("Search Steam for", _name, false, func(t: String): _search(t)), "search"))
	rows.append(SettingRow.header(""))
	rows.append(SettingRow.action("Save changes" if edit_id != 0 else "Add to library", _commit, "check"))
	if edit_id != 0:
		rows.append(SettingRow.action("Remove from library", func():
			shell.confirm("Remove %s?" % _name, "Only the shortcut goes. Your game files stay where they are.", [["Remove", "trash"], ["Cancel", "close"]], func(i):
				if i == 0:
					LocalGames.remove(edit_id)
					shell.toast("Removed " + _name, "trash")
					close()), "trash"))
	var keep := _list.index if _list.rows.size() > 0 else 0
	_list.set_rows(rows)
	_list.index = mini(keep, rows.size() - 1)
	_list.set_active(true)

func _commit() -> void:
	var sid := int(_matches[_choice].appid) if _choice >= 0 and _choice < _matches.size() else 0
	var art := {}
	if sid == 0 and _icon != "":
		art = {"icon": _icon, "header": _icon}
	var g: Dictionary
	if edit_id != 0:
		LocalGames.update(edit_id, "name", _name)
		LocalGames.update(edit_id, "steam_appid", sid)
		LocalGames.update(edit_id, "art", art)
		g = LocalGames.find(edit_id)
	else:
		g = LocalGames.add(path, _name, sid, art)
	LocalGames.update(int(g.id), "proton", _proton)
	LocalGames.update(int(g.id), "args", _args)
	Shellbus.notify({"title": ("Saved " if edit_id != 0 else "Added ") + _name, "body": "Find it in your Library", "icon": "check", "color": Tokens.OK, "appid": int(g.id)})
	SteamLib.rescan()
	close()

func nav_action(a: StringName) -> bool:
	if a == &"back":
		close()
		return true
	_list.handle(a)
	return true

func hints() -> Array:
	return [["A", "Select"], ["◀▶", "Change"], ["B", "Cancel"]]

func animate(o: float, dt: float) -> void:
	super.animate(o, dt)
	var p := _pop.step(dt)
	_preview_glass.pivot_offset = _preview_glass.size * 0.5
	_preview_glass.scale = Vector2(p, p)
