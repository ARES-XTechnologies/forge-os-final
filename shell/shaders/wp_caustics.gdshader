// FORGE OS wallpaper — Caustics: the shifting light net you see on the floor of a pool,
// in deep palette colours.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"

// Classic iterative caustic pattern.
float caustic(vec2 uv, float tt) {
	vec2 p = mod(uv * 6.2831, 6.2831) - 250.0;
	vec2 i = p;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 5; n++) {
		float tn = tt * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tn - i.x) + sin(tn + i.y), sin(tn - i.y) + cos(tn + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tn) / inten), p.y / (cos(i.y + tn) / inten)));
	}
	c /= 5.0;
	c = 1.17 - pow(c, 1.4);
	return pow(abs(c), 8.0);
}

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.7;
	float tt = t * 0.35 + 23.0;
	vec3 a = pal_a(); vec3 b = pal_b(); vec3 c = pal_c();
	float depth = smoothstep(-0.7, 0.7, p.y);
	vec3 col = mix(c_base.rgb + a * 0.05, c_base.rgb * 0.6, depth);
	float k1 = caustic(p * 0.55 + vec2(0.1, 0.0), tt);
	float k2 = caustic(p * 0.85 + vec2(3.3, 1.7), tt * 1.21);
	col += mix(c, a, depth) * k1 * 0.55;
	col += b * k2 * 0.25;
	// Light shafts from above.
	float shafts = fbm(vec2(p.x * 3.0 + p.y * 0.8, tt * 0.3)) * smoothstep(0.6, -0.6, p.y);
	col += mix(c, vec3(1.0), 0.3) * shafts * 0.10;
	col *= intensity;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
