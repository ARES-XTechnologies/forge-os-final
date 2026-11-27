// FORGE OS — game art inside a glass card.
// Cover-fits the texture, rounds the corners with an anti-aliased mask, adds a glass
// sheen, a travelling shine on focus and a dim for unfocused cards.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D art : source_color, filter_linear_mipmap;
uniform bool has_art = false;
uniform vec2 size = vec2(240.0, 360.0);
uniform vec2 art_size = vec2(600.0, 900.0);
uniform float radius = 18.0;
uniform float dim = 0.0;
uniform float shine = -1.0;
uniform float saturation = 1.0;
uniform float zoom = 1.0;
uniform vec4 fallback_a : source_color = vec4(0.18, 0.22, 0.45, 1.0);
uniform vec4 fallback_b : source_color = vec4(0.45, 0.2, 0.55, 1.0);
uniform float opacity = 1.0;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void fragment() {
	vec2 px = UV * size;
	float d = sd_round_box(px - size * 0.5, size * 0.5, radius);
	float mask = clamp(0.5 - d, 0.0, 1.0);

	vec3 col;
	if (has_art) {
		// cover fit
		float ra = art_size.x / art_size.y;
		float rs = size.x / size.y;
		vec2 uv = UV - 0.5;
		if (ra > rs) { uv.x *= rs / ra; } else { uv.y *= ra / rs; }
		uv = uv / zoom + 0.5;
		col = texture(art, uv).rgb;
	} else {
		col = mix(fallback_a.rgb, fallback_b.rgb, UV.y * 0.8 + UV.x * 0.2);
		col += 0.06 * sin(UV.x * 9.0 + UV.y * 5.0);
	}
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);

	// Glass sheen: brighter top, very subtle.
	col += vec3(0.05) * smoothstep(0.35, 0.0, UV.y);
	// Inner edge darkening gives the art depth under the glass.
	col *= 1.0 - 0.18 * smoothstep(-14.0, 0.0, d);

	if (shine > -0.5) {
		float diag = (UV.x + UV.y * 0.55) - shine * 2.4 + 0.4;
		col += vec3(exp(-diag * diag * 60.0) * 0.28);
	}
	col *= 1.0 - dim;
	COLOR = vec4(col, mask * opacity);
}
