// haze.gdshader - atmospheric haze on a level's background painting.
// The paintings use the same black lines as the characters and are drawn much larger,
// so they competed with the action. Fading them toward a sky colour makes them read
// as far away (aerial perspective), which also makes the bigger scale look intended.
// One texture read; set on the background Sprite2D by level_base.gd.
shader_type canvas_item;

uniform vec4 haze_color : source_color = vec4(0.85, 0.6, 0.47, 1.0);
// 0 = the painting as it is, 1 = flat haze colour.
uniform float amount : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	// In a canvas_item fragment(), COLOR already holds the texture pixel times the
	// node's modulate, so no extra texture() read is needed.
	vec4 c = COLOR;
	COLOR = vec4(mix(c.rgb, haze_color.rgb, amount), c.a);
}
