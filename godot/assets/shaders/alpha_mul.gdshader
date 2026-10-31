shader_type canvas_item;
render_mode blend_mul, unshaded;

// Flash multiply: transparent pixels and the modulate fade leave the backdrop unchanged.
void fragment() {
	COLOR = vec4(mix(vec3(1.0), COLOR.rgb, COLOR.a), 1.0);
}
