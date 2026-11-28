// FORGE OS wallpaper — Golden Dust: warm golden particles drifting through the dark, lit by a
// soft ray of light from the top-left. Several depth layers: far dust is tiny and sharp,
// near dust is large, soft and out of focus. Particles glow brighter where the ray hits them.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"

const vec3 GOLD = vec3(1.0, 0.72, 0.42);
const vec3 PEACH = vec3(1.0, 0.82, 0.66);

// The ray: a soft cone from just above the top-left corner, with drifting haze inside it.
float light_ray(vec2 p, float tt) {
	vec2 src = vec2(-0.78, -0.95);
	vec2 d = p - src;
	float ang = atan(d.x, d.y);              // 0 = straight down
	float centre = 0.42;                      // the ray leans to the right
	float w = 0.24 + 0.03 * sin(tt * 0.21);
	float cone = exp(-pow((ang - centre) / w, 2.0));
	// fine beams inside the cone, slowly moving
	float beams = 0.55 + 0.45 * noise(vec2(ang * 24.0 + tt * 0.15, tt * 0.05));
	beams *= 0.7 + 0.3 * noise(vec2(ang * 61.0 - tt * 0.11, 3.0));
	float dist = length(d);
	float fall = exp(-dist * 0.95);
	float haze = 0.65 + 0.35 * fbm(d * 3.0 + vec2(tt * 0.04, -tt * 0.02));
	return cone * beams * fall * haze;
}

// One layer of dust. scale: cells per screen height; blur: 0 sharp .. 1 very soft.
vec3 dust(vec2 p, float scale, float drift, float size, float blur, float seed, float ray, float tt) {
	vec2 q = p * scale + vec2(-tt * drift, tt * drift * 0.35) + seed * 17.0;
	vec2 id = floor(q);
	vec2 f = fract(q);
	vec3 acc = vec3(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 o = vec2(float(i), float(j));
			vec2 cid = id + o;
			float h0 = hash12(cid + seed);
			// density: a thick drifting band through the middle, thinner above and below
			vec2 world = (cid + 0.5 - vec2(-tt * drift, tt * drift * 0.35) - seed * 17.0) / scale;
			float band = exp(-pow((world.y - 0.12 + 0.06 * sin(world.x * 2.0 + tt * 0.1)) / 0.30, 2.0));
			float keep = mix(0.10, 0.85, band);
			if (h0 > keep) continue;
			vec2 h = hash22(cid * 1.37 + seed);
			vec2 pos = o + 0.12 + 0.76 * h + 0.18 * vec2(sin(tt * 0.35 + h.x * 6.283), cos(tt * 0.29 + h.y * 6.283));
			float d = length(f - pos);
			float r = size * (0.45 + 0.9 * hash12(cid + seed * 3.1));
			float soft = r * (0.15 + blur * 0.85);
			float disc = 1.0 - smoothstep(r - soft, r, d);
			// out-of-focus discs have a slightly brighter rim, like real bokeh
			float rim = blur > 0.4 ? smoothstep(r - soft * 1.2, r - soft * 0.3, d) * disc * 0.35 : 0.0;
			float tw = 0.55 + 0.45 * sin(tt * (0.8 + h.x * 1.6) + h.y * 40.0);
			vec3 tint = mix(GOLD, PEACH, h.y * 0.6);
			// a soft glow around each grain makes it sparkle
			float glow = exp(-d / (r * 1.6)) * (1.0 - blur) * 0.35;
			acc += tint * ((disc * (0.75 + 0.25 * tw) + rim) + glow * tw) * (0.55 + 2.2 * ray);
		}
	}
	return acc;
}

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.35;
	float tt = t * 0.6 + 40.0;
	// deep charcoal-navy background with a faint warm floor haze
	vec3 col = mix(vec3(0.030, 0.034, 0.055), vec3(0.016, 0.018, 0.032), smoothstep(-0.5, 0.5, p.y));
	col += vec3(0.11, 0.095, 0.085) * smoothstep(0.15, 0.55, p.y) * (0.6 + 0.4 * fbm(p * 2.0 + tt * 0.02));
	float ray = light_ray(p, tt);
	col += vec3(1.0, 0.84, 0.70) * ray * 0.75;
	// warm bloom where the light comes in
	col += vec3(1.0, 0.78, 0.6) * exp(-length(p - vec2(-0.85, -0.6)) * 2.2) * 0.35;
	// far -> near
	col += dust(p + parallax * 0.05, 30.0, 0.020, 0.10, 0.05, 1.0, ray, tt) * 0.9;
	col += dust(p + parallax * 0.15, 17.0, 0.030, 0.11, 0.18, 2.0, ray, tt) * 0.9;
	col += dust(p + parallax * 0.35, 9.0, 0.045, 0.12, 0.55, 3.0, ray, tt) * 0.55;
	col += dust(p + parallax * 0.70, 4.5, 0.070, 0.13, 0.95, 4.0, ray, tt) * 0.28;
	col = mix(col, col * mix(vec3(1.0), game_tint.rgb * 1.4, 0.25), game_tint_amount * 0.4);
	col *= intensity * 0.8;   // a little calmer: 20% softer overall
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
