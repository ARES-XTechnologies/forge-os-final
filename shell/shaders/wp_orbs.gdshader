// FORGE OS wallpaper — Orbs: soft glowing blobs that drift, merge and part like a lava lamp,
// with a glossy rim where they meet the dark.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"

float field(vec2 p, float tt) {
	float f = 0.0;
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		vec2 c = vec2(sin(tt * (0.11 + fi * 0.017) + fi * 2.1) * 0.75, cos(tt * (0.09 + fi * 0.013) + fi * 1.3) * 0.38);
		float r = 0.16 + 0.07 * sin(fi * 1.7);
		f += r * r / (dot(p - c, p - c) + r * r * 0.35);
	}
	return f;
}

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.9;
	float tt = t;
	float f = field(p, tt);
	float e = 0.003;
	vec2 g = vec2(field(p + vec2(e, 0.0), tt) - f, field(p + vec2(0.0, e), tt) - f) / e;
	vec3 a = pal_a(); vec3 b = pal_b();
	float inside = smoothstep(1.0, 1.35, f);
	vec3 n = normalize(vec3(-g * 0.035, 1.0));
	float rim = pow(1.0 - n.z, 1.5);
	vec3 blob = mix(a, b, clamp(0.5 + 0.5 * sin(p.x * 1.5 + tt * 0.1), 0.0, 1.0));
	vec3 col = c_base.rgb;
	col += blob * inside * (0.34 + 0.6 * rim);
	// Gloss only on the curved edge of each blob (never a hot spot in the middle).
	float edge = smoothstep(0.08, 0.5, rim);
	col += mix(vec3(1.0), pal_c(), 0.4) * inside * edge * pow(max(dot(n, normalize(vec3(-0.4, -0.6, 0.7))), 0.0), 6.0) * 0.45;
	// Deeper colour toward each blob's heart.
	col += mix(b, c_glow.rgb, 0.3) * smoothstep(1.6, 4.0, f) * 0.18;
	col += mix(a, c_glow.rgb, 0.5) * smoothstep(0.35, 1.0, f) * (1.0 - inside) * 0.16;   // glow around blobs
	col *= intensity;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
