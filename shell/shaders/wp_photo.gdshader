// FORGE OS wallpaper — your own photo, filling the screen, with gentle parallax and the
// same dimming and finish as the other wallpapers.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"

uniform sampler2D photo : filter_linear_mipmap, repeat_disable;
uniform vec2 photo_size = vec2(1920.0, 1080.0);
uniform float soften = 0.0;       // 0..1 blur for a calmer background

void fragment() {
	// Cover-fit: fill the screen, crop the overflow, keep the centre.
	float sa = res.x / res.y;
	float pa = photo_size.x / max(photo_size.y, 1.0);
	vec2 uv = UV - 0.5;
	if (pa > sa) uv.x *= sa / pa; else uv.y *= pa / sa;
	uv = uv * 0.96 + 0.5 + parallax * 0.25;  // a little headroom for parallax
	vec3 col = textureLod(photo, uv, soften * 5.0).rgb * intensity;
	// Your photo keeps its own colours: only a soft vignette, dimming and the intro fade.
	vec2 p = wp_coords(UV);
	col *= mix(0.7, 1.0, smoothstep(1.3, 0.3, length(p * vec2(0.9, 1.15))));
	col *= (1.0 - dim * 0.55) * reveal;
	COLOR = vec4(col, 1.0);
}
