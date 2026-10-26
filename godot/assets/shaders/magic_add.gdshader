shader_type canvas_item;
render_mode blend_add;

// GlowFilter color is carried in glow, already split out of any parent modulate.
uniform vec4 glow : source_color = vec4(0.0, 1.0, 0.0, 0.35);
uniform bool solid = false;

void fragment() {
	float cover = 1.0;
	if (!solid) {
		cover = texture(TEXTURE, UV).a;
	}
	COLOR = vec4(glow.rgb, glow.a * cover);
}
