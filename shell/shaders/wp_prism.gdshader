// FORGE OS wallpaper — Prism: broad sheets of light fall slowly through the dark like light
// through tall glass panels. Where each sheet's edge passes through the glass it splits into
// soft spectral fringes; fine dust glows inside the light.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"

// A soft light sheet: brightness across its width, for a given colour channel offset.
float sheet(vec2 p, float ang, float off, float width, float tt, float shift) {
	vec2 dir = vec2(sin(ang), cos(ang));
	vec2 n = vec2(dir.y, -dir.x);
	float across = dot(p, n) - off - shift;
	float body = smoothstep(width, width * 0.55, abs(across));
	float along = dot(p, dir);
	return body * smoothstep(1.1, -0.6, along) * (0.75 + 0.25 * noise(vec2(along * 3.0 - tt * 0.2, off * 9.0)));
}

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.35;
	float tt = t * 0.35 + 8.0;
	vec3 col = mix(vec3(0.020, 0.022, 0.045), vec3(0.006, 0.007, 0.016), smoothstep(-0.6, 0.6, p.y));
	vec3 light = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float ang = -0.35 + fi * 0.13 + 0.05 * sin(tt * 0.25 + fi * 1.7);
		float off = -0.75 + fi * 0.48 + 0.08 * sin(tt * 0.18 + fi);
		float w = 0.09 + 0.05 * hash12(vec2(fi, 1.0));
		float disp = 0.012 + 0.006 * fi;   // how far the colours separate at the edges
		vec3 s = vec3(sheet(p, ang, off, w, tt, -disp), sheet(p, ang, off, w, tt, 0.0), sheet(p, ang, off, w, tt, disp));
		// white core + spectral fringes where the channels don't overlap
		float core = min(s.r, min(s.g, s.b));
		vec3 fringe = s - core;
		vec3 tint = mix(vec3(1.0), mix(pal_a(), pal_c(), fi / 3.0), 0.25);
		light += (tint * core * 0.38 + fringe * vec3(1.0, 0.9, 1.1) * 0.6) * (0.7 + 0.3 * sin(tt * 0.4 + fi * 2.1));
	}
	col += light;
	// glow where the light comes from (top)
	col += vec3(0.35, 0.38, 0.5) * exp(-length(p - vec2(-0.2, -0.75)) * 2.4) * 0.35;
	// dust glinting inside the light
	vec2 g = p * 30.0 + vec2(tt * 0.12, -tt * 0.06);
	vec2 id = floor(g);
	float mote = smoothstep(0.07, 0.0, length(fract(g) - hash22(id))) * step(0.72, hash12(id));
	col += vec3(1.0) * mote * clamp(length(light) * 2.5, 0.0, 1.0) * 0.6;
	col *= intensity;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
