shader_type canvas_item;

// DisplacementMapFilter on the hair bitmap (src_tex). Sampled bilinearly at
// the fractional offset (Flash rounds to whole pixels, which steps visibly).
uniform sampler2D src_tex : filter_linear, repeat_disable;
uniform sampler2D map_tex : filter_nearest, repeat_disable;
uniform vec2 scale = vec2(10.0, 15.0);
uniform vec2 src_size = vec2(240.0, 300.0);
uniform vec2 map_size = vec2(240.0, 300.0);

void fragment() {
	vec2 ip = floor(UV * src_size);
	if (ip.x < 0.0 || ip.y < 0.0 || ip.x >= src_size.x || ip.y >= src_size.y) {
		discard;
	}
	float R = 128.0;
	if (ip.x < map_size.x && ip.y < map_size.y) {
		R = texelFetch(map_tex, ivec2(ip), 0).r * 255.0;
	}
	vec2 d = (R - 128.0) * scale / 256.0;
	vec2 s = ip + 0.5 + d;
	if (s.x < 0.0 || s.y < 0.0 || s.x >= src_size.x || s.y >= src_size.y) {
		discard;
	}
	vec4 c = texture(src_tex, s / src_size);
	if (c.a < 0.004) {
		discard;
	}
	COLOR = c;
}
