// FORGE OS — hero backdrop for the focused game.
// Cross-fades between two images, slow cinematic drift, melts into the wallpaper.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tex_a : source_color, filter_linear_mipmap;
uniform sampler2D tex_b : source_color, filter_linear_mipmap;
uniform vec2 size_a = vec2(1920.0, 620.0);
uniform vec2 size_b = vec2(1920.0, 620.0);
uniform bool has_a = false;
uniform bool has_b = false;
uniform float mix_ab = 0.0;        // 0 = a, 1 = b
uniform vec2 view = vec2(1920.0, 1080.0);
uniform float drift = 0.0;         // seconds, drives the Ken Burns motion
uniform float strength = 1.0;
uniform float bottom_fade = 0.72;  // where the image fully dissolves (0..1 of height)

vec4 sample_cover(sampler2D tex, vec2 tsize, vec2 uv, float z, vec2 pan) {
	float ra = tsize.x / tsize.y;
	float rs = view.x / view.y;
	vec2 q = uv - 0.5;
	if (ra > rs) { q.x *= rs / ra; } else { q.y *= ra / rs; }
	q = q / z + 0.5 + pan;
	return texture(tex, q);
}

void fragment() {
	float z = 1.06 + 0.03 * sin(drift * 0.05);
	vec2 pan = vec2(sin(drift * 0.037), cos(drift * 0.029)) * 0.012;
	vec3 a = has_a ? sample_cover(tex_a, size_a, UV, z, pan).rgb : vec3(0.0);
	vec3 b = has_b ? sample_cover(tex_b, size_b, UV, z, -pan).rgb : vec3(0.0);
	float wa = has_a ? 1.0 - mix_ab : 0.0;
	float wb = has_b ? mix_ab : 0.0;
	vec3 col = a * wa + b * wb;
	float alpha = clamp(wa + wb, 0.0, 1.0);

	// Readability: darken left third and the top band, melt the bottom into the sky.
	float left = mix(0.35, 1.0, smoothstep(0.0, 0.62, UV.x));
	float top = mix(0.6, 1.0, smoothstep(0.0, 0.22, UV.y));
	float fade = 1.0 - smoothstep(bottom_fade * 0.45, bottom_fade, UV.y);
	col *= left * top;
	COLOR = vec4(col, alpha * fade * strength * 0.92);
}
