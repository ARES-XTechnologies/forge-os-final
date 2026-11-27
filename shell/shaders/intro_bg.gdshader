// FORGE OS — intro backdrop: a dark forge, warm light breathing in the centre,
// smoke drifting through it.
shader_type canvas_item;
render_mode unshaded;

uniform float t = 0.0;
uniform float glow = 0.0;       // 0..1 central light
uniform float flash = 0.0;      // 0..1 burst when the logo forms
uniform float fade = 1.0;       // overall opacity (fades to reveal the shell)
uniform vec2 res = vec2(1920.0, 1080.0);
uniform vec2 center = vec2(0.5, 0.46);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

void fragment() {
	float aspect = res.x / res.y;
	vec2 p = (UV - center) * vec2(aspect, 1.0);
	float r = length(p);
	vec3 col = vec3(0.012, 0.008, 0.006);
	// smoke
	float s = fbm(p * 2.2 + vec2(0.0, -t * 0.06)) * fbm(p * 3.7 + vec2(t * 0.03, -t * 0.09));
	vec3 warm = vec3(1.0, 0.62, 0.24);
	col += warm * s * 0.18 * (0.3 + glow);
	// central light pool
	col += warm * exp(-r * r * 5.5) * 0.30 * glow;
	col += vec3(1.0, 0.82, 0.5) * exp(-r * r * 26.0) * 0.25 * glow;
	// flash bloom
	col += vec3(1.0, 0.86, 0.6) * exp(-r * r * (3.0 + 10.0 * (1.0 - flash))) * flash * 0.9;
	// vignette
	col *= smoothstep(1.3, 0.2, r);
	col += (hash12(UV * res + t * 60.0) - 0.5) * 0.01;
	COLOR = vec4(col, fade);
}
