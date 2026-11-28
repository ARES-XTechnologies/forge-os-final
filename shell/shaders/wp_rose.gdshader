// FORGE OS wallpaper — Rose Horizon: the Milky Way arcs diagonally from the deep blue sky
// down to a glowing pink horizon over dark rolling hills.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"
#include "res://shaders/sky_common.gdshaderinc"

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.25;
	float tt = t * 0.5 + 3.0;
	vec3 col = mix(vec3(0.02, 0.05, 0.20), vec3(0.004, 0.01, 0.05), smoothstep(0.1, -0.55, p.y));
	col = mix(col, vec3(0.55, 0.12, 0.42), smoothstep(-0.05, 0.42, p.y) * 0.85);       // pink near the horizon
	col += vec3(0.9, 0.35, 0.6) * exp(-pow((p.y - 0.40) / 0.12, 2.0)) * exp(-abs(p.x - 0.25) * 1.2) * 0.6;
	vec2 mw = s_milky(p, vec2(0.05, -0.05), -0.62, 0.19);
	vec3 mwc = mix(vec3(0.35, 0.45, 0.95), vec3(0.95, 0.75, 0.95), smoothstep(-0.2, 0.4, p.y));
	col += mwc * mw.x * 0.65;
	col *= 1.0 - mw.y * 0.5;
	col += s_stars(p, tt, mw.x) * 1.1;
	float hill = 0.36 - s_ridge(p.x * 0.9, 3.0, 0.2) * 0.14 + 0.05 * sin(p.x * 2.3 + 1.0);
	col = mix(col, vec3(0.0), smoothstep(hill - 0.002, hill + 0.002, p.y));
	col = mix(col, col * mix(vec3(1.0), game_tint.rgb * 1.3, 0.25), game_tint_amount * 0.25);
	col *= intensity;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
