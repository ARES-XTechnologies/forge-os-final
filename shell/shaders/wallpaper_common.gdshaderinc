// FORGE OS — shared parts of every wallpaper shader.
// Each wallpaper takes the same inputs (palette colours, time, brightness, parallax, dimming,
// intro reveal, game-colour tint) so Settings and the shell drive them all the same way.

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
uniform float game_tint_amount = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x),
	           mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = m * p;
		a *= 0.5;
	}
	return v;
}

// Palette colours, pulled toward the focused game's colour when "match colours" is on.
vec3 pal_a() { return mix(c_a.rgb, game_tint.rgb, game_tint_amount * 0.7); }
vec3 pal_b() { return mix(c_b.rgb, game_tint.rgb * vec3(0.85, 0.9, 1.1), game_tint_amount * 0.45); }
vec3 pal_c() { return mix(c_c.rgb, game_tint.rgb, game_tint_amount * 0.35); }

// Centred, aspect-correct coordinates (y down, height = 1).
vec2 wp_coords(vec2 uv) {
	return (uv - 0.5) * vec2(res.x / res.y, 1.0);
}

// Tone-map, vignette, grain, dimming and intro reveal: the same finish on every wallpaper.
vec3 wp_finish(vec3 col, vec2 uv) {
	col = vec3(1.0) - exp(-col * 1.35);
	vec2 p = wp_coords(uv);
	float v = smoothstep(1.25, 0.25, length(p * vec2(0.9, 1.15)));
	col *= mix(0.55, 1.0, v);
	col += (hash12(uv * res + fract(t * 7.0) * 100.0) - 0.5) * 0.012;
	col *= (1.0 - dim * 0.55) * reveal;
	return col;
}
