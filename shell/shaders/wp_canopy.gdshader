// FORGE OS wallpaper — Night Canopy: the Milky Way rises straight up through a violet sky,
// framed by black trees on both sides, with a soft pink glow behind distant hills.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"
#include "res://shaders/sky_common.gdshaderinc"

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.25;
	float tt = t * 0.5 + 3.0;
	vec3 col = mix(vec3(0.07, 0.07, 0.17), vec3(0.008, 0.01, 0.04), smoothstep(0.45, -0.5, p.y));
	col += vec3(0.45, 0.25, 0.35) * exp(-pow((p.y - 0.45) / 0.15, 2.0)) * 0.5;
	vec2 mw = s_milky(p, vec2(-0.1, 0.0), -1.25, 0.16);
	col += mix(vec3(0.45, 0.42, 0.62), vec3(0.75, 0.7, 0.8), mw.x * 0.5) * mw.x * 0.6;
	col *= 1.0 - mw.y * 0.5;
	col += s_stars(p, tt, mw.x) * 1.15;
	// distant hills, then trees growing taller toward both edges
	float hills = 0.45 - s_ridge(p.x * 1.4, 5.0, 0.6) * 0.08;
	float edge = smoothstep(0.25, 0.95, abs(p.x));
	if (p.y > hills) col = vec3(0.0);
	if (s_forest(p.x, hills - p.y, 22.0, 2.0, 1.0, 0.7 + edge * 4.0) > 0.5) col = vec3(0.0);
	col = mix(col, col * mix(vec3(1.0), game_tint.rgb * 1.3, 0.25), game_tint_amount * 0.25);
	col *= intensity;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
