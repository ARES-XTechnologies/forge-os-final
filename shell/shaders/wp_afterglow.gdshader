// FORGE OS wallpaper — Afterglow: a purple starry sky where the last orange light of sunset
// still glows behind wispy clouds above a black tree line.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"
#include "res://shaders/sky_common.gdshaderinc"

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.25;
	float tt = t * 0.5 + 3.0;
	vec3 col = mix(vec3(0.10, 0.06, 0.22), vec3(0.015, 0.01, 0.05), smoothstep(0.2, -0.55, p.y));
	col = mix(col, vec3(0.55, 0.20, 0.30), smoothstep(0.0, 0.32, p.y));
	col = mix(col, vec3(1.0, 0.52, 0.18), smoothstep(0.18, 0.40, p.y));
	vec2 mw = s_milky(p, vec2(-0.15, -0.15), -0.8, 0.17);
	col += mix(vec3(0.45, 0.35, 0.65), vec3(0.9, 0.55, 0.5), mw.x * 0.4) * mw.x * 0.5 * smoothstep(0.3, -0.1, p.y);
	col *= 1.0 - mw.y * 0.45;
	col += s_stars(p, tt, mw.x) * smoothstep(0.32, 0.0, p.y) * 1.1;
	// wispy sunset clouds
	float cl = fbm(vec2(p.x * 2.2 + tt * 0.01, p.y * 9.0)) * smoothstep(0.05, 0.22, p.y) * smoothstep(0.38, 0.22, p.y);
	col += vec3(1.0, 0.5, 0.35) * smoothstep(0.45, 0.75, cl) * 0.6;
	if (s_forest(p.x, 0.41 - p.y, 30.0, 4.0, 0.0, 0.75) > 0.5) col = vec3(0.0);
	col = mix(col, col * mix(vec3(1.0), game_tint.rgb * 1.3, 0.25), game_tint_amount * 0.25);
	col *= intensity;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
