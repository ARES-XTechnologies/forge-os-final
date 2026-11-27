extends Node
## Design tokens: the single source of truth for colour, type, spacing and motion.

const OS_NAME := "FORGE"
const OS_VERSION := "1.4.2"
const STUDIO := "Blacksmith Games"

# ---------- Colour ----------
const INK := Color("f4f6ff")            # primary text
const INK_DIM := Color(0.86, 0.88, 0.96, 0.72)
const INK_FAINT := Color(0.86, 0.88, 0.96, 0.46)
const BASE := Color("05060f")
const ACCENT := Color("7cc8ff")         # cool cyan
const ACCENT_2 := Color("b58cff")       # violet
const GOLD := Color("ffc76b")
const OK := Color("6ff2b5")
const WARN := Color("ffb86b")
const BAD := Color("ff6b8a")

# Wallpaper palettes: [base, ribbon A, ribbon B, ribbon C, glow]
const PALETTES := {
	"aurora": [Color("060714"), Color("3b6cff"), Color("9a5cff"), Color("2fd5ff"), Color("ff5cc8")],
	"ember":  [Color("0c0605"), Color("ff7a2f"), Color("ffc46b"), Color("ff3d5a"), Color("ffd9a0")],
	"ocean":  [Color("020b12"), Color("00b3ff"), Color("00ffc8"), Color("2a5cff"), Color("8ff7ff")],
	"rose":   [Color("100610"), Color("ff5c9d"), Color("b55cff"), Color("ff9a6b"), Color("ffd1e8")],
	"mono":   [Color("060608"), Color("8a8fa8"), Color("e6e9ff"), Color("5c6178"), Color("ffffff")],
}

const CLOCK_COLORS := {
	"white": Color("f4f6ff"), "ice": Color("9fe0ff"), "violet": Color("c6a6ff"),
	"gold": Color("ffd38a"), "rose": Color("ffa6c9"), "mint": Color("8fffd0"),
	"crimson": Color("ff5c6c"), "sunset": Color("ff9a5c"),
}

# ---------- Spacing / radius ----------
const R_SM := 14.0
const R_MD := 22.0
const R_LG := 32.0
const R_XL := 44.0
const PAD := 32.0
const SAFE_X := 96.0
const SAFE_TOP := 52.0

# ---------- Motion (stiffness, damping) ----------
# Underdamped springs give the "drop and settle" overshoot. Ratio d / (2*sqrt(k)) is the
# damping ratio: < 1 bounces, 1 is critical.
const SPRINGS := {
	&"snappy":  Vector2(560.0, 34.0),   # ~0.72 ratio: quick, small overshoot
	&"bouncy":  Vector2(420.0, 20.0),   # ~0.49 ratio: playful drop-and-bounce
	&"jelly":   Vector2(300.0, 13.0),   # ~0.38 ratio: wobbly, for pops
	&"smooth":  Vector2(180.0, 27.0),   # ~1.0  ratio: no overshoot, scroll glide
	&"glide":   Vector2(110.0, 21.0),   # ~1.0  slow cinematic
	&"stiff":   Vector2(900.0, 60.0),   # ~1.0  fast UI response
	&"press":   Vector2(1400.0, 34.0),  # press squash
}

# ---------- Type ----------
var _fonts := {}

func font(weight: int = 400, italic := false) -> Font:
	var key := "%d_%s" % [weight, italic]
	if _fonts.has(key):
		return _fonts[key]
	# Bundled Inter (SIL Open Font License, see fonts/OFL.txt) so FORGE looks the same on
	# Windows, where Inter isn't installed. Italics fall back to the system font.
	if not italic:
		var names := {100: "Thin", 200: "ExtraLight", 300: "Light", 400: "Regular", 500: "Medium", 600: "SemiBold", 700: "Bold"}
		var w := clampi(int(round(weight / 100.0)) * 100, 100, 700)
		var path := "res://fonts/Inter-%s.otf" % names[w]
		var ff: FontFile = load(path) if ResourceLoader.exists(path) else null
		if ff != null:
			var bf := ff.duplicate() as FontFile
			bf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			bf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
			bf.hinting = TextServer.HINTING_LIGHT
			bf.multichannel_signed_distance_field = false
			var fb := SystemFont.new()
			fb.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "DejaVu Sans", "sans-serif"])
			bf.fallbacks = [fb]
			_fonts[key] = bf
			return bf
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Inter", "Inter Variable", "SF Pro Display", "Segoe UI Variable Display", "Segoe UI", "Noto Sans", "DejaVu Sans", "sans-serif"])
	f.font_weight = weight
	f.font_italic = italic
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	f.hinting = TextServer.HINTING_LIGHT
	f.multichannel_signed_distance_field = false
	_fonts[key] = f
	return f

func label(text: String, size: int, weight := 400, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func palette() -> Array:
	return PALETTES.get(Config.get_s("appearance.palette"), PALETTES["aurora"])

func clock_color() -> Color:
	var key: String = Config.get_s("appearance.clock_color")
	if key == "custom":
		return Color.from_hsv(Config.get_f("appearance.clock_hue"), 0.45, 1.0)
	return CLOCK_COLORS.get(key, INK)

## Convenience: draw a soft drop shadow under a rounded rect.
func draw_soft_shadow(ci: CanvasItem, rect: Rect2, radius: float, strength: float, spread := 26.0) -> void:
	var steps := 7
	for i in steps:
		var t := float(i) / float(steps)
		var grow := spread * (1.0 - t)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, strength * 0.06 * (0.4 + t))
		sb.set_corner_radius_all(int(radius + grow))
		sb.anti_aliasing = true
		sb.anti_aliasing_size = 2.0
		var r := rect.grow(grow)
		r.position.y += grow * 0.55
		ci.draw_style_box(sb, r)
