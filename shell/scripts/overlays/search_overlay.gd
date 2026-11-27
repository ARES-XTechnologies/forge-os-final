class_name SearchOverlay
extends Overlay
## Live search across the library. Results update on every key press.
## Type with the keyboard, press Done to move into the results.

const CARD := Vector2(170, 255)
var _query := ""
var _title: Label
var _sub: Label
var _row: Control
var _cards: Array[GameCard] = []
var _focus := 0
var _row_x: Spring
var _in_results := false
var _kb: Keyboard

func build() -> void:
	from_offset = Vector2(0, -60)
	var c := Control.new()
	c.name = "content"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(1720, 420)
	add_child(c)
	var ic := Icon.make("search", 40)
	ic.position = Vector2(0, 8)
	c.add_child(ic)
	_title = Tokens.label("Search your games", 44, 700)
	_title.position = Vector2(60, 0)
	c.add_child(_title)
	_sub = Tokens.label("Start typing", 21, 500, Tokens.INK_DIM)
	_sub.position = Vector2(62, 60)
	c.add_child(_sub)
	_row = Control.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.position = Vector2(0, 120)
	c.add_child(_row)
	_row_x = Spring.preset(0.0, &"snappy")
	_open_kb.call_deferred()

func _content_base() -> Vector2:
	return Vector2(Tokens.SAFE_X, 140)

func _open_kb() -> void:
	_in_results = false
	_kb = shell.open_keyboard("Search", _query, false, func(_t):
		_kb = null
		if _cards.is_empty():
			close()
		else:
			_in_results = true
			_apply_focus()
			Nav.push(self)
			shell.hint_bar.set_hints(hints()), func(t): _update(t))
	# Keyboard closed with B: close search too.
	_kb.tree_exiting.connect(func():
		if not _in_results and not closing:
			close())

func _update(q: String) -> void:
	_query = q
	var res := SteamLib.search(q)
	for c in _cards:
		c.queue_free()
	_cards.clear()
	_title.text = q if q != "" else "Search your games"
	_sub.text = "Start typing" if q == "" else ("No matches" if res.is_empty() else "%d result%s" % [res.size(), "" if res.size() == 1 else "s"])
	var i := 0
	for g in res.slice(0, 20):
		var card := GameCard.make(g, CARD)
		_row.add_child(card)
		card.position = Vector2(i * (CARD.x + 24), 0)
		card.appear(i * 0.03, 50)
		_cards.append(card)
		i += 1
	_focus = 0
	_row_x.snap(0.0)

func _apply_focus() -> void:
	for i in _cards.size():
		_cards[i].set_focused(_in_results and i == _focus)
	_row_x.target = -maxf(0.0, _focus - 4) * (CARD.x + 24)

func nav_action(a: StringName) -> bool:
	if not _in_results:
		return true
	match a:
		&"left", &"right":
			var n := _focus + (1 if a == &"right" else -1)
			if n < 0 or n >= _cards.size():
				Sfx.play("edge")
			else:
				_focus = n
				_apply_focus()
				Sfx.focus_tick(_focus)
		&"accept":
			var g := _cards[_focus].game
			_cards[_focus].press()
			close()
			shell.launch(g, null)
		&"alt":
			var g2 := _cards[_focus].game
			close()
			shell.open_game(g2)
		&"menu", &"up":
			Nav.pop(self)
			_apply_focus()
			_open_kb()
		&"back":
			close()
	return true

func hints() -> Array:
	return [["A", "Play"], ["X", "Details"], ["Y", "Edit search"], ["B", "Close"]]

func on_close() -> void:
	if _kb and is_instance_valid(_kb):
		_kb.close()

func animate(o: float, dt: float) -> void:
	super.animate(o, dt)
	_row.position.x = _row_x.step(dt)
