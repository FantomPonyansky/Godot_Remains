shader_type canvas_item;

// Sats.ct: ColorTransform(1, 1, 1, 1, 0, 100, 0, 0) on the unit snapshot.
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(min(c.rgb + vec3(0.0, 100.0 / 255.0, 0.0), vec3(1.0)), c.a);
}
