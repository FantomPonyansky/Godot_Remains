shader_type canvas_item;

// tile_outline.gd: mode 0 clips a block texture by its main mask, mode 1 draws
// the edge texture through the edge mask. glow = two inner glows (px, alpha),
// bevel = the potek shade under open tops (px, alpha).
uniform sampler2D main_mask : filter_linear, repeat_disable;
uniform sampler2D edge_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin;
uniform vec2 mask_size;
uniform vec4 glow;
uniform vec2 bevel;
uniform int mode = 0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float solid_at(vec2 w) {
	vec2 uv = (w - mask_origin) / mask_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 1.0;
	}
	return texture(main_mask, uv).r;
}

float inner(float r) {
	if (r <= 0.0) {
		return 0.0;
	}
	float s = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853982;
		vec2 d = vec2(cos(a), sin(a));
		s += solid_at(world + d * r) + solid_at(world + d * r * 0.5);
	}
	return clamp((1.0 - s / 16.0) * 2.0, 0.0, 1.0);
}

void fragment() {
	vec2 uv = (world - mask_origin) / mask_size;
	float m = mode == 0 ? texture(main_mask, uv).r : texture(edge_mask, uv).r;
	vec4 c = COLOR;
	c.a *= m;
	float dark = 1.0 - (1.0 - glow.y * inner(glow.x)) * (1.0 - glow.w * inner(glow.z));
	if (bevel.x > 0.0) {
		float open = 0.0;
		for (int t = 1; t <= 4; t++) {
			open += 1.0 - solid_at(world - vec2(0.0, bevel.x * float(t) * 0.25));
		}
		dark = 1.0 - (1.0 - dark) * (1.0 - bevel.y * open * 0.25);
	}
	c.rgb *= 1.0 - clamp(dark, 0.0, 1.0);
	COLOR = c;
}
