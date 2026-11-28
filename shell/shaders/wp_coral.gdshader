// FORGE OS wallpaper — Coral Light: clear tropical water over a sandy floor. Sunlight from the
// rippling surface draws a moving net of caustics across the sand ripples, with a few dark
// rocks, drifting specks and soft rays.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"
#include "res://shaders/water_common.gdshaderinc"

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.4;
	float tt = t * 0.45 + 3.0;
	vec3 water_far = vec3(0.02, 0.55, 0.66);
	vec3 water_top = vec3(0.20, 0.82, 0.88);
	float horizon = -0.05;
	vec3 col = mix(water_top, water_far, smoothstep(-0.55, horizon + 0.05, p.y));
	// surface glitter at the top
	col += vec3(1.0) * w_surface(p * vec2(1.0, 1.3), tt * 1.2) * smoothstep(-0.25, -0.55, p.y) * 0.45;
	float rays = w_rays(p, vec2(0.25, -1.1), 0.7, tt);
	col += vec3(0.9, 1.0, 1.0) * rays * 0.35;
	// sandy floor in perspective
	vec3 fl = w_floor(p, horizon, 0.16);
	if (fl.z > 0.0) {
		vec2 fc = fl.xy + vec2(tt * 0.02, 0.0);
		// sand ripples
		float warp = fbm(fc * 0.9) * 3.0;
		float ripples = 0.5 + 0.5 * sin(fc.x * 4.0 + fc.y * 1.3 + warp);
		float grain = hash12(floor(fc * 140.0)) * 0.06;
		vec3 sand = mix(vec3(0.38, 0.70, 0.70), vec3(0.55, 0.84, 0.80), ripples) * (0.94 + grain);
		// a few dark rocks / coral heads
		float rock = smoothstep(0.62, 0.66, fbm(fc * 0.35 + 9.0));
		sand = mix(sand, vec3(0.16, 0.30, 0.30) * (0.7 + 0.3 * fbm(fc * 3.0)), rock);
		// caustic net, stronger close up
		float c1 = pow(w_caustic(fc * 2.1, tt), 1.4);
		float c2 = pow(w_caustic(fc * 2.1 + 0.37, tt * 1.07), 1.4);
		sand += vec3(0.85, 1.0, 1.0) * (c1 * 1.6 + c2 * 0.6) * (1.0 - rock * 0.7) * exp(-fl.z * 0.25);
		// shading of the ripples
		sand *= 0.82 + 0.18 * ripples;
		float fog = exp(-fl.z * 0.40);
		vec3 floor_col = mix(water_far, sand * vec3(0.85, 1.0, 1.0), fog);
		col = mix(col, floor_col, smoothstep(0.0, 0.30, p.y - horizon));
	}
	col += vec3(1.0) * w_motes(p, 30.0, tt) * 0.25;
	col = mix(col, col * mix(vec3(1.0), game_tint.rgb * 1.3, 0.3), game_tint_amount * 0.3);
	col = mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, 1.35);
	col *= intensity * 0.80;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
