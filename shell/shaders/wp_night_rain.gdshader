// FORGE OS wallpaper — Night Rain: a wet asphalt road at night. Street lights and neon from
// the city ahead stretch into long shimmering reflections in the puddles, raindrops ring the
// water, the lane markings gleam and rain falls through the light.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/wallpaper_common.gdshaderinc"
#include "res://shaders/rain_common.gdshaderinc"

const float HORIZON = -0.18;

// The city ahead: dark sky, skyline, and blurred lights (warm street lamps, cyan/pink neon).
vec3 city(vec2 p, float tt) {
	vec3 c = mix(vec3(0.05, 0.05, 0.09), vec3(0.015, 0.015, 0.03), smoothstep(HORIZON, -0.6, p.y));
	c += vec3(0.25, 0.12, 0.22) * exp(-abs(p.y - HORIZON) * 9.0) * 0.6;   // city glow
	// skyline: a far layer of small blocks and a near layer of taller towers, both full of
	// lit interiors — mostly warm, some cool white/blue offices, and whole lit floors
	for (int layer = 0; layer < 2; layer++) {
		float fl = float(layer);
		float cols = mix(14.0, 8.0, fl);
		float bx = floor(p.x * cols + fl * 0.37);
		float bh = hash12(vec2(bx, 2.0 + fl * 11.0));
		float hgt = HORIZON - 0.02 - (0.06 + 0.16 * bh * bh + fl * 0.05) * smoothstep(1.4, 0.0, abs(p.x));
		float inb = step(hgt, p.y) * step(p.y, HORIZON + 0.005);
		float lx = fract(p.x * cols + fl * 0.37);
		inb *= step(0.04, lx) * step(lx, 0.96 - 0.1 * hash12(vec2(bx, 9.0)));   // gaps between towers
		if (inb > 0.5) {
			vec3 body = mix(vec3(0.020, 0.020, 0.032), vec3(0.012, 0.012, 0.02), fl);
			// window grid in screen space; rows are floors
			vec2 wq = vec2(p.x * mix(230.0, 160.0, fl), (p.y - HORIZON) * mix(260.0, 190.0, fl));
			vec2 wc = floor(wq);
			vec2 wf = fract(wq);
			float frame = step(0.22, wf.x) * step(wf.x, 0.82) * step(0.25, wf.y) * step(wf.y, 0.80);
			float floorlit = step(0.80, hash12(vec2(wc.y, bx + fl * 50.0)));          // fully lit floors
			float tone = hash12(vec2(bx * 3.1, wc.y * 0.13 + fl));                    // per-building mood
			float lit = max(step(0.42 + 0.25 * tone, hash12(wc + fl * 31.0)), floorlit);
			float cool = step(0.72, hash12(vec2(bx, floor(wc.y / 4.0) + 7.0)));       // office floors
			vec3 warm = mix(vec3(1.0, 0.70, 0.38), vec3(1.0, 0.86, 0.60), hash12(wc * 1.7));
			vec3 cold = mix(vec3(0.75, 0.88, 1.0), vec3(0.45, 0.70, 1.0), hash12(wc * 2.3));
			vec3 wcol = mix(warm, cold, cool) * (0.55 + 0.45 * hash12(wc + 3.0));
			float flick = 1.0 - step(0.996, hash12(wc + floor(tt * 0.5))) * 0.8;  // the odd light switching
			body += wcol * frame * lit * flick * mix(0.55, 0.75, fl);
			body += wcol * lit * floorlit * 0.06;                                   // light spill on lit floors
			c = body;
		}
	}
	// soft glow of all those windows into the haze above the skyline
	c += vec3(0.35, 0.22, 0.14) * exp(-abs(p.y - (HORIZON - 0.12)) * 10.0) * 0.12 * smoothstep(1.3, 0.0, abs(p.x));
	// lights
	vec3 L = vec3(0.0);
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		vec2 h = hash22(vec2(fi, 4.0));
		vec2 lp = vec2((h.x - 0.5) * 2.6, HORIZON - 0.02 - h.y * 0.12);
		vec3 lc = i % 3 == 0 ? vec3(1.0, 0.55, 0.25) : (i % 3 == 1 ? vec3(0.25, 0.85, 1.0) : vec3(1.0, 0.3, 0.6));
		float flick = 0.85 + 0.15 * sin(tt * (1.0 + h.x) + fi);
		float d = length((p - lp) * vec2(1.0, 1.3));
		L += lc * (exp(-d * 55.0) * 1.4 + exp(-d * 9.0) * 0.18) * flick;
	}
	// street lamps lining the road, getting closer toward the sides of the screen
	for (int k = 0; k < 6; k++) {
		float fk = float(k);
		float zz = 1.0 + fk * 1.6;
		for (int sd = -1; sd <= 1; sd += 2) {
			vec2 lp = vec2(float(sd) * (0.9 / zz + 0.06), HORIZON - 0.28 / zz);
			float d = length((p - lp) * vec2(1.0, 1.2)) * zz;
			L += vec3(1.0, 0.62, 0.30) * (exp(-d * 40.0) * 1.6 + exp(-d * 6.0) * 0.10);
		}
	}
	return c + L;
}

void fragment() {
	vec2 p = wp_coords(UV) + parallax * 0.4;
	float tt = t * 0.6 + 2.0;
	vec3 col;
	if (p.y < HORIZON) {
		col = city(p, tt);
	} else {
		float dy = p.y - HORIZON;
		float z = 0.35 / dy;
		vec2 fc = vec2(p.x * z, z);
		// asphalt: dark, grainy, with fine stones
		float grain = fbm(fc * 18.0) * 0.6 + hash12(floor(fc * vec2(260.0, 260.0))) * 0.4;
		vec3 asphalt = vec3(0.045, 0.045, 0.05) * (0.75 + 0.5 * grain);
		// lane markings: dashed centre line, solid edge lines
		float dash = step(0.5, fract(fc.y * 0.35)) * smoothstep(0.06, 0.04, abs(fc.x));
		float edge = smoothstep(0.07, 0.05, abs(abs(fc.x) - 2.2));
		asphalt = mix(asphalt, vec3(0.55, 0.53, 0.45), max(dash, edge) * 0.8 * exp(-z * 0.05));
		// puddles (big, irregular), and wet everywhere
		float pud = smoothstep(0.50, 0.56, fbm(fc * vec2(0.55, 0.25) + vec2(4.0, 2.0)));
		vec3 rip = r_ripples(fc * vec2(2.6, 1.4), tt, 0.35, 0.9);
		// mirror the city above the horizon, wobbling with the rings, blurrier on plain wet road
		float rough = mix(0.06, 0.008, pud);
		vec2 rp = vec2(p.x, HORIZON - dy * mix(0.45, 0.8, pud));   // wet roads stretch reflections into long streaks
		rp.x += (noise(vec2(p.x * 40.0, p.y * 4.0)) - 0.5) * rough * 2.0 + rip.x * mix(0.004, 0.03, pud);
		rp.y += rip.y * mix(0.002, 0.02, pud);
		// long vertical streaks of light: blur the reflection downward
		vec3 refl = city(rp, tt) * 0.55 + city(rp + vec2(0.0, rough * 1.5), tt) * 0.3 + city(rp - vec2(0.0, rough * 3.0), tt) * 0.15;
		float fres = mix(0.35, 0.95, smoothstep(0.6, 0.0, dy));
		col = mix(asphalt + refl * fres * 0.45, refl * fres + asphalt * 0.25, pud);
		col += vec3(0.8, 0.85, 1.0) * rip.z * mix(0.008, 0.22, pud) * (0.3 + length(refl));
		col = mix(col, vec3(0.04, 0.04, 0.07), smoothstep(6.0, 30.0, z) * 0.6);
		col += vec3(0.10, 0.06, 0.05) * smoothstep(0.9, 0.0, abs(p.x)) * 0.25;   // ambient light on the road
	}
	// rain falling through the light
	col += vec3(0.75, 0.82, 0.95) * r_streaks(p, tt) * 0.20;
	col = mix(col, col * mix(vec3(1.0), game_tint.rgb * 1.3, 0.3), game_tint_amount * 0.3);
	col *= intensity;
	COLOR = vec4(wp_finish(col, UV), 1.0);
}
