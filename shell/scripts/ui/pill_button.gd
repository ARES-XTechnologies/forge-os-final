class_name PillButton
extends Control
## Liquid-glass button / chip. Springs for focus scale, press squash and glow.
## `primary` buttons fill with light when focused.

signal pressed()

var text := "":
	set(v):
		text = v
		if _label: _label.text = v; _relayout()
var icon_name := "":
	set(v):
		icon_name = v
		if _icon: _icon.icon = v; _icon.visible = v != ""; _relayout()
var primary := false
var selected := false:        # chips: "this filter is on"
	set(v):
		selected = v
		if _sel: _sel.target = 1.0 if v else 0.0
var height := 64.0
var font_size := 24
var min_width := 0.0
var focused := false
var nested := false
var focus_color := Tokens.ACCENT:
	set(v):
		focus_color = v
		if _glass: _glass.focus_color = v

var _glass: GlassPanel
var _label: Label
var _icon: Icon
var _body: Control
var _scale: Spring
var _focus: Spring
var _press: Spring
var _sel: Spring
var _shine := -1.0

static func make(t: String, ic := "", h := 64.0, fs := 24) -> PillButton:
	var b := PillButton.new()
	b.text = t
	b.icon_name = ic
	b.height = h
	b.font_size = fs
	return b

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_scale = Spring.preset(1.0, &"bouncy")
	_focus = Spring.preset(0.0, &"snappy")
	_press = Spring.preset(0.0, &"press")
	_sel = Spring.preset(1.0 if selected else 0.0, &"snappy")
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_glass = GlassPanel.new()
	_glass.radius = height * 0.5
	_glass.bevel = minf(18.0, height * 0.32)
	_glass.edge_bend = 18.0
	_glass.shadow = 0.35
	_glass.nested = has_meta("nested") or nested
	_body.add_child(_glass)
	_icon = Icon.make(icon_name if icon_name != "" else "dot", font_size * 1.15)
	_icon.visible = icon_name != ""
	_body.add_child(_icon)
	_label = Tokens.label(text, font_size, 500)
	_body.add_child(_label)
	_relayout()

func _relayout() -> void:
	if not _label:
		return
	var tw := _label.get_minimum_size().x
	var iw := (_icon.size.x + 12.0) if _icon.visible else 0.0
	var pad := height * 0.5 if text != "" else height * 0.5 - _icon.size.x * 0.5
	var w := maxf(min_width, tw + iw + pad * 2.0)
	if text == "":
		w = height
	size = Vector2(w, height)
	custom_minimum_size = size
	_body.size = size
	_body.pivot_offset = size * 0.5
	_glass.size = size
	var cx := (w - (tw + iw)) * 0.5
	_icon.position = Vector2(cx, (height - _icon.size.y) * 0.5)
	_label.position = Vector2(cx + iw, (height - _label.get_minimum_size().y) * 0.5)
	if text == "":
		_icon.position.x = (w - _icon.size.x) * 0.5

func set_focused(f: bool) -> void:
	if f == focused:
		return
	focused = f
	_focus.target = 1.0 if f else 0.0
	_scale.target = 1.07 if f else 1.0
	if f:
		_scale.kick(1.2)
		_shine = 0.0

func press() -> void:
	_press.snap(0.0)
	_press.kick(-9.0)
	_scale.kick(-2.5)
	Sfx.confirm()
	pressed.emit()

func _process(dt: float) -> void:
	var s := _scale.step(dt)
	var f := clampf(_focus.step(dt), 0.0, 1.2)
	var pr := _press.step(dt)
	var sel := clampf(_sel.step(dt), 0.0, 1.0)
	_body.scale = Vector2(s - pr * 0.04 + pr * 0.02, s + pr * 0.04)
	_glass.focus = f * (0.6 if primary else 0.45)
	_glass.tint_boost = sel * 0.14 + (f * 0.35 if primary else f * 0.06)
	_glass.tint = Tokens.ACCENT.lerp(Color.WHITE, 0.25) if (primary and f > 0.05) or sel > 0.05 else Color(0.62, 0.72, 1.0)
	_glass.press = absf(pr)
	var ink := Tokens.INK if (f > 0.3 or sel > 0.5) else Tokens.INK_DIM
	if primary:
		ink = Tokens.INK        # primary buttons read as clearly as the others (white text)
	_label.add_theme_color_override("font_color", ink)
	_icon.color = ink
	if _shine >= 0.0:
		_shine += dt * 1.4
		_glass.shine = _shine
		if _shine > 1.2:
			_shine = -1.0
			_glass.shine = -1.0
