shader_type canvas_item;
render_mode blend_premul_alpha;

// Flash blendMode "hardlight" at alpha a: a channel under 0.5 multiplies dst by
// 2s, one over 0.5 screens it with 2s - 1. Premultiplied output scales dst by a
// single factor, so that factor is the mean over the three channels.
void fragment() {
	vec3 d = COLOR.rgb * 2.0 - 1.0;
	float a = COLOR.a;
	COLOR = vec4(max(d, vec3(0.0)) * a, a * (abs(d.r) + abs(d.g) + abs(d.b)) / 3.0);
}
