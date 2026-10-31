shader_type canvas_item;
render_mode blend_premul_alpha;

// Flash GlowFilter (outer, not knocked out) on a rig part: the part over a glow of `glow_color`
// from its blurred alpha times `strength`, then the colour transform, then the part's blend
// (screen when `screen`). blur_x / blur_y are Flash widths in world pixels along the world axes;
// quality 3 (three box passes) is drawn as a Gaussian of sigma width / 2.
uniform vec4 ct_multiply = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 ct_offset = vec4(0.0, 0.0, 0.0, 0.0);
uniform float ct_brightness = 1.0;
uniform float blur_x = 4.0;
uniform float blur_y = 4.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform float strength = 1.0;
uniform bool screen = false;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

varying vec4 v_mod;
varying vec2 v_ex;
varying vec2 v_ey;

void vertex() {
	v_mod = COLOR;
	mat2 inv = inverse(mat2(MODEL_MATRIX[0].xy, MODEL_MATRIX[1].xy));
	v_ex = inv * vec2(1.0, 0.0) * TEXTURE_PIXEL_SIZE;
	v_ey = inv * vec2(0.0, 1.0) * TEXTURE_PIXEL_SIZE;
	vec2 grow_uv = abs(v_ex) * (blur_x * 1.5 + 1.0) + abs(v_ey) * (blur_y * 1.5 + 1.0);
	vec2 side = UV * 2.0 - 1.0;
	VERTEX += side * grow_uv / TEXTURE_PIXEL_SIZE;
	UV += side * grow_uv;
}

void fragment() {
	float sx = max(blur_x, 1.0) * 0.5;
	float sy = max(blur_y, 1.0) * 0.5;
	float acc = 0.0;
	float wsum = 0.0;
	for (int j = -8; j <= 8; j++) {
		float wy = exp(-float(j * j) / (2.0 * sy * sy));
		for (int i = -8; i <= 8; i++) {
			float w = exp(-float(i * i) / (2.0 * sx * sx)) * wy;
			wsum += w;
			vec2 uv = UV + v_ex * float(i) + v_ey * float(j);
			if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
				continue;
			}
			acc += texture(TEXTURE, uv).a * w;
		}
	}
	float ga = clamp(acc / max(wsum, 1e-5) * strength, 0.0, 1.0) * glow_color.a;
	vec4 src = vec4(0.0);
	if (UV.x >= 0.0 && UV.y >= 0.0 && UV.x <= 1.0 && UV.y <= 1.0) {
		src = texture(TEXTURE, UV);
	}
	float out_a = src.a + ga * (1.0 - src.a);
	vec3 rgb = (src.rgb * src.a + glow_color.rgb * ga * (1.0 - src.a)) / max(out_a, 1e-5);
	float inv_br = 1.0 / max(ct_brightness, 0.01);
	float ct_a = out_a * (ct_multiply.a + ct_offset.a * inv_br);
	vec3 ct_rgb = clamp(rgb * ct_multiply.rgb + ct_offset.rgb * inv_br, 0.0, 1.0);
	if (screen) {
		vec3 base = texture(screen_tex, SCREEN_UV).rgb;
		ct_rgb = 1.0 - (1.0 - base) * (1.0 - ct_rgb);
	}
	COLOR = vec4(ct_rgb * ct_a * v_mod.rgb * v_mod.a, ct_a * v_mod.a);
}
