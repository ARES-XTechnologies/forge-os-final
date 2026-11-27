class_name GlassPanel
extends Control
## A liquid-glass surface. Put any content inside it as children.
## Shadow and focus halo render outside the panel bounds in the same draw.

const SHADER := preload("res://shaders/liquid_glass.gdshader")

@export var radius := 28.0:
	set(v): radius = v; _push()
@export var bevel := 22.0:
	set(v): bevel = v; _push()
@export var edge_bend := 26.0:
	set(v): edge_bend = v; _push()
@export var magnify := 0.035:
	set(v): magnify = v; _push()
@export var shadow := 0.55:
	set(v): shadow = v; _push()
@export var tint := Color(0.62, 0.72, 1.0):
	set(v): tint = v; _push()
@export var tint_boost := 0.0:
	set(v): tint_boost = v; _push()
@export var body_dim := 0.0:
	set(v): body_dim = v; _set_param("body_dim", v)
@export var focus := 0.0:
	set(v): focus = v; _set_param("focus", v)
@export var press := 0.0:
	set(v): press = v; _set_param("press", v)
@export var glass_opacity := 1.0:
	set(v): glass_opacity = v; _set_param("opacity", v)
@export var shine := -1.0:
	set(v): shine = v; _set_param("shine", v)
## Set true for glass that sits on top of other glass. Layered glass draws as a
## translucent lens over what's below instead of re-reading the screen, so stacks of
## glass stay cheap and never "punch through" the panel underneath.
var nested := false:
	set(v):
		nested = v
		_set_param("layered", v)
var _bbc: BackBufferCopy
## Glass drawn over a running game (the in-game menu, hints, notifications).
## The screen behind it is the game, which the UI can't read, so it becomes smoked glass.
var ingame := false:
	set(v):
		ingame = v
		_push()
var focus_color := Tokens.ACCENT:
	set(v): focus_color = v; _set_param("focus_color", v)

const MARGIN := 56.0
## Per-panel glow multiplier: big sheets glow a little softer than small cards.
var glow_scale := 1.0:
	set(v): glow_scale = v; _push()
var _seed := randf()

var _rect: ColorRect
var _mat: ShaderMaterial

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.color = Color.WHITE
	add_child(_rect, false, Node.INTERNAL_MODE_FRONT)

func _ready() -> void:
	resized.connect(_layout)
	Config.changed.connect(_on_config)
	_layout()
	_push()

func _on_config(key: String) -> void:
	if key == "motion.reduce":
		_push()
	if key.begins_with("appearance.glass") or key.begins_with("appearance.glow"):
		_push()

func _layout() -> void:
	_rect.position = Vector2(-MARGIN, -MARGIN)
	_rect.size = size + Vector2(MARGIN, MARGIN) * 2.0
	_set_param("size", _rect.size)


func _set_param(n: String, v) -> void:
	if _mat:
		_mat.set_shader_parameter(n, v)

func _push() -> void:
	if not _mat:
		return
	_set_param("margin", MARGIN)
	_set_param("radius", radius)
	_set_param("bevel", bevel)
	_set_param("edge_bend", edge_bend)
	_set_param("magnify", magnify)
	_set_param("shadow", shadow)
	_set_param("tint", tint)
	_set_param("refraction", Config.get_f("appearance.glass_refraction"))
	_set_param("dispersion", Config.get_f("appearance.glass_dispersion"))
	_set_param("tint_amount", Config.get_f("appearance.glass_tint") + tint_boost)
	_set_param("focus_color", focus_color)
	_set_param("focus", focus)
	_set_param("press", press)
	_set_param("opacity", glass_opacity)
	_set_param("shine", shine)
	_set_param("body_dim", body_dim)
	_set_param("glass_brightness", Config.get_f("appearance.glass_brightness"))
	_set_param("glow_on", Config.get_b("appearance.glow"))
	_set_param("glow_strength", Config.get_f("appearance.glow_strength") * glow_scale)
	_set_param("glow_mode", ["adaptive", "accent", "gold", "ice", "rainbow"].find(Config.get_s("appearance.glow_color")))
	_set_param("glow_motion", Config.get_b("appearance.glow_motion") and not Config.get_b("motion.reduce"))
	_set_param("glow_seed", _seed)
	_set_param("style", ["liquid", "frosted", "matte"].find(Config.get_s("appearance.glass_style")))
	_set_param("layered", nested or ingame)
	_set_param("smoke", 0.82 if ingame else 0.0)
