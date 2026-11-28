// FORGE OS wallpaper — Liquid Chrome: a slowly flowing surface of polished liquid metal. The
// folds catch a soft studio light, with a faint oil-slick shimmer in the palette colours.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"

// Smooth, large folds: a few layers of warped sine waves (no fine noise, so it reads as
// polished liquid rather than crumpled foil).
float height(vec2 p, float tt) {
	vec2 q = p;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		q += 0.35 * vec2(sin(q.y * (1.1 + fi * 0.37) + tt * (0.21 + fi * 0.05) + fi),
		                 cos(q.x * (1.3 + fi * 0.29) - tt * (0.17 + fi * 0.04) + fi * 1.7));
	}
	return 0.5 + 0.25 * sin(q.x * 1.6) * cos(q.y * 1.4) + 0.15 * sin((q.x + q.y) * 2.1);
}

// A soft studio environment: dark with two broad light panels.
vec3 env(vec3 n) {
	// reflect a view ray off the surface and look up a studio with soft light panels
	vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);
	float panel1 = smoothstep(0.70, 0.92, dot(r, normalize(vec3(-0.5, -0.6, 0.62))));
	float panel2 = smoothstep(0.75, 0.95, dot(r, normalize(vec3(0.65, 0.1, 0.75))));
	float sky = smoothstep(-0.2, 0.8, -r.y) * 0.35;
	float floorb = smoothstep(0.0, 0.9, r.y) * 0.08;
	return vec3(0.012, 0.013, 0.02) + vec3(0.62) * panel1 + vec3(0.42, 0.46, 0.55) * panel2 + vec3(0.10, 0.11, 0.15) * sky + floorb * 0.5;
}

void fragment() {
	vec2 p = wp_coords(UV) * 2.8 + parallax * 0.5;
	float tt = t * 0.5 + 30.0;
	float e = 0.004;
	float h = height(p, tt);
	float hx = height(p + vec2(e, 0.0), tt);
	float hy = height(p + vec2(0.0, e), tt);
	vec3 n = normalize(vec3((h - hx) / e * 0.55, (h - hy) / e * 0.55, 1.0));
	vec3 col = env(n);
	// thin-film shimmer, coloured by the palette, strongest on the slopes
	float slope = 1.0 - n.z;
	vec3 film = 0.5 + 0.5 * cos(6.2831 * (h * 2.0 + vec3(0.0, 0.33, 0.67)));
	vec3 tint = mix(pal_a(), pal_b(), film.x) * mix(vec3(1.0), pal_c(), film.y * 0.4);
	col += tint * smoothstep(0.02, 0.25, slope) * 0.22;
	col *= 0.9 + 0.2 * h;
	col *= intensity * 0.62;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
