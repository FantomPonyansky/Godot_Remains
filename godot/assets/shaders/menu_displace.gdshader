shader_type canvas_item;

// DisplacementMapFilter (red channel both ways, mode COLOR with colour 0):
// dst(x, y) = src(x + (R - 128) * scale.x / 256, y + (R - 128) * scale.y / 256).
uniform sampler2D map_tex : filter_linear;
uniform vec2 map_size = vec2(240.0, 300.0);
uniform vec2 disp_scale = vec2(10.0, 15.0);
uniform vec2 origin;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 p = local;
	vec2 m = p / map_size;
	if (m.x >= 0.0 && m.y >= 0.0 && m.x <= 1.0 && m.y <= 1.0) {
		float r = texture(map_tex, m).r * 255.0;
		p += (r - 128.0) / 256.0 * disp_scale;
	}
	vec2 uv = (p + origin) * TEXTURE_PIXEL_SIZE;
	vec4 c = vec4(0.0);
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		c = texture(TEXTURE, uv);
	}
	COLOR = c * COLOR;
}
