// FORGE OS wallpaper — Deep Field: a dense field of stars and a rich Milky Way core with dark
// dust lanes, above a thin black horizon.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"
#include "res://shaders/sky_common.gdshaderinc"

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.25;
	float tt = t * 0.5 + 3.0;
	vec3 col = mix(vec3(0.04, 0.03, 0.09), vec3(0.008, 0.008, 0.025), smoothstep(0.4, -0.5, p.y));
	vec2 mw = s_milky(p, vec2(0.0, 0.05), -0.45, 0.22);
	vec3 mwc = mix(vec3(0.30, 0.28, 0.55), vec3(0.85, 0.65, 0.70), smoothstep(0.3, 0.9, mw.x));
	col += mwc * mw.x * 0.7;
	col *= 1.0 - mw.y * 0.65;
	col += vec3(0.25, 0.1, 0.3) * exp(-length((p - vec2(-0.3, 0.25)) * vec2(1.0, 2.0)) * 3.0) * 0.4;
	col += s_stars(p, tt, mw.x * 1.4) * 1.2;
	float land = 0.47 - s_ridge(p.x * 0.8, 9.0, 0.3) * 0.03;
	if (p.y > land) col = vec3(0.0);
	col = mix(col, col * mix(vec3(1.0), game_tint.rgb * 1.3, 0.25), game_tint_amount * 0.25);
	col *= intensity;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
