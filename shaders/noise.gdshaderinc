// noise.gdshaderinc
// Purpose: cheap procedural noise shared by the petrify and marble shaders.
// Everything is math on the UV (a hash, not a texture), so it costs no extra
// texture reads and runs on WebGL2 / the Compatibility renderer.

// A pseudo-random number in 0..1 for each integer grid cell p ("hash").
float mp_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// A random 2D point inside cell p (used for the Voronoi cracks).
vec2 mp_hash2(vec2 p) {
	return vec2(mp_hash(p), mp_hash(p + 17.31));
}

// Value noise: random values on a grid, blended smoothly in between. 0..1.
float mp_value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);  // smoothstep curve, hides the grid
	float a = mp_hash(i);
	float b = mp_hash(i + vec2(1.0, 0.0));
	float c = mp_hash(i + vec2(0.0, 1.0));
	float d = mp_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal noise: `octaves` layers of value noise, each twice as fine and half as
// strong. More octaves = more detail but more math per pixel (max 4).
float mp_fbm(vec2 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= octaves) {
			break;
		}
		sum += mp_value_noise(p) * amp;
		norm += amp;
		p *= 2.0;
		amp *= 0.5;
	}
	return sum / max(norm, 0.0001);
}

// Turn vase art into stone: the black body becomes marble white, the terracotta
// incised lines become grey veins, so the figure reads as a carved statue.
vec3 mp_to_marble(vec3 rgb, vec3 marble, vec3 vein) {
	float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
	return mix(marble, vein, smoothstep(0.2, 0.45, lum));
}
