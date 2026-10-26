shader_type canvas_item;

// Grafon.drawSats: the frozen frame under BlurFilter(3, 3, 1), one 3 px box pass.
uniform sampler2D screen : hint_screen_texture, filter_linear;

void fragment() {
	vec4 acc = vec4(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			acc += texture(screen, SCREEN_UV + vec2(float(x), float(y)) * SCREEN_PIXEL_SIZE);
		}
	}
	COLOR = vec4((acc / 9.0).rgb, 1.0);
}
