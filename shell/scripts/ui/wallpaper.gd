class_name Wallpaper
extends ColorRect
## Animated liquid-light wallpaper. Parallax follows UI focus on a soft spring,
## so the whole world gently shifts as you move through games.

const SHADER := preload("res://shaders/wallpaper.gdshader")
## Every wallpaper is its own shader; they all take the same palette and motion inputs.
const STYLES := {
	"ribbons": "res://shaders/wallpaper.gdshader",
	"nebula": "res://shaders/wp_nebula.gdshader",
	"silk": "res://shaders/wp_silk.gdshader",
	"caustics": "res://shaders/wp_caustics.gdshader",
	"northern": "res://shaders/wp_northern.gdshader",
	"orbs": "res://shaders/wp_orbs.gdshader",
	"golden": "res://shaders/wp_golden.gdshader",
	"shallows": "res://shaders/wp_shallows.gdshader",
	"coral": "res://shaders/wp_coral.gdshader",
	"deep": "res://shaders/wp_deep.gdshader",
	"night_rain": "res://shaders/wp_night_rain.gdshader",
	"chrome": "res://shaders/wp_chrome.gdshader",
	"prism": "res://shaders/wp_prism.gdshader",
	"starfall": "res://shaders/wp_starfall.gdshader",
	"gold": "res://shaders/wp_gold.gdshader",
	"rose": "res://shaders/wp_rose.gdshader",
	"canopy": "res://shaders/wp_canopy.gdshader",
	"deepfield": "res://shaders/wp_deepfield.gdshader",
	"afterglow": "res://shaders/wp_afterglow.gdshader",
	"mirror": "res://shaders/wp_mirror.gdshader",
	"violet": "res://shaders/wp_violet.gdshader",
	"photo": "res://shaders/wp_photo.gdshader",
}
var _style := ""
var _switching := false

var _mat: ShaderMaterial
var _t := 0.0
var parallax: Spring2
var dim: Spring
var reveal: Spring
var _palette_mix := 1.0
var _tint := Color.WHITE
var _tint_target := Color.WHITE
var _tint_amt: Spring
var _from: Array = []
var _to: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	material = _mat
	parallax = Spring2.preset(Vector2.ZERO, &"glide")
	dim = Spring.preset(0.0, &"smooth")
	reveal = Spring.preset(1.0, &"glide")
	_tint_amt = Spring.preset(0.0, &"glide")
	_t = randf() * 200.0
	_to = Tokens.palette()
	_from = _to
	_set_style(_wanted_style())
	Config.changed.connect(func(k):
		if k in ["appearance.wallpaper", "appearance.wallpaper_photo"]:
			_switching = true          # fade out, swap, fade back in (see _process)
			reveal.target = 0.0
		if k == "appearance.wallpaper_soften":
			_mat.set_shader_parameter("soften", Config.get_f("appearance.wallpaper_soften"))
		if k == "appearance.palette":
			_from = _current_palette()
			_to = Tokens.palette()
			_palette_mix = 0.0)

func _wanted_style() -> String:
	var st := Config.get_s("appearance.wallpaper")
	if st == "photo" and not FileAccess.file_exists(Config.get_s("appearance.wallpaper_photo")):
		st = "ribbons"                 # photo missing (deleted, or drive unplugged)
	return st if STYLES.has(st) else "ribbons"

func _set_style(st: String) -> void:
	_style = st
	_mat.shader = load(STYLES[st])
	_apply_palette(1.0)
	if st == "photo":
		var img := Image.load_from_file(Config.get_s("appearance.wallpaper_photo"))
		if img:
			# Big photos are scaled down to screen size: sharp enough, light on memory.
			var maxw := 3840
			if img.get_width() > maxw:
				img.resize(maxw, int(img.get_height() * float(maxw) / img.get_width()), Image.INTERPOLATE_LANCZOS)
			img.generate_mipmaps()
			_mat.set_shader_parameter("photo", ImageTexture.create_from_image(img))
			_mat.set_shader_parameter("photo_size", Vector2(img.get_width(), img.get_height()))
		_mat.set_shader_parameter("soften", Config.get_f("appearance.wallpaper_soften"))

func _current_palette() -> Array:
	var out := []
	for i in 5:
		out.append((_from[i] as Color).lerp(_to[i], _palette_mix))
	return out

func _apply_palette(k: float) -> void:
	var names := ["c_base", "c_a", "c_b", "c_c", "c_glow"]
	for i in 5:
		_mat.set_shader_parameter(names[i], (_from[i] as Color).lerp(_to[i], smoothstep(0.0, 1.0, k)))

## Dynamic theme: drift the sky's colours toward the focused game's art.
func set_game_color(c, on := true) -> void:
	if c == null or not on or not Config.get_b("appearance.dynamic"):
		_tint_amt.target = 0.0
		return
	_tint_target = c
	_tint_amt.target = 1.0

## Nudge the parallax target, e.g. from the focused card's screen position (-1..1).
func look_at_point(n: Vector2) -> void:
	if Config.get_b("appearance.parallax") and not Config.get_b("motion.reduce"):
		parallax.target = Vector2(n.x * 0.035, n.y * 0.02)

func _process(dt: float) -> void:
	if Config.get_b("appearance.wallpaper_animated"):
		_t += dt * Config.get_f("appearance.wallpaper_speed")
	if _palette_mix < 1.0:
		_palette_mix = minf(1.0, _palette_mix + dt * 0.8)
		_apply_palette(_palette_mix)
	var pv := parallax.step(dt)
	_mat.set_shader_parameter("t", _t)
	_mat.set_shader_parameter("parallax", pv)
	_mat.set_shader_parameter("res", size)
	_mat.set_shader_parameter("dim", dim.step(dt))
	var rv := clampf(reveal.step(dt), 0.0, 1.0)
	if _switching and rv < 0.04:
		_switching = false
		_set_style(_wanted_style())
		reveal.target = 1.0
	_mat.set_shader_parameter("reveal", rv)
	_mat.set_shader_parameter("intensity", Config.get_f("appearance.wallpaper_intensity"))
	_tint = _tint.lerp(_tint_target, clampf(dt * 2.2, 0.0, 1.0))
	_mat.set_shader_parameter("game_tint", _tint)
	_mat.set_shader_parameter("game_tint_amount", clampf(_tint_amt.step(dt), 0.0, 1.0))
