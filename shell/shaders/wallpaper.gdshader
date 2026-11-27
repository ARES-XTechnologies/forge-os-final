// FORGE OS — Living wallpaper
// Silk ribbons of light drifting through a deep night sky. Each ribbon is a bundle of
// hair-thin strands that twist around a flowing centre line, so the light reads like
// fabric. Floating bokeh and a faint grain finish it.
// Time is fed from script so the speed can change without the motion jumping.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 c_base : source_color = vec4(0.024, 0.027, 0.078, 1.0);
uniform vec4 c_a : source_color = vec4(0.23, 0.42, 1.0, 1.0);
uniform vec4 c_b : source_color = vec4(0.60, 0.36, 1.0, 1.0);
uniform vec4 c_c : source_color = vec4(0.18, 0.84, 1.0, 1.0);
uniform vec4 c_glow : source_color = vec4(1.0, 0.36, 0.78, 1.0);
uniform float t = 0.0;
uniform float intensity = 1.0;
uniform vec2 parallax = vec2(0.0);
uniform vec2 res = vec2(1920.0, 1080.0);
uniform float dim = 0.0;          // darkens for overlays
uniform float reveal = 1.0;       // 0..1 intro fade-in
uniform vec4 game_tint : source_color = vec4(1.0);
uniform float game_tint_amount = 0.0;   // dynamic theme: how much the focused game's colour tints the sky

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x),
	           mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

// One silk ribbon. Returns rgb light.
vec3 ribbon(vec2 p, float tt, float seed, float y0, float slope, float amp, float spread, vec3 ca, vec3 cb) {
	float x = p.x;
	float center = y0 + slope * x
		+ amp * sin(x * 1.25 + tt * 0.21 + seed)
		+ amp * 0.55 * sin(x * 2.6 - tt * 0.15 + seed * 2.3)
		+ amp * 0.25 * sin(x * 4.1 + tt * 0.33 + seed * 0.7);
	float dc = p.y - center;
	// Twist: the bundle's width breathes along x, so strands cross and fold like silk.
	float twist = sin(x * 1.6 + tt * 0.27 + seed * 1.7);
	float w = spread * (0.35 + 0.65 * abs(twist));
	vec3 tone = mix(ca, cb, 0.5 + 0.5 * sin(x * 0.9 + tt * 0.11 + seed));
	vec3 acc = vec3(0.0);
	// Broad glow under the strands
	acc += tone * exp(-dc * dc / (w * w * 2.2 + 0.002)) * 0.22;
	// Strands
	for (int i = 0; i < 18; i++) {
		float fi = float(i) / 17.0 - 0.5;
		float off = fi * w * 2.0 * twist + 0.004 * sin(x * 7.0 + float(i) * 1.7 + tt * 0.4);
		float ds = dc - off;
		float thin = 0.0016 + 0.0024 * (1.0 - abs(fi) * 1.6);
		float line = exp(-(ds * ds) / (thin * thin));
		float fade = 1.0 - abs(fi) * 1.4;
		acc += tone * line * max(fade, 0.0) * 0.16;
	}
	// Fade the ribbon in/out along its length for an organic silhouette.
	float len = smoothstep(-1.4, -0.2, x + 0.25 * sin(tt * 0.1 + seed)) * (1.0 - smoothstep(0.4, 1.5, x - 0.2 * sin(tt * 0.13 + seed)));
	return acc * (0.35 + 0.65 * len);
}

vec3 bokeh(vec2 p, float tt, float scale, float speed, vec3 col, float seed) {
	vec2 q = p * scale + vec2(tt * speed * 0.3, -tt * speed);
	vec2 id = floor(q);
	vec2 f = fract(q) - 0.5;
	float h = hash12(id + seed);
	if (h > 0.42) return vec3(0.0);
	vec2 o = vec2(hash12(id + 3.1 + seed), hash12(id + 7.7 + seed)) - 0.5;
	float r = 0.08 + 0.16 * hash12(id + 11.0 + seed);
	float d = length(f - o * 0.6);
	float disk = smoothstep(r, r * 0.55, d);
	float ring = smoothstep(r, r * 0.86, d) - smoothstep(r * 0.86, r * 0.72, d);
	float tw = 0.6 + 0.4 * sin(tt * (0.5 + h) + h * 40.0);
	return col * (disk * 0.10 + ring * 0.05) * tw;
}

void fragment() {
	float aspect = res.x / res.y;
	vec2 uv = UV;
	float gt = game_tint_amount;
	vec3 ta = mix(c_a.rgb, game_tint.rgb, gt * 0.7);
	vec3 tb = mix(c_b.rgb, game_tint.rgb * vec3(0.85, 0.9, 1.1), gt * 0.45);
	vec3 tc = mix(c_c.rgb, game_tint.rgb, gt * 0.35);
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
	vec2 pp = p + parallax;
	float tt = t;

	// Deep sky: vertical gradient + soft light pool top-right + faint drifting haze.
	vec3 col = c_base.rgb + game_tint.rgb * 0.025 * gt;
	col += ta * 0.06 * smoothstep(1.1, -0.3, length(p - vec2(0.55, -0.45)));
	col += tb * 0.05 * smoothstep(1.2, -0.2, length(p - vec2(-0.7, 0.55)));
	float haze = noise(pp * 1.6 + vec2(tt * 0.02, 0.0)) * noise(pp * 3.1 - vec2(0.0, tt * 0.015));
	col += mix(ta, tb, 0.5) * haze * 0.06;

	// Silk ribbons (sweeping diagonally like the reference, at different depths).
	vec3 light = vec3(0.0);
	light += ribbon(pp * 1.00 + parallax * 0.6, tt, 0.0, 0.10, -0.10, 0.10, 0.065, ta, tb);
	light += ribbon(pp * 0.92 + parallax * 0.9, tt * 0.85, 2.4, 0.20, -0.16, 0.08, 0.05, tb, c_glow.rgb) * 0.85;
	light += ribbon(pp * 1.15 + parallax * 0.3, tt * 1.1, 4.9, 0.02, -0.05, 0.12, 0.04, tc, ta) * 0.7;
	light *= intensity;

	// Bokeh (two depths).
	light += bokeh(pp + parallax * 0.5, tt, 5.0, 0.015, mix(ta, tc, 0.5), 1.0);
	light += bokeh(pp + parallax * 1.2, tt, 9.0, 0.03, mix(tb, c_glow.rgb, 0.4), 5.0) * 0.7;

	col += light;

	// Filmic shoulder so overlapping light blooms instead of clipping.
	col = vec3(1.0) - exp(-col * 1.35);

	// Vignette + grain.
	float v = smoothstep(1.25, 0.25, length(p * vec2(0.9, 1.15)));
	col *= mix(0.55, 1.0, v);
	col += (hash12(uv * res + fract(tt * 7.0) * 100.0) - 0.5) * 0.012;

	col *= (1.0 - dim * 0.55) * reveal;
	COLOR = vec4(col, 1.0);
}
