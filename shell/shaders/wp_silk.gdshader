// FORGE OS wallpaper — Silk: a single sheet of satin with deep, slowly moving folds,
// lit by a soft key light so the folds catch glossy highlights.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"

float folds(vec2 p, float tt) {
	float h = 0.0;
	// Broad diagonal folds that slowly roll, like a sheet of satin lying in waves.
	float u = p.x * 0.9 + p.y * 0.55;
	h += sin(u * 2.4 + 0.8 * sin(p.y * 1.3 + tt * 0.12) + tt * 0.18) * 0.55;
	h += sin(u * 4.1 - p.y * 1.2 + 1.2 * sin(p.x * 0.9 - tt * 0.1) + tt * 0.13) * 0.25;
	h += sin(p.y * 2.2 - p.x * 0.7 + tt * 0.09) * 0.20;
	return h;
}

void fragment() {
	vec2 p = wp_coords(UV) * 2.1 + parallax * 0.8;
	float tt = t;
	float e = 0.004;
	float h = folds(p, tt);
	vec2 grad = vec2(folds(p + vec2(e, 0.0), tt) - h, folds(p + vec2(0.0, e), tt) - h) / e;
	vec3 n = normalize(vec3(-grad * 0.32, 1.0));
	vec3 L = normalize(vec3(-0.5, -0.6, 0.9));
	vec3 V = vec3(0.0, 0.0, 1.0);
	float diff = max(dot(n, L), 0.0);
	float spec = pow(max(dot(reflect(-L, n), V), 0.0), 10.0);
	float sheen = pow(1.0 - max(dot(n, V), 0.0), 2.0);
	vec3 a = pal_a(); vec3 b = pal_b();
	vec3 cloth = mix(a, b, 0.5 + 0.5 * sin(h * 1.4 + p.x * 0.6));
	vec3 col = c_base.rgb * 0.8 + cloth * (0.04 + 0.48 * pow(diff, 2.2));
	col += mix(vec3(1.0), c_glow.rgb, 0.3) * spec * 0.32;
	col += pal_c() * sheen * 0.35;
	col *= intensity;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
