// FORGE OS wallpaper — Nebula: slow, deep-space gas clouds lit from within, with a field of
// twinkling stars at two depths.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"

vec3 stars(vec2 p, float scale, float tt) {
	vec2 q = p * scale;
	vec2 id = floor(q);
	vec2 f = fract(q) - 0.5;
	float h = hash12(id);
	if (h > 0.12) return vec3(0.0);
	vec2 o = hash22(id) - 0.5;
	float d = length(f - o * 0.7);
	float tw = 0.55 + 0.45 * sin(tt * (1.0 + 3.0 * h) + h * 60.0);
	float s = exp(-d * d * 900.0) + exp(-d * 14.0) * 0.05;
	return mix(vec3(0.8, 0.88, 1.0), vec3(1.0, 0.9, 0.8), hash12(id + 4.0)) * s * tw;
}

void fragment() {
	vec2 p = wp_coords(UV) + parallax;
	float tt = t * 0.25;
	vec3 a = pal_a(); vec3 b = pal_b(); vec3 c = pal_c();
	// Domain-warped gas: two layers of fbm feeding each other.
	vec2 q = vec2(fbm(p * 1.4 + vec2(0.0, tt * 0.3)), fbm(p * 1.4 + vec2(5.2, 1.3) - tt * 0.2));
	vec2 r = vec2(fbm(p * 1.8 + 3.0 * q + vec2(1.7, 9.2) + tt * 0.15), fbm(p * 1.8 + 3.0 * q + vec2(8.3, 2.8)));
	float gas = fbm(p * 1.6 + 2.6 * r);
	float dens = smoothstep(0.35, 0.95, gas);
	vec3 col = c_base.rgb * 0.8;
	col += mix(a, b, clamp(q.x * 1.2, 0.0, 1.0)) * dens * 0.55;
	col += mix(c, c_glow.rgb, clamp(r.y, 0.0, 1.0)) * pow(dens, 3.0) * 0.55;
	// Dark dust lanes.
	col *= 1.0 - smoothstep(0.55, 0.75, fbm(p * 3.2 - r * 1.5)) * 0.55;
	// Bright core glow.
	col += c_glow.rgb * exp(-length(p - vec2(0.25, -0.1) - q * 0.2) * 3.0) * 0.18 * dens;
	col *= intensity;
	col += stars(p + parallax * 0.4, 38.0, t) * 0.9;
	col += stars(p + parallax * 1.2, 70.0, t * 1.3) * 0.6;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
