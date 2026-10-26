shader_type canvas_item;
render_mode unshaded;

// CanvasGroup material: Flash GlowFilter on the composited group, quality 1
// (one box pass blur px wide), outer, no knockout. blur is in original stage
// pixels (1080 tall), converted to screen pixels here.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 0.6, 1.0);
uniform float blur = 4.0;
uniform float strength = 2.9;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	float width = max(blur / (1080.0 * SCREEN_PIXEL_SIZE.y), 1.0);
	int n = clamp(int(round(width)), 1, 12);
	float half_n = (float(n) - 1.0) * 0.5;
	float acc = 0.0;
	for (int y = 0; y < n; y++) {
		for (int x = 0; x < n; x++) {
			vec2 at = SCREEN_UV + (vec2(float(x), float(y)) - half_n) * SCREEN_PIXEL_SIZE;
			acc += textureLod(screen_texture, at, 0.0).a;
		}
	}
	float g = clamp(acc / float(n * n) * strength, 0.0, 1.0) * glow_color.a;
	float a = c.a + g * (1.0 - c.a);
	vec3 rgb = c.rgb + glow_color.rgb * g * (1.0 - c.a);
	COLOR *= vec4(a > 0.0001 ? rgb / a : vec3(0.0), a);
}
