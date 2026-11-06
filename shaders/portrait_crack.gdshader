// portrait_crack.gdshader - the portrait's damage, drawn INTO the painting.
// Replaces the old white overlay lines. Two layers, like a real aging oil painting:
//   1. Craquelure: fine dark cracks that grow in from the rim of the shield as this
//      stage's cracks add up (`amount` 0..1 = cracks so far / cracks for this stage).
//      Along each crack the paint flakes a little (a pale speck beside the dark line).
//   2. Wear: varnish darkening and grime that deepen with the stage (`wear` 0..1).
// No extra texture reads beyond the painting itself (Voronoi and noise use hashes).
shader_type canvas_item;

#include "res://shaders/noise.gdshaderinc"

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float wear : hint_range(0.0, 1.0) = 0.0;
// Crack cell size (bigger = more, smaller cracks) and line width (in cell units).
uniform float crack_scale = 9.0;
uniform float crack_width = 0.035;
uniform vec4 crack_color : source_color = vec4(0.08, 0.06, 0.05, 1.0);
uniform vec4 flake_color : source_color = vec4(0.93, 0.88, 0.78, 1.0);
uniform vec4 varnish_color : source_color = vec4(0.35, 0.22, 0.1, 1.0);

// Distance to the nearest Voronoi cell border (small = on a crack).
float crack_distance(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			float d = length(g + mp_hash2(cell + g) - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

void fragment() {
	vec4 c = COLOR;  // the painting pixel (texture x modulate)
	vec3 rgb = c.rgb;
	// Distance from the centre of the round shield, 0 (middle) to 1 (rim).
	float r = length(UV - vec2(0.5)) * 2.0;
	// Wobbly domain so the cracks are not straight-edged cells.
	vec2 p = UV * crack_scale + vec2(mp_fbm(UV * 4.0, 2), mp_fbm(UV * 4.0 + 7.0, 2)) * 0.8;
	float d = crack_distance(p);
	// Cracks reach in from the rim: with amount 0 none, with amount 1 most of the way.
	float reach = 1.0 - amount * 0.85;
	float mask = smoothstep(reach - 0.05, reach + 0.15, r) * step(0.001, amount);
	float line = 1.0 - smoothstep(crack_width * 0.4, crack_width, d);
	float flake = (1.0 - smoothstep(crack_width, crack_width * 2.2, d)) - line;
	rgb = mix(rgb, flake_color.rgb, clamp(flake, 0.0, 1.0) * mask * 0.35);
	rgb = mix(rgb, crack_color.rgb, line * mask * 0.9);
	// Wear: darker varnish toward the rim, and patchy grime, both growing with `wear`.
	float grime = mp_fbm(UV * 6.0 + 3.0, 2);
	rgb = mix(rgb, varnish_color.rgb, wear * (0.25 * r + 0.2 * smoothstep(0.5, 0.8, grime)));
	COLOR = vec4(rgb, c.a);
}
