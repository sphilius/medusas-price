// desaturate.gdshader
// Purpose: full-screen veil for Medusa's death. The world fades to gray and then on
// toward marble white, as if the whole screen were turning to stone.
// `amount` 0 = untouched, 1 = fully stone. One screen read. Compatibility renderer safe.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// Marble white and how far the gray is pushed toward it (set from Balance).
uniform vec4 marble_color : source_color = vec4(0.949, 0.937, 0.910, 1.0);
uniform float marble_mix : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float gray = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 stone = mix(vec3(gray), marble_color.rgb, marble_mix);
	COLOR = vec4(mix(c, stone, amount), 1.0);
}
