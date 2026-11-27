// Brushed-gold lettering with a travelling light sweep.
shader_type canvas_item;

uniform float sweep = -1.0;        // sweep position in px (wordmark space)
uniform float offset_x = 0.0;      // this glyph's x in wordmark space
uniform float height = 120.0;
uniform float glow = 0.0;
varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float y = clamp(lp.y / height, 0.0, 1.0);
	vec3 top = vec3(1.0, 0.93, 0.72);
	vec3 mid = vec3(1.0, 0.76, 0.36);
	vec3 bot = vec3(0.72, 0.42, 0.14);
	vec3 g = y < 0.5 ? mix(top, mid, y * 2.0) : mix(mid, bot, (y - 0.5) * 2.0);
	float x = lp.x + offset_x;
	float d = (x - sweep) + (lp.y - height * 0.5) * 0.35;
	float band = exp(-d * d / 900.0);
	g += vec3(1.0, 0.95, 0.85) * band * 0.9;
	g += vec3(1.0, 0.8, 0.5) * glow * 0.3;
	COLOR = vec4(g, tex.a * COLOR.a);
}
