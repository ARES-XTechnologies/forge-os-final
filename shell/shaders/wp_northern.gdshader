// FORGE OS wallpaper — Northern Lights: curtains of light with fine vertical rays rippling
// over a starry sky and a dark mountain ridge.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"

float curtain(vec2 p, float tt, float seed) {
	float x = p.x * 1.2 + seed;
	float base = -0.12 + 0.12 * sin(x * 1.3 + tt * 0.18 + seed) + 0.06 * sin(x * 3.1 - tt * 0.27);
	float dy = p.y - base;                    // below the curtain's lower hem = positive
	float body = exp(-max(-dy, 0.0) * 3.2) * smoothstep(0.08, -0.02, dy);
	// Rays: irregular vertical streaks that shimmer along the curtain.
	float rays = 0.35 + 0.65 * pow(noise(vec2(x * 18.0 + noise(vec2(x * 3.0, tt * 0.15)) * 4.0, seed * 3.0 + tt * 0.05)), 1.5);
	rays *= 0.75 + 0.25 * noise(vec2(x * 55.0, tt * 0.4 + seed));
	return body * rays;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = wp_coords(uv) + parallax * 0.5;
	float tt = t;
	vec3 a = pal_a(); vec3 b = pal_b(); vec3 c = pal_c();
	vec3 col = mix(c_base.rgb * 1.4 + a * 0.03, c_base.rgb * 0.5, smoothstep(-0.5, 0.5, p.y));
	// Stars.
	vec2 sq = (p + parallax * 0.2) * 55.0;
	vec2 id = floor(sq);
	float h = hash12(id);
	if (h < 0.10) {
		vec2 f = fract(sq) - 0.5 - (hash22(id) - 0.5) * 0.6;
		col += vec3(0.85, 0.9, 1.0) * exp(-dot(f, f) * 120.0) * (0.5 + 0.5 * sin(tt * (1.0 + h * 9.0) + h * 50.0)) * 0.6;
	}
	// Aurora: two curtains in palette colours.
	float c1 = curtain(p, tt, 0.0);
	float c2 = curtain(p + vec2(0.3, 0.07), tt * 0.8, 2.7);
	col += mix(c, a, smoothstep(0.1, -0.4, p.y)) * c1 * 0.75;
	col += mix(b, c_glow.rgb, 0.4) * c2 * 0.45;
	// Mountain ridge silhouette.
	vec2 m = wp_coords(uv) + parallax * 1.4;
	float ridge = 0.12 + 0.16 * fbm(vec2(m.x * 1.6 + 3.0, 0.5)) + 0.06 * sin(m.x * 1.3 + 1.0);
	float mount = smoothstep(ridge - 0.003, ridge + 0.003, m.y);
	float rimlight = exp(-abs(m.y - ridge) * 140.0) * (1.0 - mount * 0.3);
	col = mix(col, vec3(0.006, 0.007, 0.014), mount);
	col += mix(c, a, 0.5) * rimlight * 0.10;           // aurora light catching the ridge
	col *= intensity;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
