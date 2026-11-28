// FORGE OS wallpaper — The Deep: deep blue water, strong god rays falling from the surface far
// above, columns of bubbles rising, and a dim sandy floor with soft caustics.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"
#include "res://shaders/water_common.gdshaderinc"

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.4;
	float tt = t * 0.5 + 11.0;
	vec3 deep = vec3(0.005, 0.03, 0.09);
	vec3 mid = vec3(0.02, 0.17, 0.36);
	vec3 shallow = vec3(0.10, 0.48, 0.72);
	// water: bright toward the light above, deep below
	float up = smoothstep(0.55, -0.6, p.y);
	vec3 col = mix(deep, mid, up);
	col = mix(col, shallow, pow(up, 3.0) * 0.8);
	col += shallow * exp(-length(p - vec2(0.05, -0.7)) * 2.2) * 0.55;   // glow of the sun above
	// surface ripples at the very top
	col += vec3(0.6, 0.9, 1.0) * w_surface(p, tt) * smoothstep(-0.32, -0.55, p.y) * 0.35;
	// god rays
	float rays = w_rays(p, vec2(0.05, -1.05), 0.55, tt);
	col += vec3(0.55, 0.85, 1.0) * rays * 0.55;
	// floor
	vec3 fl = w_floor(p, 0.22, 0.12);
	if (fl.z > 0.0) {
		vec2 fc = fl.xy;
		float sand = 0.5 + 0.5 * fbm(fc * 1.6);
		float ripple = 0.5 + 0.5 * sin(fc.x * 7.0 + fbm(fc * 2.0) * 6.0);
		vec3 floor_col = vec3(0.08, 0.27, 0.40) * (0.65 + 0.35 * sand) * (0.85 + 0.15 * ripple);
		float caus = w_caustic(fc * 0.55, tt * 0.8);
		floor_col += vec3(0.45, 0.85, 1.0) * caus * 0.75 * smoothstep(0.0, 0.25, p.y - 0.22);
		float fog = exp(-fl.z * 0.45);
		col = mix(col, floor_col, fog * smoothstep(0.0, 0.22, p.y - 0.22));
	}
	// bubbles and motes
	float b = w_bubbles(p + vec2(0.0, 0.0), 7.0, 0.9, tt, 0.18) + w_bubbles(p + vec2(0.37, 0.0), 13.0, 1.4, tt, 0.12) * 0.6;
	col += vec3(0.65, 0.9, 1.0) * b * (0.35 + 0.4 * up);
	col += vec3(0.5, 0.8, 1.0) * w_motes(p, 26.0, tt) * 0.25 * (0.4 + rays * 2.0);
	col = mix(col, col * mix(vec3(1.0), game_tint.rgb * 1.3, 0.3), game_tint_amount * 0.35);
	col *= intensity;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
