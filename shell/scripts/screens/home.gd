class_name HomeScreen
extends Screen
## Home: one cinematic row of your games. The focused game takes over the screen —
## its official hero art drifts behind glass, its logo springs in, and every card in
## the row reacts to your movement like it's floating on water.

const HERO_SHADER := preload("res://shaders/hero.gdshader")
const CARD := Vector2(214, 321)
const GAP := 30.0
const ROW_Y := 620.0

var _hero: ColorRect
var _hero_mat: ShaderMaterial
var _hero_mix: Spring
var _hero_slot := 0              # which texture slot is showing (0 = a, 1 = b)
var _hero_appid := -1
var _hero_wait := 0.0
var _drift := 0.0

var _info: Control
var _logo: TextureRect
var _title: Label
var _meta: Label
var _caption: Label
var _logo_y: Spring
var _logo_a: Spring
var _info_appid := -1
var _info_pending := false

var _row: Control
var _cards: Array[GameCard] = []
var _gaps: Array[Spring] = []
var _row_x: Spring
var focus := 0
var _ripples: Array = []          # [card, impulse, delay]
var _empty: Control
var _built_once := false

func _ready() -> void:
	_hero = ColorRect.new()
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_mat = ShaderMaterial.new()
	_hero_mat.shader = HERO_SHADER
	_hero.material = _hero_mat
	add_child(_hero)
	_hero_mix = Spring.preset(0.0, &"glide")

	_info = Control.new()
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info)
	_logo = TextureRect.new()
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(_logo)
	_title = Tokens.label("", 76, 700)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_title.add_theme_constant_override("line_spacing", -14)
	_info.add_child(_title)
	_meta = Tokens.label("", 23, 500, Tokens.INK_DIM)
	_info.add_child(_meta)
	_logo_y = Spring.preset(0.0, &"bouncy")
	_logo_a = Spring.preset(0.0, &"smooth")

	_caption = Tokens.label("", 17, 600, Tokens.INK_FAINT)
	_caption.visible = false
	add_child(_caption)

	_row = Control.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_row_x = Spring.make(0.0, 260.0, 25.0)

	SteamLib.library_changed.connect(_rebuild)
	Art.art_ready.connect(_on_art)
	resized.connect(_layout)
	_rebuild()
	_layout()

func _layout() -> void:
	_hero.position = Vector2.ZERO
	_hero.size = Vector2(size.x, 800)
	_hero_mat.set_shader_parameter("view", _hero.size)
	_info.position = Vector2(Tokens.SAFE_X, 0)
	_info.size = Vector2(minf(820.0, size.x * 0.45), 560)
	_logo.size = Vector2(minf(640.0, size.x * 0.36), 230)
	_title.size = Vector2(_info.size.x, 230)
	_caption.position = Vector2(Tokens.SAFE_X + 4, ROW_Y - 46)
	if _empty:
		_empty.position = (size - _empty.size) * 0.5 + Vector2(0, 80)

# ------------------------------------------------------------------ building
func _rebuild() -> void:
	var keep_id := -1
	if focus < _cards.size():
		keep_id = _cards[focus].game.get("appid", -1)
	for c in _cards:
		c.queue_free()
	_cards.clear()
	_gaps.clear()
	var games := SteamLib.recent(14)
	for g in games:
		_add_card(GameCard.make(g, CARD))
	if not games.is_empty():
		var all := GameCard.make({"name": "All games"}, CARD)
		all.kind = "all_games"
		_add_card(all)
	focus = 0
	for i in _cards.size():
		if _cards[i].game.get("appid", -2) == keep_id:
			focus = i
	_row_x.snap(_target_x())
	_update_focus(true)
	_set_empty(games.is_empty())
	if active:
		_cascade()
		if shell:
			shell.refresh_hints()
	_built_once = true

func _add_card(c: GameCard) -> void:
	_row.add_child(c)
	c.dim_others = 0.22
	_cards.append(c)
	_gaps.append(Spring.preset(0.0, &"snappy"))

func _set_empty(empty: bool) -> void:
	if empty and _empty == null:
		_empty = GlassPanel.new()
		(_empty as GlassPanel).body_dim = 0.4
		_empty.size = Vector2(760, 300)
		var ic := Icon.make("steam", 64)
		ic.position = Vector2(348, 44)
		_empty.add_child(ic)
		var t := Tokens.label("No games installed yet", 34, 700)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.size = Vector2(760, 40)
		t.position = Vector2(0, 128)
		_empty.add_child(t)
		var msg := "Sign in to Steam when it asks, then install games from the Steam app on\nyour phone or another PC. They'll appear here on their own."
		if not SteamLib.has_steam():
			msg = "Steam is starting up for the first time.\nThis can take a few minutes. Your games will appear here."
		var s := Tokens.label(msg, 20, 400, Tokens.INK_DIM)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.size = Vector2(760, 60)
		s.position = Vector2(0, 186)
		_empty.add_child(s)
		add_child(_empty)
		_layout()
	if _empty:
		_empty.visible = empty

func _cascade() -> void:
	for i in _cards.size():
		var d := absi(i - focus)
		_cards[i].appear(0.05 + d * 0.045, 110.0 + d * 6.0)
	_logo_a.snap(0.0)
	_logo_y.snap(40.0)
	_logo_y.target = 0.0
	_logo_a.target = 1.0

# ------------------------------------------------------------------ focus
func _target_x() -> float:
	return Tokens.SAFE_X + 6.0 - focus * (CARD.x + GAP)

func _update_focus(silent := false) -> void:
	for i in _cards.size():
		_cards[i].set_focused(i == focus and active, silent)
		_gaps[i].target = 0.0 if i == focus else (CARD.x * 0.065 * signf(i - focus))
	var g := _focused_game()
	if g.get("appid", -1) != _info_appid:
		_info_pending = true
		_logo_a.target = 0.0
		_logo_y.target = -10.0
	_hero_wait = 0.14

func _focused_game() -> Dictionary:
	if focus < _cards.size() and _cards[focus].kind == "game":
		return _cards[focus].game
	return {}

func _move(d: int) -> void:
	var n := focus + d
	if n < 0 or n >= _cards.size():
		Sfx.play("edge")
		Sfx.haptic(0.0, 0.25, 40)
		_row_x.kick(-d * 420.0)
		if focus < _cards.size():
			_cards[focus].nudge(-d * 260.0)
		return
	var prev := focus
	focus = n
	_row_x.target = _target_x()
	_update_focus()
	Sfx.focus_tick(focus)
	# Ripple: neighbours get pushed in the direction of travel, closer = stronger, later = further.
	for i in _cards.size():
		if i == focus or i == prev:
			continue
		var dist := absi(i - focus)
		if dist > 6:
			continue
		_ripples.append([_cards[i], d * 340.0 / (dist + 0.6), dist * 0.035])
	_cards[prev].nudge(d * 120.0)

func nav_action(a: StringName) -> bool:
	if _cards.is_empty():
		return false
	match a:
		&"left": _move(-1)
		&"right": _move(1)
		&"page_prev": _move(-mini(5, focus)) if focus > 0 else _move(-1)
		&"page_next": _move(mini(5, _cards.size() - 1 - focus)) if focus < _cards.size() - 1 else _move(1)
		&"accept":
			var c := _cards[focus]
			c.press()
			if c.kind == "all_games":
				Sfx.confirm()
				shell.go_tab(1)
			else:
				shell.launch(c.game, c)
		&"alt":
			if _cards[focus].kind == "game":
				Sfx.play("open")
				_cards[focus].press()
				shell.open_game(_cards[focus].game)
		&"menu":
			shell.open_search()
		_:
			return false
	return true

func hints() -> Array:
	if _cards.is_empty():
		return [["LB+RB", "Switch"], ["⌂", "Quick menu"]]
	return [["A", "Play"], ["X", "Details"], ["Y", "Search"], ["LB+RB", "Switch"], ["⌂", "Quick menu"]]

func focused_card() -> GameCard:
	return _cards[focus] if focus < _cards.size() else null

# ------------------------------------------------------------------ lifecycle
func on_enter(_dir: int) -> void:
	_update_focus(true)
	if _cards.size() > focus:
		_cards[focus].set_focused(false, true)
		_cards[focus].set_focused(true)
	_cascade()

func on_leave() -> void:
	for c in _cards:
		c.set_focused(false, true)
	if shell:
		shell.wallpaper.set_game_color(null, false)

func _on_art(appid: int, kind: String) -> void:
	var g := _focused_game()
	if g.get("appid", -1) != appid:
		return
	if kind == "hero" and appid == _hero_appid:
		_show_hero(appid, true)
	if kind == "logo" and appid == _info_appid:
		_apply_info(g)
	if (kind == "portrait" or kind == "hero") and appid == _info_appid and shell:
		shell.wallpaper.set_game_color(Art.colors.get(appid, null))

func _show_hero(appid: int, refresh := false) -> void:
	var tex := Art.get_tex(appid, "hero")
	if tex == null:
		tex = Art.get_tex(appid, "header") if Art.is_missing(appid, "hero") else null
	if not refresh:
		_hero_slot = 1 - _hero_slot
	var slot := "a" if _hero_slot == 0 else "b"
	_hero_mat.set_shader_parameter("tex_" + slot, tex)
	_hero_mat.set_shader_parameter("has_" + slot, tex != null)
	if tex:
		_hero_mat.set_shader_parameter("size_" + slot, Vector2(tex.get_size()))
	_hero_mix.target = float(_hero_slot)

func _apply_info(g: Dictionary) -> void:
	_info_appid = g.get("appid", -1)
	var logo := Art.get_tex(_info_appid, "logo") if _info_appid > 0 else null
	_logo.texture = logo
	if logo:
		# Fit the logo inside 640×210, keeping its shape; bottom-left aligned in tick().
		var box := Vector2(minf(640.0, size.x * 0.36), 210.0)
		var k := minf(box.x / logo.get_width(), box.y / logo.get_height())
		_logo.size = Vector2(logo.get_size()) * k
	_logo.visible = logo != null
	_title.visible = logo == null
	_title.text = g.get("name", "")
	if g.is_empty():
		_meta.text = ""
	else:
		var parts := [SteamLib.fmt_last_played(g.last_played), SteamLib.fmt_playtime(g.playtime)]
		if g.get("updating", false):
			parts.append("Updating %d%%" % int(g.progress * 100.0))
		elif not g.get("installed", true):
			parts = ["Not installed", "Press A to download"]
		if g.get("missing", false):
			parts = ["Drive not connected"]
		var src := str(g.get("source", "steam"))
		if src != "steam":
			parts.push_front(SteamLib.source_label(g))
		_meta.text = "   ·   ".join(parts)
	if shell:
		shell.wallpaper.set_game_color(Art.colors.get(_info_appid, null), not g.is_empty())

func tick(dt: float) -> void:
	_drift += dt
	_hero_mat.set_shader_parameter("drift", _drift)
	_hero_mat.set_shader_parameter("mix_ab", clampf(_hero_mix.step(dt), 0.0, 1.0))
	if _hero_wait > 0.0:
		_hero_wait -= dt
		if _hero_wait <= 0.0:
			var g := _focused_game()
			var id: int = g.get("appid", -1)
			if id != _hero_appid:
				_hero_appid = id
				_show_hero(id)
	# info block swap once the old logo has faded out
	var la := _logo_a.step(dt)
	var ly := _logo_y.step(dt)
	if _info_pending and (la < 0.08 or _logo_a.target > 0.5):
		_info_pending = false
		_apply_info(_focused_game())
		_logo_y.snap(34.0)
		_logo_y.target = 0.0
		_logo_a.target = 1.0
	var base_y := 470.0
	_logo.position = Vector2(0, base_y - _logo.size.y + ly)
	_title.position = Vector2(0, base_y - _title.size.y + ly)
	_meta.position = Vector2(4, base_y + 22 + ly * 0.6)
	_info.modulate.a = clampf(la, 0.0, 1.0)

	# ripples
	for i in range(_ripples.size() - 1, -1, -1):
		var r: Array = _ripples[i]
		r[2] -= dt
		if r[2] <= 0.0:
			if is_instance_valid(r[0]):
				(r[0] as GameCard).nudge(r[1])
			_ripples.remove_at(i)

	var rx := _row_x.step(dt)
	for i in _cards.size():
		_cards[i].position = Vector2(rx + i * (CARD.x + GAP) + _gaps[i].step(dt), ROW_Y)
	if focus < _cards.size() and shell:
		var c := _cards[focus]
		var sx := (c.position.x + CARD.x * 0.5) / maxf(size.x, 1.0) * 2.0 - 1.0
		shell.wallpaper.look_at_point(Vector2(sx, 0.4))
