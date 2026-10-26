shader_type canvas_item;

// odBar: bar2 (od) and bar (odv) grow left from x 0 at scaleX = value / 50, each
// clipped by its striped maska. This quad is the 121x20 mask at (-60.5, -10);
// the bars span y -19..-0.5 in odBar space.
uniform sampler2D bar_tex : filter_nearest;
uniform sampler2D bar2_tex : filter_nearest;
uniform float od_w = 0.0;
uniform float odv_w = 0.0;

void fragment() {
	float m = texture(TEXTURE, UV).a;
	vec2 at = UV * vec2(121.0, 20.0) - vec2(60.5, 10.0);
	vec4 c = vec4(0.0);
	if (at.y >= -19.0 && at.y <= -0.5 && at.x <= 0.0) {
		float v = (at.y + 19.0) / 18.5;
		if (at.x >= -od_w) {
			c = texture(bar2_tex, vec2(1.0 + at.x / max(od_w, 0.001), v));
		}
		if (at.x >= -odv_w) {
			c = texture(bar_tex, vec2(1.0 + at.x / max(odv_w, 0.001), v));
		}
	}
	COLOR = vec4(c.rgb, c.a * m);
}
