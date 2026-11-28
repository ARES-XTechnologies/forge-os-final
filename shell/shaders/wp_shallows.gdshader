// FORGE OS wallpaper — Sunlit Shallows: bright turquoise water just under the surface. The
// rippling surface glitters above, wide sunbeams slant down from the left and fine bubbles
// drift up through the light.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"
#include "res://shaders/water_common.gdshaderinc"

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.4;
	float tt = t * 0.5 + 5.0;
	vec3 top = vec3(0.16, 0.80, 0.84);
	vec3 midc = vec3(0.00, 0.50, 0.60);
	vec3 low = vec3(0.00, 0.20, 0.32);
	float y = smoothstep(-0.55, 0.55, p.y);
	vec3 col = mix(top, midc, smoothstep(0.0, 0.5, y));
	col = mix(col, low, smoothstep(0.45, 1.0, y));
	// glittering surface overhead (seen from below), wobbling
	vec2 sp = p + vec2(0.02 * sin(p.y * 9.0 + tt), 0.0);
	float surf = w_surface(sp * vec2(1.0, 1.4), tt * 1.3);
	float near_top = smoothstep(-0.18, -0.58, p.y);
	col += vec3(0.85, 1.0, 0.98) * surf * near_top * 0.75;
	// the surface from below: a bright rippled light net, squashed by perspective
	vec2 sq = vec2(p.x / (0.6 - p.y * 0.8), 1.0 / (0.12 - p.y * 0.9));
	col += vec3(0.9, 1.0, 1.0) * w_caustic(sq * vec2(0.6, 0.25), tt * 0.9) * near_top * 1.1;
	// sun glow and slanted rays from the upper left
	col += vec3(0.9, 1.0, 0.95) * exp(-length(p - vec2(-0.75, -0.65)) * 2.0) * 0.55;
	float rays = w_rays(p, vec2(-0.95, -1.0), 0.65, tt);
	col += vec3(0.85, 1.0, 0.95) * rays * 0.55;
	// bubbles and floating specks
	float b = w_bubbles(p, 16.0, 1.2, tt, 0.10) * 0.7 + w_bubbles(p + 0.3, 28.0, 1.8, tt, 0.08) * 0.5;
	col += vec3(0.9, 1.0, 1.0) * b * 0.6;
	col += vec3(0.9, 1.0, 1.0) * w_motes(p, 34.0, tt) * (0.15 + rays);
	col = mix(col, col * mix(vec3(1.0), game_tint.rgb * 1.3, 0.3), game_tint_amount * 0.3);
	col = mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, 1.35);
	col *= intensity * 0.85;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
