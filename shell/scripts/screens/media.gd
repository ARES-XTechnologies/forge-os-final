class_name MediaScreen
extends Screen
## Media: your Steam screenshots, newest first, in a glass gallery with a full-screen viewer.

const THUMB := Vector2(392, 220)
const GAP := Vector2(28, 56)

var _title: Label
var _count: Label
var _grid: Control
var _items: Array = []        # {path, thumb, appid, time, node}
var _tiles: Array[Control] = []
var _focus := 0
var _cols := 4
var _scroll: Spring
var _empty: Label
var _tex := {}
var _loading := {}
var _scanned := false

func _ready() -> void:
	_title = Tokens.label("Media", 48, 700)
	add_child(_title)
	_count = Tokens.label("", 21, 500, Tokens.INK_DIM)
	add_child(_count)
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)
	_scroll = Spring.make(0.0, 230.0, 27.0)
	_empty = Tokens.label("Screenshots and clips you take in games show up here.\nWhile playing: Share or Guide + X for a screenshot, Guide + Y to save a clip.", 24, 500, Tokens.INK_DIM)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_empty)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	_title.position = Vector2(Tokens.SAFE_X, 160)
	_count.position = Vector2(Tokens.SAFE_X + _title.get_minimum_size().x + 22, 180)
	var avail := size.x - Tokens.SAFE_X * 2.0
	_cols = maxi(2, int((avail + GAP.x) / (THUMB.x + GAP.x)))
	_grid.position.x = Tokens.SAFE_X
	_empty.size = Vector2(size.x, 80)
	_empty.position = Vector2(0, 480)

func _scan() -> void:
	_items.clear()
	_scan_forge()
	var root := SteamLib.root
	if root == "":
		_items.sort_custom(func(a, b): return a.time > b.time)
		return
	var ud := DirAccess.open(root + "/userdata")
	if ud == null:
		return
	for u in ud.get_directories():
		var base := root + "/userdata/" + u + "/760/remote"
		var rd := DirAccess.open(base)
		if rd == null:
			continue
		for app in rd.get_directories():
			var sdir := base + "/" + app + "/screenshots"
			var sd := DirAccess.open(sdir)
			if sd == null:
				continue
			for f in sd.get_files():
				if f.ends_with(".jpg") or f.ends_with(".png"):
					var p := sdir + "/" + f
					var th := sdir + "/thumbnails/" + f
					_items.append({"path": p, "thumb": th if FileAccess.file_exists(th) else p, "appid": int(app) if app.is_valid_int() else 0, "time": FileAccess.get_modified_time(p)})
	_items.sort_custom(func(a, b): return a.time > b.time)

## FORGE's own captures: ~/Pictures/FORGE/<game>/*.png and ~/Videos/FORGE/<game>/*.mp4
func _scan_forge() -> void:
	var home := OS.get_environment("HOME")
	for kind in [["Pictures", ["png", "jpg"], "shot"], ["Videos", ["mp4", "mkv"], "clip"]]:
		var base: String = home + "/" + kind[0] + "/FORGE"
		var d := DirAccess.open(base)
		if d == null:
			continue
		for game in d.get_directories():
			var gd := DirAccess.open(base + "/" + game)
			if gd == null:
				continue
			for f in gd.get_files():
				if f.get_extension().to_lower() in kind[1]:
					var p: String = base + "/" + game + "/" + f
					_items.append({"path": p, "thumb": p if kind[2] == "shot" else "", "appid": 0, "game": game, "kind": kind[2], "time": FileAccess.get_modified_time(p)})

func _build() -> void:
	for t in _tiles:
		t.queue_free()
	_tiles.clear()
	for i in _items.size():
		var it: Dictionary = _items[i]
		var tile := GlassPanel.new()
		tile.radius = 22
		tile.bevel = 14
		tile.size = THUMB
		var img := TextureRect.new()
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.position = Vector2(6, 6)
		img.size = THUMB - Vector2(12, 12)
		img.name = "img"
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.clip_contents = true
		tile.add_child(img)
		var g: Dictionary = SteamLib.by_id.get(it.appid, {})
		var cap_text: String = g.get("name", it.get("game", "Screenshot"))
		if it.get("kind", "shot") == "clip":
			cap_text = "Clip  ·  " + cap_text
			var play := Icon.make("play", 54, Tokens.INK)
			play.position = (THUMB - Vector2(54, 54)) * 0.5
			tile.add_child(play)
			tile.tint_boost = 0.1
		var cap := Tokens.label(cap_text, 18, 600, Tokens.INK_DIM)
		cap.position = Vector2(8, THUMB.y + 12)
		cap.size = Vector2(THUMB.x - 16, 24)
		cap.clip_text = true
		tile.add_child(cap)
		tile.position = Vector2((i % _cols) * (THUMB.x + GAP.x), (i / _cols) * (THUMB.y + GAP.y))
		tile.set_meta("s", Spring.preset(1.0, &"bouncy"))
		tile.set_meta("appear", Spring.preset(1.0, &"bouncy"))
		tile.set_meta("delay", (i % _cols) * 0.04 + (i / _cols) * 0.06)
		_grid.add_child(tile)
		_tiles.append(tile)
	_count.text = "%d screenshot%s" % [_items.size(), "" if _items.size() == 1 else "s"]
	_empty.visible = _items.is_empty()
	_focus = clampi(_focus, 0, maxi(0, _items.size() - 1))
	_apply_focus()

func _load_thumb(i: int) -> void:
	var p: String = _items[i].thumb
	if p == "":
		return
	if _tex.has(p) or _loading.has(p):
		return
	_loading[p] = true
	var me := weakref(self)
	_bg.append(WorkerThreadPool.add_task(func():
		var img := Image.new()
		var ok := img.load(p) == OK
		if ok:
			if img.get_width() > 640:
				img.resize(640, int(640.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
			img.generate_mipmaps()
		var o = me.get_ref()
		if o:
			o._thumb_done.call_deferred(p, img if ok else null)))

func _thumb_done(p: String, img: Image) -> void:
	_collect_bg()
	_loading.erase(p)
	if img:
		_tex[p] = ImageTexture.create_from_image(img)
		for i in _items.size():
			if _items[i].thumb == p and i < _tiles.size():
				(_tiles[i].get_node("img") as TextureRect).texture = _tex[p]

func _apply_focus() -> void:
	for i in _tiles.size():
		var f := active and i == _focus
		_tiles[i].focus = 1.0 if f else 0.0
		(_tiles[i].get_meta("s") as Spring).target = 1.06 if f else 1.0
	if _tiles.size() > 0:
		_scroll.target = -maxf(0.0, _focus / _cols) * (THUMB.y + GAP.y)

func nav_action(a: StringName) -> bool:
	if _items.is_empty():
		return false
	var n := _focus
	match a:
		&"left": n -= 1
		&"right": n += 1
		&"up": n -= _cols
		&"down": n += _cols
		&"accept":
			if _items[_focus].get("kind", "shot") == "clip":
				shell.toast("Clips play on your PC or phone: press X to copy to USB", "play")
			else:
				_open_viewer()
			return true
		&"alt":
			_export([_items[_focus].path])
			return true
		&"menu":
			_export(_items.map(func(it): return it.path))
			return true
		_:
			return false
	if n < 0 or n >= _items.size() or (a in [&"left", &"right"] and n / _cols != _focus / _cols):
		Sfx.play("edge")
		return true
	_focus = n
	(_tiles[_focus].get_meta("s") as Spring).kick(1.2)
	_apply_focus()
	Sfx.focus_tick(_focus)
	return true

func _export(files: Array) -> void:
	shell.toast("Copying to USB…", "storage")
	Sys.export_to_usb(files, func(ok: bool, msg: String):
		shell.toast(msg, "check" if ok else "info", Tokens.OK if ok else Tokens.BAD))

func _open_viewer() -> void:
	var v := MediaViewer.new()
	v.shell = shell
	v.items = _items
	v.index = _focus
	shell.push_overlay(v)

func hints() -> Array:
	return [["A", "View"], ["X", "Copy to USB"], ["Y", "Copy all to USB"], ["LB+RB", "Switch"]] if not _items.is_empty() else [["LB+RB", "Switch"]]

func on_enter(_dir: int) -> void:
	_scan()
	_build()
	for t in _tiles:
		(t.get_meta("appear") as Spring).snap(1.0)

func tick(dt: float) -> void:
	_grid.position.y = 270 + _scroll.step(dt)
	for i in _tiles.size():
		var t := _tiles[i]
		var y := _grid.position.y + t.position.y
		var on := y + THUMB.y > 150 and y < size.y + 20
		t.visible = on
		if on:
			_load_thumb(i)
		var d: float = t.get_meta("delay")
		if d > 0.0:
			t.set_meta("delay", d - dt)
		else:
			(t.get_meta("appear") as Spring).target = 0.0
		var ap: float = (t.get_meta("appear") as Spring).step(dt)
		var s: float = (t.get_meta("s") as Spring).step(dt)
		t.pivot_offset = THUMB * 0.5
		t.scale = Vector2(s, s)
		t.modulate.a = clampf(1.0 - maxf(ap, 0.0) * 1.3, 0.0, 1.0) * clampf((y + THUMB.y - 260.0) / 100.0, 0.0, 1.0) * clampf((size.y - 110.0 - y) / 140.0, 0.0, 1.0)
		t.get_node("img").position.y = 6 + ap * 0.0
		t.position.y = (i / _cols) * (THUMB.y + GAP.y) + ap * 70.0


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
		WorkerThreadPool.wait_for_task_completion(t)
	_bg.clear()
