shader_type canvas_item;
render_mode blend_premul_alpha;

// Flash BlurFilter (quality 1: one box pass) on a rig part, then color_transform.gdshader's
// colour transform. blur_x / blur_y are the Flash widths in world pixels along the world axes,
// whatever the part's rotation and scale (Flash filters ignore the display transform).
// The quad grows by the blur radius so the smear is not clipped at the texture edge.
uniform vec4 ct_multiply = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 ct_offset = vec4(0.0, 0.0, 0.0, 0.0);
uniform float ct_brightness = 1.0;
uniform float blur_x = 0.0;
uniform float blur_y = 0.0;

varying vec4 v_mod;
varying vec2 v_ex;
varying vec2 v_ey;

void vertex() {
	v_mod = COLOR;
	mat2 inv = inverse(mat2(MODEL_MATRIX[0].xy, MODEL_MATRIX[1].xy));
	// one world pixel along x / y, in UV
	v_ex = inv * vec2(1.0, 0.0) * TEXTURE_PIXEL_SIZE;
	v_ey = inv * vec2(0.0, 1.0) * TEXTURE_PIXEL_SIZE;
	vec2 grow_uv = abs(v_ex) * (blur_x * 0.5 + 1.0) + abs(v_ey) * (blur_y * 0.5 + 1.0);
	vec2 side = UV * 2.0 - 1.0;
	VERTEX += side * grow_uv / TEXTURE_PIXEL_SIZE;
	UV += side * grow_uv;
}

float box_w(float r, float k) {
	return clamp(r - abs(k) + 1.0, 0.0, 1.0);
}

void fragment() {
	float rx = max(blur_x - 1.0, 0.0) * 0.5;
	float ry = max(blur_y - 1.0, 0.0) * 0.5;
	vec4 acc = vec4(0.0);
	float wsum = 0.0;
	for (int j = -8; j <= 8; j++) {
		float wy = box_w(ry, float(j));
		if (wy <= 0.0) {
			continue;
		}
		for (int i = -8; i <= 8; i++) {
			float wx = box_w(rx, float(i));
			if (wx <= 0.0) {
				continue;
			}
			wsum += wx * wy;
			// TEXTURE cannot be passed to a function; outside the texture is transparent.
			vec2 uv = UV + v_ex * float(i) + v_ey * float(j);
			if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
				continue;
			}
			vec4 t = texture(TEXTURE, uv);
			acc += vec4(t.rgb * t.a, t.a) * wx * wy;
		}
	}
	acc /= max(wsum, 1e-5);
	vec4 tex = acc.a > 0.0 ? vec4(acc.rgb / acc.a, acc.a) : vec4(0.0);
	float inv_br = 1.0 / max(ct_brightness, 0.01);
	float out_a = tex.a * (ct_multiply.a + ct_offset.a * inv_br);
	COLOR = vec4(
		(tex.rgb * ct_multiply.rgb + ct_offset.rgb * inv_br) * tex.a * v_mod.rgb * v_mod.a,
		out_a * v_mod.a
	);
}
