// vignette.gdshader - a dark edge around the screen that closes in as the portrait ages.
// level_base.gd sets `inner` (where the dark begins, 0 = centre, 1 = corner) and
// `strength` (how dark the corners get) from the portrait stage. No texture reads.
shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.102, 0.078, 0.063, 1.0);
uniform float inner = 0.75;
uniform float strength = 0.25;

void fragment() {
	// Distance from the screen centre, stretched so the corners are 1.
	float d = length((SCREEN_UV - vec2(0.5)) * 2.0) / 1.4142;
	COLOR = vec4(color.rgb, smoothstep(inner, 1.0, d) * strength);
}
