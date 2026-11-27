class_name LibraryScreen
extends Screen
## Library: every installed game, organised. Filter chips across the top, sort on Y,
## a responsive grid that cascades in like dominoes when you change the filter.

const CARD := Vector2(196, 294)
const GAP := Vector2(30, 40)
const ALL_FILTERS := [["all", "All"], ["installed", "Installed"], ["uninstalled", "Not installed"], ["stores", "Epic & GOG"], ["classics", "Classics"], ["local", "Your games"], ["favorites", "Favourites"], ["played", "Played"], ["updating", "Updating"], ["hidden", "Hidden"]]
var FILTERS: Array = []
const SORTS := [["recent", "Recently played"], ["name", "A–Z"], ["playtime", "Most played"], ["size", "Largest"], ["installed_date", "Recently updated"]]

var _title: Label
var _count: Label
var _chips: Array[PillButton] = []
var _sort_chip: PillButton
var _add_chip: PillButton
var _grid: Control
var _cards: Array[GameCard] = []
var _cols := 7
var _focus := 0
var _in_chips := false
var _chip_i := 0
var _scroll: Spring
var _empty: Label
var _letter: Label
var _letter_a: Spring

func _ready() -> void:
	_title = Tokens.label("Library", 48, 700)
	add_child(_title)
	_count = Tokens.label("", 21, 500, Tokens.INK_DIM)
	add_child(_count)
	_build_chips()
	_sort_chip = PillButton.make(_sort_label(), "sort", 52, 20)
	add_child(_sort_chip)
	_add_chip = PillButton.make("", "plus", 52, 20)
	add_child(_add_chip)
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)
	move_child(_grid, 0)        # cards slide *under* the title and filter buttons
	_scroll = Spring.make(0.0, 230.0, 27.0)
	_empty = Tokens.label("", 26, 500, Tokens.INK_DIM)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_empty)
	_letter = Tokens.label("", 180, 700, Color(1, 1, 1, 0.9))
	_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_letter)
	_letter_a = Spring.preset(0.0, &"smooth")
	SteamLib.library_changed.connect(func(): _rebuild(false))
	Config.changed.connect(func(k):
		if k == "library.favorites" or k == "library.hidden":
			for c in _cards: c.refresh_badges()
			if Config.get_s("library.filter") in ["favorites", "hidden", "all"]:
				_rebuild(false))
	resized.connect(_layout)
	_rebuild(false)
	_layout()

## Only show filters that have something in them (plus the basics).
func _build_chips() -> void:
	var want := []
	for f in ALL_FILTERS:
		var key: String = f[0]
		if key in ["all", "favorites"] or not SteamLib.sorted("name", key).is_empty():
			want.append(f)
	if want == FILTERS:
		return
	FILTERS = want
	for c in _chips:
		c.queue_free()
	_chips.clear()
	for f in FILTERS:
		var c := PillButton.make(f[1], "", 52, 20)
		add_child(c)
		_chips.append(c)
	if not FILTERS.any(func(f): return f[0] == Config.get_s("library.filter")):
		Config.set_v("library.filter", "all")

func _sort_label() -> String:
	var s := Config.get_s("library.sort")
	for o in SORTS:
		if o[0] == s:
			return o[1]
	return "Sort"

func _layout() -> void:
	_title.position = Vector2(Tokens.SAFE_X, 160)
	_count.position = Vector2(Tokens.SAFE_X + _title.get_minimum_size().x + 22, 180)
	var x := Tokens.SAFE_X
	for c in _chips:
		c.position = Vector2(x, 246)
		x += c.size.x + 14
	_sort_chip.position = Vector2(size.x - Tokens.SAFE_X - _sort_chip.size.x, 246)
	_add_chip.position = Vector2(_sort_chip.position.x - _add_chip.size.x - 14, 246)
	var avail := size.x - Tokens.SAFE_X * 2.0
	_cols = maxi(3, int((avail + GAP.x) / (CARD.x + GAP.x)))
	var used := _cols * CARD.x + (_cols - 1) * GAP.x
	_grid.position = Vector2(Tokens.SAFE_X + (avail - used) * 0.5, GRID_TOP + _scroll.value)
	_empty.position = Vector2(0, 520)
	_empty.size = Vector2(size.x, 40)
	_letter.size = Vector2(size.x, 300)
	_letter.position = Vector2(0, 420)
	_place_all()

func _rebuild(cascade := true) -> void:
	var keep := -1
	if _focus < _cards.size():
		keep = _cards[_focus].game.appid
	for c in _cards:
		c.queue_free()
	_cards.clear()
	_build_chips()
	var filter := Config.get_s("library.filter")
	var list := SteamLib.sorted(Config.get_s("library.sort"), filter)
	for g in list:
		var c := GameCard.make(g, CARD)
		c.dim_others = 0.0
		_grid.add_child(c)
		_cards.append(c)
	_focus = 0
	for i in _cards.size():
		if _cards[i].game.appid == keep:
			_focus = i
	if _cards.is_empty():
		_in_chips = true
		_chip_i = _chips.size()          # the "+" Add a game button
	elif _in_chips and _chip_i == _chips.size() and keep == -1:
		_in_chips = false
	for i in _chips.size():
		_chips[i].selected = FILTERS[i][0] == filter
	_count.text = "%d game%s  ·  %d installed  ·  %s" % [list.size(), "" if list.size() == 1 else "s", SteamLib.total_installed(), SteamLib.fmt_size(SteamLib.total_size())]
	_empty.text = "" if not list.is_empty() else ("Nothing here yet" if filter != "all" else "Install games in Steam, or choose Add a game at the top right")
	_layout()
	_scroll.snap(_scroll_target())
	_apply_focus(true)
	if cascade:
		_cascade()

func _cascade() -> void:
	for i in _cards.size():
		var r := i / _cols
		var c := i % _cols
		var rr := (i - _focus) / _cols
		_cards[i].appear(0.02 + (absi(rr) + c) * 0.028, 70.0 + r * 4.0)

func _place_all() -> void:
	for i in _cards.size():
		_cards[i].position = Vector2((i % _cols) * (CARD.x + GAP.x), (i / _cols) * (CARD.y + GAP.y))

const GRID_TOP := 350.0
const BOTTOM_MARGIN := 100.0     # room for the hint bar

## Scroll only when the focused row would be cut off, and only as far as needed.
func _scroll_target() -> float:
	if _cards.is_empty():
		return 0.0
	var row_h := CARD.y + GAP.y
	var row := _focus / _cols
	var rows := (_cards.size() + _cols - 1) / _cols
	var view_bottom := size.y - BOTTOM_MARGIN
	var max_off := maxf(0.0, GRID_TOP + rows * row_h - GAP.y - view_bottom)
	var off := -_scroll.target
	var top := GRID_TOP + row * row_h - off
	if top + CARD.y > view_bottom:
		off += top + CARD.y - view_bottom + 24.0
	elif top < GRID_TOP:
		off = row * row_h
	if row == 0:
		off = 0.0
	return -clampf(off, 0.0, max_off + 24.0)

func _apply_focus(silent := false) -> void:
	for i in _cards.size():
		_cards[i].set_focused(active and not _in_chips and i == _focus, silent)
	for i in _chips.size():
		_chips[i].set_focused(active and _in_chips and i == _chip_i)
	_add_chip.set_focused(active and _in_chips and _chip_i == _chips.size())
	_sort_chip.set_focused(active and _in_chips and _chip_i == _chips.size() + 1)
	_scroll.target = 0.0 if _in_chips else _scroll_target()

func _move(dx: int, dy: int) -> void:
	if _in_chips:
		if dy > 0:
			if _cards.is_empty():
				Sfx.play("edge")
				return
			_in_chips = false
			_focus = mini(_focus, _cards.size() - 1)
			_apply_focus()
			Sfx.focus_tick(2)
			return
		if dy < 0:
			Sfx.play("edge")
			return
		var n := _chip_i + dx
		if n < 0 or n > _chips.size() + 1:
			Sfx.play("edge")
			return
		_chip_i = n
		_apply_focus()
		Sfx.focus_tick(_chip_i)
		return
	var col := _focus % _cols
	var n2 := _focus
	if dx != 0:
		n2 = _focus + dx
		if n2 < 0 or n2 >= _cards.size() or (n2 / _cols) != (_focus / _cols):
			_cards[_focus].nudge(dx * 300.0)
			Sfx.play("edge")
			return
	if dy != 0:
		n2 = _focus + dy * _cols
		if dy < 0 and n2 < 0:
			_in_chips = true
			var fi := FILTERS.map(func(f): return f[0]).find(Config.get_s("library.filter"))
			_chip_i = maxi(0, fi)
			_apply_focus()
			Sfx.focus_tick(0)
			return
		if n2 >= _cards.size():
			if (_cards.size() - 1) / _cols > _focus / _cols:
				n2 = _cards.size() - 1
			else:
				_scroll.kick(-dy * 500.0)
				Sfx.play("edge")
				return
	var prev := _focus
	_focus = n2
	_apply_focus()
	Sfx.focus_tick(_focus % _cols + (_focus / _cols))
	_cards[prev].nudge(dx * 140.0)
	if _focus / _cols != prev / _cols:
		# the whole grid lurches slightly in the direction of travel
		for c in _cards:
			c.s_lift.kick(dy * -60.0)
	_flash_letter()

func _flash_letter() -> void:
	if Config.get_s("library.sort") != "name" or _focus >= _cards.size():
		return
	var n: String = _cards[_focus].game.sort_name
	var l := n.substr(0, 1).to_upper() if n != "" else ""
	if l != _letter.text or Nav.repeating:
		_letter.text = l
		if Nav.repeating:
			_letter_a.snap(1.0)
		_letter_a.target = 0.0

func nav_action(a: StringName) -> bool:
	match a:
		&"left": _move(-1, 0)
		&"right": _move(1, 0)
		&"up": _move(0, -1)
		&"down": _move(0, 1)
		&"page_prev": if not _in_chips: _jump(-3)
		&"page_next": if not _in_chips: _jump(3)
		&"accept":
			if _in_chips:
				if _chip_i < _chips.size():
					_chips[_chip_i].press()
					Config.set_v("library.filter", FILTERS[_chip_i][0])
					_rebuild(true)
				elif _chip_i == _chips.size():
					_add_chip.press()
					shell.open_add_game()
				else:
					_cycle_sort()
			elif _focus < _cards.size():
				_cards[_focus].press()
				shell.launch(_cards[_focus].game, _cards[_focus])
		&"alt":
			if not _in_chips and _focus < _cards.size():
				_cards[_focus].press()
				shell.open_game(_cards[_focus].game)
		&"menu":
			_cycle_sort()
		&"start":
			shell.open_search()
		&"back":
			if not _in_chips and _focus >= _cols:
				_focus = _focus % _cols
				_apply_focus()
				Sfx.back()
				return true
			return false
		_:
			return false
	return true

func _jump(rows: int) -> void:
	if _cards.is_empty():
		return
	var n := clampi(_focus + rows * _cols, 0, _cards.size() - 1)
	if n == _focus:
		Sfx.play("edge")
		return
	_focus = n
	_apply_focus()
	Sfx.play("tab")
	_letter_a.snap(1.0)
	_flash_letter()

func _cycle_sort() -> void:
	var s := Config.get_s("library.sort")
	var i := 0
	for k in SORTS.size():
		if SORTS[k][0] == s:
			i = k
	i = (i + 1) % SORTS.size()
	Config.set_v("library.sort", SORTS[i][0])
	_sort_chip.text = _sort_label()
	_sort_chip.press()
	_layout()
	_rebuild(true)
	shell.toast("Sorted by " + SORTS[i][1].to_lower(), "sort")

func hints() -> Array:
	if _in_chips:
		return [["A", "Select"], ["Y", "Sort"], ["LB+RB", "Switch"]]
	return [["A", "Play"], ["X", "Details"], ["Y", "Sort"], ["☰", "Search"], ["LT+RT", "Jump"]]

func on_enter(_dir: int) -> void:
	# Coming down from the tabs, focus lands on the row right under them (filters, + and
	# sort); press down to reach the games. With no games yet, start on "+" Add a game.
	_in_chips = true
	if _cards.is_empty():
		_chip_i = _chips.size()
	else:
		_chip_i = maxi(0, FILTERS.map(func(f): return f[0]).find(Config.get_s("library.filter")))
	_scroll.target = 0.0
	_apply_focus(true)
	if not _in_chips and _focus < _cards.size():
		_cards[_focus].set_focused(false, true)
		_cards[_focus].set_focused(true)
	_cascade()

func on_leave() -> void:
	for c in _cards:
		c.set_focused(false, true)
	for c in _chips:
		c.set_focused(false)
	_sort_chip.set_focused(false)
	_add_chip.set_focused(false)

func tick(dt: float) -> void:
	var s := _scroll.step(dt)
	_grid.position.y = GRID_TOP + s
	var la := _letter_a.step(dt)
	_letter.modulate.a = clampf(la, 0.0, 1.0) * 0.55
	_letter.pivot_offset = _letter.size * 0.5
	_letter.scale = Vector2.ONE * (1.0 + (1.0 - clampf(la, 0.0, 1.0)) * 0.2)
	# cards above the chips fade out so the header stays clean
	for c in _cards:
		var y := _grid.position.y + c.position.y
		var vis_top := clampf((y - (GRID_TOP - 90.0)) / 90.0, 0.0, 1.0)
		var vis_bot := clampf((size.y - 40.0 - (y + CARD.y)) / 90.0 + 0.4, 0.0, 1.0)
		var on_screen := y + CARD.y > 220.0 and y < size.y + 40.0
		c.visible = on_screen
		if on_screen:
			c.fade = minf(vis_top, vis_bot)
	if active and _focus < _cards.size() and shell:
		var c := _cards[_focus]
		shell.wallpaper.look_at_point(Vector2((c.position.x + _grid.position.x) / maxf(size.x, 1.0) * 2.0 - 1.0, (_focus / _cols) * 0.1))

# ------------------------------------------------------------------ mouse
## _input (not _unhandled_input): the full-screen controls above would swallow the click.
func _input(e: InputEvent) -> void:
	if not active or not visible or shell == null or not Nav.is_top(shell) or Nav.passthrough:
		return
	if not (e is InputEventMouseButton and e.pressed):
		return
	match e.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_move(0, -1)
		MOUSE_BUTTON_WHEEL_DOWN:
			_move(0, 1)
		MOUSE_BUTTON_LEFT:
			var p: Vector2 = get_global_transform().affine_inverse() * e.global_position
			var buttons: Array = _chips.duplicate()
			buttons.append(_add_chip)
			buttons.append(_sort_chip)
			for i in buttons.size():
				var b: Control = buttons[i]
				if Rect2(b.position, b.size).has_point(p):
					_in_chips = true
					_chip_i = i
					_apply_focus()
					nav_action(&"accept")
					shell.refresh_hints()
					get_viewport().set_input_as_handled()
					return
			for i in _cards.size():
				var c := _cards[i]
				if c.visible and Rect2(_grid.position + c.position, CARD).has_point(p):
					if _in_chips or i != _focus:
						_in_chips = false
						_focus = i
						_apply_focus()
						Sfx.focus_tick(i)
					else:
						nav_action(&"accept")
					shell.refresh_hints()
					get_viewport().set_input_as_handled()
					return
		_:
			return
	shell.refresh_hints()
	get_viewport().set_input_as_handled()
