// desaturate.gdshader
// Purpose: full-screen veil that fades the world to grayscale (Medusa turning to
// stone). `amount` 0 = untouched, 1 = fully gray. Compatibility renderer safe.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float gray = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c, vec3(gray), amount), 1.0);
}
