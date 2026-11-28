// FORGE OS — shared rain pieces for the rain wallpapers (Rain on Tiles, Night Rain):
// raindrop rings spreading on puddles, falling rain streaks and splashes.

// Rings from raindrops landing on water, in floor coordinates. Returns (height slope x, y,
// ring brightness). Each cell gets a drop every so often at a random spot.
vec3 r_ripples(vec2 fc, float tt, float cell, float rate) {
	vec2 q = fc / cell;
	vec2 id0 = floor(q);
	vec3 acc = vec3(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 id = id0 + vec2(float(i), float(j));
			vec2 h = hash22(id);
			float phase = fract(tt * rate * (0.7 + 0.6 * h.x) + h.y);
			vec2 c = id + 0.15 + 0.7 * hash22(id + floor(tt * rate * (0.7 + 0.6 * h.x) + h.y) * 1.7);
			vec2 d = q - c;
			float dist = length(d);
			float radius = phase * 1.1;
			float fade = (1.0 - phase) * (1.0 - phase);
			float w = 0.035 + 0.035 * phase;
			// two rings, like real drops
			float ring = exp(-pow((dist - radius) / w, 2.0)) - 0.6 * exp(-pow((dist - radius * 0.6) / w, 2.0));
			vec2 dir = dist > 0.0001 ? d / dist : vec2(0.0);
			acc.xy += dir * ring * fade;
			acc.z += abs(ring) * fade;
		}
	}
	return acc;
}

// Falling rain: thin slanted streaks in screen space, a few layers deep.
float r_streaks(vec2 p, float tt) {
	float s = 0.0;
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		float scale = 26.0 + fk * 22.0;
		vec2 q = vec2(p.x + p.y * 0.12, p.y) * vec2(scale, scale * 0.08);
		q.y -= tt * (5.0 + fk * 2.5);
		vec2 id = floor(q);
		vec2 f = fract(q);
		float h = hash12(id + fk * 7.0);
		float x = 0.2 + 0.6 * hash12(id.xx + fk * 3.0);
		float line = smoothstep(0.06, 0.0, abs(f.x - x)) * smoothstep(0.0, 0.3, f.y) * smoothstep(1.0, 0.6, f.y);
		s += line * step(0.72, h) * (0.5 - fk * 0.12);
	}
	return s;
}
