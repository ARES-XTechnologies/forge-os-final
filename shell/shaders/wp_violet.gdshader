// FORGE OS wallpaper — Violet Peaks: an extremely dense purple and pink star field over dark
// mountains, with pine trees at the edges.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"
#include "res://shaders/sky_common.gdshaderinc"

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.25;
	float tt = t * 0.5 + 3.0;
	vec3 col = mix(vec3(0.06, 0.04, 0.18), vec3(0.01, 0.01, 0.05), smoothstep(0.3, -0.5, p.y));
	col = mix(col, vec3(0.55, 0.22, 0.50), smoothstep(0.0, 0.40, p.y) * 0.8);
	vec2 mw = s_milky(p, vec2(0.0, -0.1), -1.45, 0.20);
	col += vec3(0.6, 0.4, 0.85) * mw.x * 0.55;
	col *= 1.0 - mw.y * 0.35;
	col += s_stars(p, tt, 0.6 + mw.x) * 1.25;
	col += vec3(0.6, 0.3, 0.6) * exp(-length(p - vec2(0.35, -0.05)) * 6.0) * 0.25;
	float mtn = 0.40 - s_ridge(p.x * 1.5, 6.0, 1.0) * 0.20;
	float edge = smoothstep(0.45, 0.95, abs(p.x));
	if (p.y > mtn) col = vec3(0.0);
	if (edge > 0.01 && s_forest(p.x, mtn - p.y, 26.0, 8.0, 1.0, edge * 3.5) > 0.5) col = vec3(0.0);
	col = mix(col, col * mix(vec3(1.0), game_tint.rgb * 1.3, 0.25), game_tint_amount * 0.25);
	col *= intensity;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
