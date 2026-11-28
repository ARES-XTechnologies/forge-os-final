// FORGE OS wallpaper — Liquid Gold: the same slowly flowing liquid metal as Liquid Chrome, but
// molten gold. Warm studio panels glint across the folds over deep amber shadows.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"

float height(vec2 p, float tt) {
	vec2 q = p;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		q += 0.35 * vec2(sin(q.y * (1.1 + fi * 0.37) + tt * (0.21 + fi * 0.05) + fi),
		                 cos(q.x * (1.3 + fi * 0.29) - tt * (0.17 + fi * 0.04) + fi * 1.7));
	}
	return 0.5 + 0.25 * sin(q.x * 1.6) * cos(q.y * 1.4) + 0.15 * sin((q.x + q.y) * 2.1);
}

// Warm studio environment: deep amber dark with a bright cream panel and a softer honey panel.
vec3 env(vec3 n) {
	vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);
	float panel1 = smoothstep(0.70, 0.92, dot(r, normalize(vec3(-0.5, -0.6, 0.62))));
	float panel2 = smoothstep(0.75, 0.95, dot(r, normalize(vec3(0.65, 0.1, 0.75))));
	float sky = smoothstep(-0.2, 0.8, -r.y) * 0.18;
	float glint = pow(max(dot(r, normalize(vec3(-0.45, -0.55, 0.70))), 0.0), 220.0);
	float floorb = smoothstep(0.0, 0.9, r.y) * 0.08;
	return vec3(0.035, 0.018, 0.004)
		+ vec3(1.0, 0.86, 0.55) * panel1 * 0.80
		+ vec3(0.85, 0.55, 0.18) * panel2 * 0.45
		+ vec3(1.0, 0.95, 0.80) * glint * 1.5
		+ vec3(0.30, 0.17, 0.05) * sky
		+ vec3(0.4, 0.2, 0.05) * floorb;
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
	// gold body colour: metal tints its own reflections, richer in the slopes
	float slope = 1.0 - n.z;
	vec3 gold = mix(vec3(1.0, 0.78, 0.36), vec3(0.85, 0.45, 0.10), smoothstep(0.02, 0.3, slope));
	col *= gold * 1.25;
	col += vec3(0.55, 0.30, 0.06) * smoothstep(0.05, 0.35, slope) * 0.12;
	col *= 0.9 + 0.2 * h;
	col *= intensity * 0.62;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
