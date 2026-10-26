shader_type canvas_item;

// morda.magic is blend mode hardlight (14) after Obj.setColor(this, 4).
uniform vec3 magic_mul = vec3(0.137, 1.0, 0.137);
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 src = clamp(tex.rgb * magic_mul, vec3(0.0), vec3(1.0));
	float cover = tex.a;
	vec3 under = texture(screen_tex, SCREEN_UV).rgb;
	vec3 low = 2.0 * under * src;
	vec3 high = vec3(1.0) - 2.0 * (vec3(1.0) - under) * (vec3(1.0) - src);
	vec3 lit = mix(low, high, step(vec3(0.5), src));
	COLOR = vec4(lit, cover);
}
