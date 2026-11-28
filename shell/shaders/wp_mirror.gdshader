// FORGE OS wallpaper — Mirror Lake: the Milky Way over a perfectly still lake. The stars and
// the band of light are reflected in the water below a black forest shoreline; now and then a
// faint ripple crosses the reflection.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"
#include "res://shaders/sky_common.gdshaderinc"

const float SHORE = 0.10;

vec3 sky(vec2 p, float tt) {
	vec3 col = mix(vec3(0.07, 0.09, 0.22), vec3(0.01, 0.015, 0.06), smoothstep(SHORE, -0.55, p.y));
	col += vec3(0.15, 0.17, 0.32) * exp(-abs(p.y - SHORE) * 8.0) * 0.5;
	vec2 mw = s_milky(p, vec2(-0.15, -0.2), -1.05, 0.15);
	col += mix(vec3(0.45, 0.45, 0.65), vec3(0.8, 0.72, 0.75), mw.x * 0.5) * mw.x * 0.6;
	col *= 1.0 - mw.y * 0.5;
	col += s_stars(p, tt, mw.x) * 1.1;
	return col;
}

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.25;
	float tt = t * 0.5 + 3.0;
	vec3 col;
	float hmul = 0.6 + s_ridge(p.x * 1.2, 4.0, 0.3) * 0.9;
	if (p.y < SHORE) {
		col = sky(p, tt);
		if (s_forest(p.x, SHORE - p.y, 24.0, 3.0, 1.0, hmul) > 0.5) col = vec3(0.0);
	} else {
		// reflection: mirrored sky, slightly darker, with slow gentle ripples
		float d = p.y - SHORE;
		vec2 rp = vec2(p.x + 0.0025 * sin(p.y * 70.0 + tt * 0.8) * smoothstep(0.02, 0.3, d), SHORE - d);
		col = sky(rp, tt) * 0.55;
		if (s_forest(rp.x, d, 24.0, 3.0, 1.0, hmul) > 0.5) col = vec3(0.0);
		col += vec3(0.06, 0.08, 0.14) * 0.15;
	}
	col = mix(col, col * mix(vec3(1.0), game_tint.rgb * 1.3, 0.25), game_tint_amount * 0.25);
	col *= intensity;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
