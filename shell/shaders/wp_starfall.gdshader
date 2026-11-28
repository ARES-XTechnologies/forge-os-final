// FORGE OS wallpaper — Starfall: a clear night over mountain ranges, thousands of stars, the
// Milky Way arcing across, a faint teal-violet horizon and a shooting star every few seconds.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"
#include "res://shaders/sky_common.gdshaderinc"

// a shooting star every few seconds, somewhere in the upper sky
vec3 shooting(vec2 p, float tt, float period) {
	float k = floor(tt / period);
	float ph = fract(tt / period);
	vec2 hk = hash22(vec2(k, 1.3));
	vec2 start = vec2(-0.7 + hk.x * 1.3, -0.48 + hk.y * 0.22);
	vec2 dir = normalize(vec2(0.9, 0.35 + hk.x * 0.25));
	float life = smoothstep(0.0, 0.04, ph) * smoothstep(0.28, 0.10, ph);
	vec2 rel = p - (start + dir * ph * 1.8);
	float along = dot(rel, -dir);
	float across = abs(dot(rel, vec2(-dir.y, dir.x)));
	float trail = smoothstep(0.0028, 0.0, across - along * 0.004) * smoothstep(0.30, 0.0, along) * step(0.0, along);
	return vec3(0.9, 0.95, 1.0) * (trail * 1.4 + exp(-length(rel) * 150.0) * 1.6) * life;
}

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.25;
	float tt = t * 0.5 + 3.0;
	vec3 col = mix(vec3(0.07, 0.06, 0.16), vec3(0.006, 0.008, 0.03), smoothstep(0.3, -0.55, p.y));
	col += vec3(0.06, 0.14, 0.18) * exp(-abs(p.y - 0.25) * 5.0);
	vec2 mw = s_milky(p, vec2(0.1, -0.12), -0.55, 0.17);
	col += mix(vec3(0.30, 0.26, 0.45), vec3(0.55, 0.45, 0.40), mw.x * 0.5) * mw.x * 0.55;
	col *= 1.0 - mw.y * 0.45;
	col += s_stars(p, tt, mw.x);
	col += shooting(p, tt, 5.5);
	float far = 0.30 - s_ridge(p.x * 1.6, 2.0, 1.0) * 0.30;
	float nearr = 0.42 - s_ridge(p.x * 1.1, 7.0, 1.0) * 0.26;
	if (p.y > far) col = mix(vec3(0.02, 0.03, 0.06), vec3(0.01, 0.012, 0.025), smoothstep(far, far + 0.15, p.y));
	if (p.y > nearr) col = vec3(0.0);
	col = mix(col, col * mix(vec3(1.0), game_tint.rgb * 1.3, 0.25), game_tint_amount * 0.25);
	col *= intensity;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
