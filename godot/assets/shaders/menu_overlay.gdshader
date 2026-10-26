shader_type canvas_item;

// Flash blendMode "overlay" (groza's sky glow).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 d = texture(screen_tex, SCREEN_UV).rgb;
	vec3 lo = 2.0 * c.rgb * d;
	vec3 hi = vec3(1.0) - 2.0 * (vec3(1.0) - c.rgb) * (vec3(1.0) - d);
	COLOR = vec4(mix(lo, hi, step(0.5, d)), c.a * COLOR.a);
}
