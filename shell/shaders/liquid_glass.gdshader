// FORGE OS — Liquid Glass with Contour Glow
// The panel is a thick, clear slab of glass with a rounded bevel. What's behind it shows
// through almost untouched (a light veil and a whisper of blur), the bevel bends the scene
// like a lens and splits colour slightly, and the rim catches two thin, bright arcs of light
// on opposite corners: the look of modern "liquid glass" controls.
//
// Styles: 0 Liquid (crystal clear like water, no haze, default), 1 Liquid Mist (clear lens with
// a soft light veil), 2 Frosted (soft blur, milky), 3 Matte (calm and nearly solid: least
// reflection and transparency, best for readability).
//
// Edges are anti-aliased against the real screen pixel size (fwidth), so rounded corners stay
// smooth at any UI scale or resolution.
//
// Contour glow (optional, off by default): a line of light that follows the edge. It takes
// its colour from whatever is behind the glass (or a chosen colour), carries a soft
// highlight that slowly orbits the panel, blooms just outside the edge and brightens on focus.
//
// The ColorRect is larger than the panel by `margin` so shadow, halo and glow render
// in the same pass.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;

uniform vec2 size = vec2(400.0, 200.0);   // full rect size in px (incl. margin)
uniform float margin = 40.0;              // px reserved around the panel for shadow/glow
uniform float radius = 28.0;
uniform float bevel = 22.0;               // width of the curved edge in px
uniform float refraction = 1.0;           // global strength (settings)
uniform float edge_bend = 26.0;           // px of displacement at the very edge
uniform float magnify = 0.035;            // interior lens magnification
uniform float dispersion = 1.0;
uniform vec4 tint : source_color = vec4(0.62, 0.72, 1.0, 1.0);
uniform float tint_amount = 0.10;
uniform float body_dim = 0.0;             // darkens what is seen through big sheets for legibility
uniform bool layered = false;             // glass on glass: translucent layer, no re-sampling
uniform float smoke = 0.0;                // layered only: dark smoked body for glass drawn over a running game
uniform float brightness = 0.035;
uniform float glass_brightness = 1.0;     // user setting: 0 = darker, 1 = default, 2 = very bright
uniform float specular = 1.0;
uniform float shadow = 0.55;
uniform float focus = 0.0;                // 0..1 focus glow
uniform vec4 focus_color : source_color = vec4(0.49, 0.78, 1.0, 1.0);
uniform float press = 0.0;
uniform float opacity = 1.0;
uniform float shine = -1.0;               // travelling highlight / focus sweep, -1 = off
uniform int style = 0;                    // 0 liquid, 1 mist, 2 frosted, 3 matte

// Contour glow
uniform bool glow_on = false;
uniform float glow_strength = 0.8;        // 1.0 = the original full brightness
uniform int glow_mode = 0;                // 0 adaptive, 1 accent, 2 gold, 3 ice, 4 rainbow
uniform bool glow_motion = true;
uniform float glow_seed = 0.0;            // per-panel phase so lights don't move in lockstep

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

vec3 hue(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

// Colour of the contour light at this spot.
vec3 glow_colour(vec2 suv, vec2 n, vec2 spx, float ang) {
	if (glow_mode == 1 || (glow_mode == 0 && smoke > 0.0)) return mix(focus_color.rgb, vec3(1.0), 0.25);
	if (glow_mode == 2) return vec3(1.0, 0.80, 0.46);
	if (glow_mode == 3) return vec3(0.70, 0.90, 1.0);
	if (glow_mode == 4) return mix(hue(ang / 6.2831 + TIME * 0.05 + glow_seed), vec3(1.0), 0.3);
	// Adaptive: average colour of the scene just outside this edge, saturated into light.
	vec3 bg = textureLod(screen_tex, suv + n * spx * 40.0, 4.5).rgb;
	float mx = max(max(bg.r, bg.g), max(bg.b, 0.04));
	vec3 c = bg / mx;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 1.35);
	return clamp(mix(c, vec3(1.0), 0.32), 0.0, 1.0);
}

// 0..1 brightness of the travelling highlights at this angle.
float orbit(float ang) {
	float t = glow_motion ? TIME * 0.42 + glow_seed * 6.2831 : glow_seed * 6.2831 + 2.2;
	float a = pow(max(cos(ang - t), 0.0), 7.0);
	float b = pow(max(cos(ang - t + 3.14159), 0.0), 14.0) * 0.45;
	float sweep = 0.0;
	if (shine > -0.5) {
		// focus sweep: one bright spark runs once around the edge
		float s = shine * 6.2831 - 1.5708;
		sweep = pow(max(cos(ang - s), 0.0), 18.0) * (1.0 - smoothstep(0.85, 1.2, shine)) * 1.6;
	}
	return a + b + sweep;
}

void fragment() {
	vec2 px = UV * size;
	vec2 half_panel = size * 0.5 - vec2(margin);
	vec2 c = size * 0.5;
	vec2 p = px - c;
	float r = min(radius, min(half_panel.x, half_panel.y));
	float d = sd_round_box(p, half_panel, r);
	vec2 spx = SCREEN_PIXEL_SIZE;
	float ang = atan(p.y / max(half_panel.y, 1.0), p.x / max(half_panel.x, 1.0));
	float gb = clamp(glass_brightness, 0.0, 2.0);

	// Surface normal from the SDF gradient (outward-pointing).
	vec2 e = vec2(1.0, 0.0);
	vec2 n = normalize(vec2(
		sd_round_box(p + e.xy, half_panel, r) - sd_round_box(p - e.xy, half_panel, r),
		sd_round_box(p + e.yx, half_panel, r) - sd_round_box(p - e.yx, half_panel, r)) + 1e-5);

	float gl = glow_on ? glow_strength : 0.0;
	vec3 gcol = vec3(0.0);
	float gorb = 0.0;
	if (gl > 0.0) {
		gcol = glow_colour(SCREEN_UV, n, spx, ang);
		gorb = orbit(ang);
	}
	// Base level everywhere on the edge + travelling highlights + focus lift.
	// Glass on glass (a focused row, a button) gets a softer glow than the panel it sits on,
	// and focus lifts it only a little: a bright row glowing over a bright panel washed out.
	float glevel = gl * (0.32 + 0.95 * gorb) * (0.75 + 0.35 * focus) * (layered ? 0.45 : 1.0);

	// Per-style recipe.
	float blur = 0.0;        // mip level: how soft the scene behind looks
	float veil = 0.0;        // white milkiness
	float sat = 1.22;        // the scene behind, a little richer, like real glass
	float bend = 1.15;       // refraction at the bevel
	float spec = 1.1;        // rim light
	float solid = 0.0;       // how much of the body is an opaque tint
	float clear = 1.0;       // 1 = tint darkens/colours instead of brightening (no haze)
	if (style == 1) { blur = 0.8; veil = 0.06; sat = 1.18; bend = 1.0; spec = 1.0; clear = 0.0; }
	if (style == 2) { blur = 3.4; veil = 0.16; sat = 1.08; bend = 0.35; spec = 0.75; clear = 0.0; }
	if (style == 3) { blur = 5.2; veil = 0.03; sat = 0.92; bend = 0.0; spec = 0.45; solid = 0.66; clear = 0.0; }

	// Screen-pixel anti-aliasing width (1 px on screen, whatever the scale).
	float aw = max(fwidth(d), 0.0001);
	float cover = clamp(0.5 - d / aw, 0.0, 1.0);

	// --- outside the panel: soft shadow + focus halo + contour bloom -----------------
	vec4 outside = vec4(0.0);
	{
		float dd = max(d, 0.0);
		float sd = sd_round_box(p - vec2(0.0, 10.0 + 6.0 * focus), half_panel, r);
		float sh = exp(-max(sd, 0.0) / (16.0 + 10.0 * focus)) * shadow * 0.30;
		float halo = exp(-dd / 10.0) * focus * 0.50 + exp(-dd / 30.0) * focus * 0.16;
		float bloom = (exp(-dd / 3.5) * 0.55 + exp(-dd / 14.0) * 0.22) * glevel * (layered ? 0.35 : 1.0);
		float edge_fade = 1.0 - smoothstep(margin * 0.55, margin * 0.98, dd + 10.0);
		sh *= edge_fade;
		halo *= edge_fade;
		bloom *= edge_fade;
		float a = clamp(sh + halo + bloom, 0.0, 1.0);
		vec3 col = (focus_color.rgb * halo + gcol * bloom * 1.3) / max(a, 0.001);
		outside = vec4(col, a * opacity);
	}
	if (cover <= 0.0) {
		COLOR = outside;
	} else {
	// --- inside the panel ----------------------------------------------------------
	float bev = min(bevel, min(half_panel.x, half_panel.y));
	float h = clamp(-d / bev, 0.0, 1.0);          // 0 at the rim, 1 on the flat top
	float z = sqrt(1.0 - (1.0 - h) * (1.0 - h));   // convex profile
	float slope = 1.0 - z;                          // steep at the rim

	// Displacement in pixels: the bevel bends the scene outward (a lens), the interior
	// magnifies very slightly.
	vec2 disp = n * slope * slope * edge_bend * refraction * bend * (1.0 + 0.6 * press);
	disp -= p * magnify * refraction * bend;
	float k = 0.10 * dispersion * refraction * bend * (1.0 - h);   // colour split only on the bevel
	vec3 col = vec3(0.0);
	if (!layered) {
		col.r = textureLod(screen_tex, SCREEN_UV + disp * spx * (1.0 - k), blur).r;
		col.g = textureLod(screen_tex, SCREEN_UV + disp * spx, blur).g;
		col.b = textureLod(screen_tex, SCREEN_UV + disp * spx * (1.0 + k), blur).b;
	}

	// Glass body.
	float l0 = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l0), col, sat);
	col *= 1.0 - body_dim * 0.97 * smoothstep(0.0, 0.35, h);
	if (clear > 0.5) {
		// Water-clear: the tint only colours the light passing through (multiplies), it
		// never adds a white or pale haze. A slight darkening keeps text readable.
		col *= mix(vec3(1.0), tint.rgb, tint_amount * 0.6);
		col = col * (0.89 + 0.08 * gb) + 0.012 * (1.0 - UV.y) * gb + press * 0.04;
	} else {
		col = mix(col, tint.rgb, tint_amount * (0.6 + 0.4 * gb));
		col = mix(col, vec3(1.0), veil * (0.7 + 0.5 * gb));
		col = col * (0.93 + 0.1 * gb) + (brightness * 0.5 + 0.018 * (1.0 - UV.y)) * (0.6 + 0.6 * gb) + press * 0.05;
	}
	if (solid > 0.0) {
		vec3 slab = mix(vec3(0.10, 0.11, 0.17), tint.rgb * 0.35, 0.35) + 0.06 * gb;
		col = mix(col, slab, solid);
	}

	// Light: two thin bright arcs on opposite corners (top-left key, bottom-right echo),
	// a soft glow just inside them, and a faint hairline all the way round.
	vec2 L = normalize(vec2(-1.0, -1.15));
	float facing = dot(n, L);
	float arc = pow(max(facing, 0.0), 1.7) + pow(max(-facing, 0.0), 1.9) * 0.8;
	float aa_in = cover;
	float line = smoothstep(-2.8 * aw - 0.6, -1.0 * aw, d) * aa_in;   // crisp ~2 px rim
	float inner = (exp(d / 4.0) * 0.6 + exp(d / 12.0) * 0.4) * aa_in;   // light just inside the rim
	col += vec3(1.0) * spec * specular * (line * (0.10 + 0.70 * arc) + inner * 0.26 * arc) * (0.85 + 0.25 * gb);
	// Lens depth: the bevel darkens slightly where it faces away from the light.
	col *= 1.0 - pow(slope, 3.0) * 0.10 * (1.0 - min(arc, 1.0)) * spec;
	// Soft caustic: light gathered along the lower edge.
	col += vec3(1.0) * smoothstep(0.6, 1.0, UV.y) * pow(1.0 - h, 5.0) * 0.07 * spec;

	// Contour glow: crisp line on the rim + soft light spilling inward.
	vec3 gadd = vec3(0.0);
	if (gl > 0.0) {
		float gline = smoothstep(-3.2 * aw, -0.9 * aw, d) * cover;
		// light just inside the line: short, so it never floods a wide row or its text
		float spill = (exp(d / 6.0) * 0.22 + exp(d / 18.0) * 0.04) * (layered ? 0.3 : 1.0);
		gadd = gcol * (gline * 1.25 + spill) * glevel;
		col += gadd;
	}

	// Focus: coloured rim + slightly brighter body.
	col += focus_color.rgb * focus * (pow(slope, 1.6) * 0.6 + 0.04);

	// Travelling diagonal shine (used when a card gains focus).
	if (shine > -0.5) {
		float diag = (UV.x + UV.y * 0.6) - shine * 2.2 + 0.3;
		float band = exp(-diag * diag * 90.0) * 0.20;
		col += vec3(band);
	}

	float aa = cover;
	vec4 inside;
	if (layered) {
		// Glass on glass: a light translucent lens with the same rim light.
		float body = (0.08 + veil * 1.2 + tint_amount * 0.5 * (1.0 - clear) + solid * 0.5 + focus * 0.12) * (0.8 + 0.4 * gb);
		vec3 lc = col + vec3(0.55, 0.6, 0.7) * 0.25 * (1.0 - clear * 0.8);
		if (clear > 0.5) body *= 0.55;
		// glow light adds colour, but only a little opacity (it was turning rows milky white)
		float la = clamp(body + length(col - gadd) * 0.55 + length(gadd) * 0.3, 0.0, 1.0);
		if (smoke > 0.0) {
			// Over a game: deep smoked glass so text stays readable on any scene.
			lc = mix(lc, vec3(0.04, 0.045, 0.085) + col * 0.9, smoke * 0.7);
			la = max(la, smoke);
		}
		inside = vec4(lc, opacity * la);
	} else {
		inside = vec4(col, opacity);
	}
	// Blend the anti-aliased edge over the shadow/glow outside it.
	float ia = inside.a * aa;
	float oa = outside.a * (1.0 - ia);
	float ta = ia + oa;
	COLOR = vec4((inside.rgb * ia + outside.rgb * oa) / max(ta, 0.0001), ta);
	}
}
