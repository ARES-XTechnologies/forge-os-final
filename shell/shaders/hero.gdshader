// FORGE OS — hero backdrop for the focused game. Cross-fades between two images with a slow
// cinematic drift.
//
// Two looks (Settings › Appearance › Game art):
//   Blend        the art sits at the top and melts into the wallpaper (darker on the left).
//   Full screen  the art covers the whole screen, no dark fade. Each picture is fitted by its
//                shape (fit_a / fit_b, chosen in home.gd):
//                  0  fills the screen well: simply cover it, keeping the top part
//                  1  very wide banner (most Steam art): sharp across the top 70% of the
//                     screen, and a soft mirrored reflection of it fills the rest
//                  2  small or low-resolution picture: a soft, blurred, colour-rich fill
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tex_a : source_color, filter_linear_mipmap;
uniform sampler2D tex_b : source_color, filter_linear_mipmap;
uniform vec2 size_a = vec2(1920.0, 620.0);
uniform vec2 size_b = vec2(1920.0, 620.0);
uniform bool has_a = false;
uniform bool has_b = false;
uniform int fit_a = 0;
uniform int fit_b = 0;
uniform float mix_ab = 0.0;        // 0 = a, 1 = b
uniform vec2 view = vec2(1920.0, 1080.0);
uniform float drift = 0.0;         // seconds, drives the Ken Burns motion
uniform float strength = 1.0;
uniform float bottom_fade = 0.72;  // Blend: where the image fully dissolves (0..1 of height)
uniform bool full = false;         // Full screen look
const float BAND = 0.70;           // Full screen, wide art: the share of the screen it fills

vec4 sample_cover(sampler2D tex, vec2 tsize, vec2 uv, float z, vec2 pan) {
	float ra = tsize.x / tsize.y;
	float rs = view.x / view.y;
	vec2 q = uv - 0.5;
	if (ra > rs) { q.x *= rs / ra; } else { q.y *= ra / rs; }
	q = q / z + 0.5 + pan;
	return texture(tex, q);
}

// Smooth blur: 24 taps on a golden-angle spiral with a Gaussian weight, read from a mip level
// that matches the radius. Reading a low mip level directly looks blocky (big square texels);
// spreading many soft taps over it gives a clean, glassy blur at any radius.
vec3 blur(sampler2D tex, vec2 uv, vec2 tsize, float px) {
	float lod = max(0.0, log2(px / 6.0));
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 24; i++) {
		float fi = float(i);
		float r = sqrt((fi + 0.5) / 24.0);
		float a = fi * 2.3999632;
		vec2 o = vec2(cos(a), sin(a)) * r * px / tsize;
		float w = exp(-r * r * 2.2);
		acc += textureLod(tex, uv + o, lod).rgb * w;
		wsum += w;
	}
	return acc / wsum;
}

// Full screen fitting.
vec3 sample_full(sampler2D tex, vec2 tsize, int fit, vec2 uv, float z, vec2 pan) {
	float ra = tsize.x / tsize.y;
	float rs = view.x / view.y;
	if (fit == 1) {
		// sharp band across the top; the picture is a little wider than the screen, so a
		// slice of each side is cropped (slightly more on the left: the hero is usually right)
		float wfrac = BAND * ra / rs;
		float u = (uv.x - 0.5) / wfrac + 0.5 + (1.0 - 1.0 / wfrac) * 0.08;
		u = (u - 0.5) / z + 0.5 + pan.x;
		if (uv.y <= BAND) {
			float v = (uv.y / BAND - 0.5) / z + 0.5 + pan.y;
			// soften the very bottom rows so the seam with the reflection disappears
			float seam = smoothstep(BAND - 0.035, BAND, uv.y);
			vec3 sharp = textureLod(tex, vec2(u, v), 0.0).rgb;
			vec3 soft = blur(tex, vec2(u, v), tsize, 10.0) * 0.9;
			return mix(sharp, soft, seam);
		}
		// mirrored below the band, blurring and dimming as it goes down (like a phone's
		// now-playing art spilling into the screen)
		float k = (uv.y - BAND) / (1.0 - BAND);
		float v = 1.0 - (uv.y - BAND) / BAND;
		v = (v - 0.5) / z + 0.5 + pan.y;
		vec3 c = blur(tex, vec2(u, v), tsize, mix(10.0, 46.0, k));
		return c * mix(0.88, 0.55, k);
	}
	if (fit == 2) {
		// low-resolution picture: blurred colour fill
		vec2 q = uv - 0.5;
		if (ra > rs) { q.x *= rs / ra; } else { q.y *= ra / rs; }
		q = q / (z * 1.15) + 0.5 + pan;
		return blur(tex, q, tsize, 0.035 * max(tsize.x, tsize.y)) * 0.8;
	}
	// cover the whole screen; if the picture is taller than the screen keep its upper part
	vec2 q = uv - 0.5;
	if (ra > rs) { q.x *= rs / ra; } else { q.y *= ra / rs; q.y -= (1.0 - ra / rs) * 0.25; }
	q = q / z + 0.5 + pan;
	return textureLod(tex, q, 0.0).rgb;
}

void fragment() {
	float z = 1.06 + 0.03 * sin(drift * 0.05);
	vec2 pan = vec2(sin(drift * 0.037), cos(drift * 0.029)) * 0.012;
	float wa = has_a ? 1.0 - mix_ab : 0.0;
	float wb = has_b ? mix_ab : 0.0;
	float alpha = clamp(wa + wb, 0.0, 1.0);
	if (full) {
		vec3 a = has_a ? sample_full(tex_a, size_a, fit_a, UV, z, pan) : vec3(0.0);
		vec3 b = has_b ? sample_full(tex_b, size_b, fit_b, UV, z, -pan) : vec3(0.0);
		vec3 col = (a * wa + b * wb) / max(alpha, 0.001);
		COLOR = vec4(col, alpha * strength);
	} else {
		vec3 a = has_a ? sample_cover(tex_a, size_a, UV, z, pan).rgb : vec3(0.0);
		vec3 b = has_b ? sample_cover(tex_b, size_b, UV, z, -pan).rgb : vec3(0.0);
		vec3 col = a * wa + b * wb;
		// Readability: darken left third and the top band, melt the bottom into the sky.
		float left = mix(0.35, 1.0, smoothstep(0.0, 0.62, UV.x));
		float top = mix(0.6, 1.0, smoothstep(0.0, 0.22, UV.y));
		float fade = 1.0 - smoothstep(bottom_fade * 0.45, bottom_fade, UV.y);
		col *= left * top;
		COLOR = vec4(col, alpha * fade * strength * 0.92);
	}
}
