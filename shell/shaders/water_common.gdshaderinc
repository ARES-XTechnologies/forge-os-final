// FORGE OS — shared underwater pieces for the water wallpapers (Sunlit Shallows, Coral Light,
// The Deep): sunlight caustics, god rays from the surface, the rippling surface seen from
// below, a sandy floor in perspective, rising bubbles and drifting particles.

// Caustic light net (sharp bright lines, like sunlight on a pool floor).
float w_caustic(vec2 uv, float tt) {
	vec2 p = mod(uv * 6.2831, 6.2831) - 250.0;
	vec2 i = p;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 5; n++) {
		float tn = tt * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tn - i.x) + sin(tn + i.y), sin(tn - i.y) + cos(tn + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tn) / inten), p.y / (cos(i.y + tn) / inten)));
	}
	c /= 5.0;
	c = 1.17 - pow(c, 1.4);
	return pow(abs(c), 8.0);
}

// God rays fanning down from a point above the screen.
float w_rays(vec2 p, vec2 src, float spread, float tt) {
	vec2 d = p - src;
	float ang = atan(d.x, d.y);
	float r = 0.0;
	r += pow(noise(vec2(ang * 9.0 + tt * 0.10, tt * 0.05)), 2.0);
	r += pow(noise(vec2(ang * 23.0 - tt * 0.07, 7.0 + tt * 0.03)), 3.0) * 0.8;
	r += pow(noise(vec2(ang * 47.0 + tt * 0.05, 13.0)), 4.0) * 0.6;
	float cone = exp(-pow(ang / spread, 2.0));
	float dist = length(d);
	return r * cone * exp(-dist * 0.9);
}

// The water surface seen from below: bright, wobbling light patches near the top.
float w_surface(vec2 p, float tt) {
	vec2 q = vec2(p.x * 2.2, p.y * 7.0);
	float n = fbm(q + vec2(tt * 0.15, tt * 0.07)) + 0.5 * fbm(q * 2.3 - vec2(tt * 0.22, 0.0));
	return smoothstep(0.55, 1.15, n);
}

// Rising bubbles; returns brightness (rim + highlight).
float w_bubbles(vec2 p, float scale, float speed, float tt, float density) {
	vec2 q = p * scale;
	q.y += tt * speed;
	vec2 id = floor(q);
	vec2 f = fract(q) - 0.5;
	float h = hash12(id);
	if (h > density) return 0.0;
	vec2 h2 = hash22(id + 3.1);
	vec2 c = vec2((h2.x - 0.5) * 0.6 + 0.12 * sin(tt * 1.7 + h * 30.0), (h2.y - 0.5) * 0.5);
	float r = 0.06 + 0.12 * hash12(id + 9.0);
	float d = length(f - c);
	float rim = smoothstep(r, r * 0.82, d) - smoothstep(r * 0.82, r * 0.55, d) * 0.85;
	float hi = smoothstep(r * 0.35, 0.0, length(f - c - vec2(-r * 0.35, -r * 0.35)));
	return clamp(rim * 0.7 + hi * 0.9, 0.0, 1.0);
}

// Tiny suspended particles (plankton / sand) catching the light.
float w_motes(vec2 p, float scale, float tt) {
	vec2 q = p * scale + vec2(tt * 0.05, -tt * 0.03);
	vec2 id = floor(q);
	vec2 f = fract(q);
	vec2 h = hash22(id);
	float d = length(f - h);
	return smoothstep(0.035, 0.0, d) * step(0.6, hash12(id + 5.0)) * (0.5 + 0.5 * sin(tt * 2.0 + h.x * 20.0));
}

// Sandy floor in perspective below `horizon` (screen y). Returns floor coords and depth.
vec3 w_floor(vec2 p, float horizon, float cam) {
	float dy = p.y - horizon;
	if (dy <= 0.0) return vec3(0.0, 0.0, -1.0);
	float z = cam / dy;
	return vec3(p.x * z, z, z);
}
