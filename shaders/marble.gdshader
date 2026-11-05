// marble.gdshader
// Purpose: a statue's stone look. Turns the vase-style art into flat marble white
// with subtle veining and a slightly darker rim; with `cracked` on it also draws
// dark fracture lines all over (the CRACKED statue state).
// Texture reads: 1 for the pixel + 4 for the rim (rim_px > 0), 5 at most.
shader_type canvas_item;

#include "res://shaders/noise.gdshaderinc"

// The vertex color (it carries the node's modulate, e.g. the hurt flicker). Saved
// here because in fragment() COLOR already has the texture multiplied in.
varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

uniform vec4 marble_color : source_color = vec4(0.949, 0.937, 0.910, 1.0);
uniform vec4 vein_color : source_color = vec4(0.55, 0.52, 0.49, 1.0);
uniform vec4 rim_color : source_color = vec4(0.72, 0.69, 0.65, 1.0);
uniform vec4 crack_color : source_color = vec4(0.102, 0.078, 0.063, 1.0);
// Veining: blob size (bigger = finer) and strength (0 = flat white).
uniform float vein_scale = 7.0;
uniform float vein_strength = 0.12;
// Rim width in texture pixels; 0 turns the rim (and its 4 extra reads) off.
uniform float rim_px = 3.0;
// CRACKED state: on/off, crack cell size (bigger = more cracks) and line width.
uniform bool cracked = false;
uniform float crack_scale = 5.0;
uniform float crack_width = 0.05;
// Noise layers (Balance.SHADER_NOISE_OCTAVES); 1 is cheapest.
uniform int octaves = 2;

// Distance to the nearest Voronoi cell border: small values lie on a crack line.
// Checks the 3x3 neighbouring cells for the closest and second-closest seed point.
float crack_distance(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			float d = length(g + mp_hash2(cell + g) - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return d2 - d1;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = mp_to_marble(c.rgb, marble_color.rgb, vein_color.rgb);

	// Veining: soft streaks, stretched sideways so they read as stone grain.
	float vein = mp_fbm(UV * vec2(vein_scale * 0.5, vein_scale), octaves);
	rgb = mix(rgb, vein_color.rgb, smoothstep(0.55, 0.8, vein) * vein_strength * 4.0);

	// Rim: a pixel near the silhouette edge (a neighbour is transparent) is darker.
	if (rim_px > 0.0) {
		vec2 o = TEXTURE_PIXEL_SIZE * rim_px;
		float inner = min(min(texture(TEXTURE, UV + vec2(o.x, 0.0)).a, texture(TEXTURE, UV - vec2(o.x, 0.0)).a),
				min(texture(TEXTURE, UV + vec2(0.0, o.y)).a, texture(TEXTURE, UV - vec2(0.0, o.y)).a));
		rgb = mix(rgb, rim_color.rgb, 1.0 - inner);
	}

	if (cracked) {
		float line = 1.0 - smoothstep(crack_width * 0.5, crack_width, crack_distance(UV * crack_scale));
		rgb = mix(rgb, crack_color.rgb, line);
	}
	COLOR = vec4(rgb, c.a) * vertex_color;
}
