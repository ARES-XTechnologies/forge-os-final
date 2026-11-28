// FORGE OS — shared night-sky pieces for the star wallpapers (Starfall, Rose Horizon, Night
// Canopy, Deep Field, Afterglow, Mirror Lake, Violet Peaks): dense twinkling star fields, a
// Milky Way band with glowing core and dark dust lanes, and black land silhouettes (hills,
// mountains, trees).

// One layer of stars. density 0..1 (share of cells with a star), size in cell units.
vec3 s_layer(vec2 p, float scale, float density, float size, float tt, float seed) {
	vec2 g = p * scale + seed * 13.0;
	vec2 id = floor(g);
	vec2 h = hash22(id + seed);
	if (hash12(id + seed * 3.7) > density) return vec3(0.0);
	float d = length(fract(g) - (0.15 + 0.7 * h));
	float b = pow(hash12(id + seed * 9.1), 3.0) * 0.8 + 0.2;          // a few bright, many faint
	float tw = 0.65 + 0.35 * sin(tt * (1.2 + h.x * 3.5) + h.y * 60.0);
	float core = smoothstep(size, 0.0, d);
	float glow = exp(-d / (size * 1.8)) * 0.25 * b;
	// star colours: mostly white, some blue-white, a few warm
	float c = hash12(id + seed * 5.3);
	vec3 col = c < 0.6 ? vec3(1.0) : (c < 0.85 ? vec3(0.75, 0.85, 1.0) : vec3(1.0, 0.85, 0.7));
	return col * (core + glow) * b * tw;
}

// All the stars: several layers from dust-fine to bright. `boost` adds more inside the band.
vec3 s_stars(vec2 p, float tt, float boost) {
	vec3 s = vec3(0.0);
	s += s_layer(p, 260.0, 0.45 + boost * 0.4, 0.16, tt, 1.0) * 0.55;
	s += s_layer(p, 150.0, 0.35 + boost * 0.3, 0.14, tt, 2.0) * 0.8;
	s += s_layer(p, 80.0, 0.22 + boost * 0.2, 0.11, tt, 3.0) * 1.1;
	s += s_layer(p, 38.0, 0.18, 0.08, tt, 4.0) * 1.6;
	s += s_layer(p, 18.0, 0.10, 0.06, tt, 5.0) * 2.2;
	return s;
}

// The Milky Way: returns (band brightness, dust darkening) for a band through `centre` at
// angle `ang` (radians) with half-width `w`.
vec2 s_milky(vec2 p, vec2 centre, float ang, float w) {
	mat2 r = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	vec2 q = r * (p - centre);
	float band = exp(-pow(q.y / w, 2.0));
	float wob = (fbm(q * vec2(1.5, 3.0)) - 0.5) * w * 0.9;
	band = exp(-pow((q.y + wob) / w, 2.0));
	float glow = band * (0.45 + 0.75 * fbm(q * vec2(2.2, 5.0) + 3.0));
	float coreg = exp(-pow(q.x / 0.55, 2.0)) * band;                 // brighter towards the core
	float dust = smoothstep(0.50, 0.72, fbm(q * vec2(3.5, 9.0) + 11.0)) * exp(-pow(q.y / (w * 0.45), 2.0));
	return vec2(glow * (0.7 + coreg * 0.9), dust);
}

// Ridge-noise silhouette height (mountains / hills).
float s_ridge(float x, float seed, float rough) {
	float h = 0.0;
	float a = 0.5;
	float f = 1.0;
	for (int i = 0; i < 5; i++) {
		float n = noise(vec2(x * f + seed, seed));
		h += a * mix(n, 1.0 - abs(n * 2.0 - 1.0), rough);
		f *= 2.07;
		a *= 0.5;
	}
	return h;
}

// Tree line: rounded crowns and pointed pines, height above a baseline at x.
float s_trees(float x, float seed, float pine) {
	float cell = floor(x * 18.0);
	float fx = fract(x * 18.0) - 0.5;
	float h = 0.0;
	for (int k = -1; k <= 1; k++) {
		float c = cell + float(k);
		float hh = hash12(vec2(c, seed));
		if (hh < 0.35) continue;
		float lx = fx - float(k) - (hash12(vec2(c, seed + 3.0)) - 0.5) * 0.6;
		float height = 0.03 + 0.07 * hh;
		float crown = mix(sqrt(max(0.0, 1.0 - pow(lx / 0.75, 2.0))), max(0.0, 1.0 - abs(lx) * 2.6), pine);
		h = max(h, crown * height);
	}
	return h;
}

// Natural tree silhouettes. x: horizontal position, up: height above the ground line (positive
// upward), dens: trees per unit, pine: 0 = broadleaf, 1 = conifer, hmul: height multiplier
// (vary with position for taller trees near the frame edges). Returns 1 inside a tree.
float s_forest(float x, float up, float dens, float seed, float pine, float hmul) {
	if (up < 0.0) return 1.0;
	float X = x * dens;
	float Y = up * dens;
	float cell = floor(X);
	float inside = 0.0;
	for (int k = -2; k <= 2; k++) {
		float c = cell + float(k);
		float hh = hash12(vec2(c, seed));
		if (hh < 0.18) continue;
		float lx = X - c - 0.5 - (hash12(vec2(c, seed + 3.0)) - 0.5) * 0.7;
		float H = (1.4 + 2.6 * hh * hh) * hmul * mix(1.0, 1.35, pine);
		float y = Y / H;
		if (y > 1.0) continue;
		float w;
		if (pine > 0.5) {
			// conifer: tiers of drooping branches that taper to a spire
			float tiers = 7.0 + floor(hh * 5.0);
			float tier = fract(y * tiers + hash12(vec2(c, seed + 7.0)));
			w = (1.0 - y) * H * 0.26 * (0.55 + 0.45 * tier);
			w += (noise(vec2(c * 13.0, Y * 6.0)) - 0.5) * 0.10 * (1.0 - y);
			w = min(max(w, 0.04 * step(y, 0.97)), 2.4);
		} else {
			// broadleaf: lumpy rounded crown on a short trunk
			float cy = (y - 0.62) / 0.40;
			float ang = atan(cy, lx / (H * 0.42));
			float r = 1.0 + (fbm(vec2(ang * 2.0 + c * 7.1, c)) - 0.5) * 0.55;
			w = min(sqrt(max(0.0, 1.0 - cy * cy / (r * r))) * H * 0.42 * r, 2.4);
			w = max(w, 0.07 * step(y, 0.3));
		}
		inside = max(inside, step(abs(lx), w));
	}
	// low undergrowth so the ground line is never perfectly straight
	inside = max(inside, step(Y, 0.18 + noise(vec2(X * 3.0, seed)) * 0.35));
	return inside;
}
