// petrify.gdshader
// Purpose: the gaze turning a body to stone. Marble white spreads outward from
// `origin` (the frame-local UV where the gaze touched) as `progress` goes 0 -> 1,
// through a noise-distorted edge with a thin bright rim at the front.
// At progress 0 the sprite is unchanged; at 1 it is fully marble.
// One texture read (the sprite itself); the noise is pure math. WebGL2 safe.
shader_type canvas_item;

#include "res://shaders/noise.gdshaderinc"

// The vertex color (it carries the node's modulate, e.g. the hurt flicker). Saved
// here because in fragment() COLOR already has the texture multiplied in.
varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

// Where the stone starts, in the sprite frame's UV (0,0 top-left, 1,1 bottom-right).
uniform vec2 origin = vec2(0.5, 0.2);
// How far the stone has spread: 0 = none, 1 = the whole figure.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Colors are set from Balance by SpriteKit (these defaults are the same values).
uniform vec4 marble_color : source_color = vec4(0.949, 0.937, 0.910, 1.0);
uniform vec4 vein_color : source_color = vec4(0.55, 0.52, 0.49, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Width of the bright front, in UV units.
uniform float edge_width = 0.05;
// Size of the noise blobs (bigger = finer) and how much they bend the front.
uniform float noise_scale = 5.0;
uniform float noise_amount = 0.3;
// Noise layers (Balance.SHADER_NOISE_OCTAVES); 1 is cheapest.
uniform int octaves = 2;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (progress > 0.0) {
		// Distance from the gaze point, pushed in and out by the noise so the front is ragged.
		float n = mp_fbm(UV * noise_scale, octaves) - 0.5;
		float d = distance(UV, origin) + n * noise_amount;
		// The front's position. At progress 1 it is past the farthest corner plus the
		// noise, so everything is stone.
		float front = progress * (1.5 + noise_amount);
		vec3 stone = mp_to_marble(c.rgb, marble_color.rgb, vein_color.rgb);
		float is_stone = 1.0 - smoothstep(front - 0.01, front, d);
		// The thin bright band just behind the front (fades out once fully stone).
		float band = smoothstep(front - edge_width, front - edge_width * 0.5, d) * is_stone;
		band *= 1.0 - step(1.0, progress);
		vec3 rgb = mix(c.rgb, stone, is_stone);
		c.rgb = mix(rgb, edge_color.rgb, band);
	}
	COLOR = c * vertex_color;
}
