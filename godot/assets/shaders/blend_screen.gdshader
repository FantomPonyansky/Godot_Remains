shader_type canvas_item;
render_mode blend_premul_alpha;

// Flash blendMode "screen" at alpha a: dst + a * s * (1 - dst). Premultiplied
// output scales dst by a single factor, so the brightest channel stands in for it.
void fragment() {
	vec3 s = COLOR.rgb * COLOR.a;
	COLOR = vec4(s, max(s.r, max(s.g, s.b)));
}
