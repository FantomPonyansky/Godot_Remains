shader_type canvas_item;

// Flash ColorMatrixFilter on the world view (Grafon.specEffect): each output
// channel is row . (r, g, b, a) + offset, offsets in 0..1. blur > 0 reads a
// lower mip of the screen (BlurFilter).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 row0 = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 row1 = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 row2 = vec4(0.0, 0.0, 1.0, 0.0);
uniform float off0 = 0.0;
uniform float off1 = 0.0;
uniform float off2 = 0.0;
uniform float blur = 0.0;

void fragment() {
	vec4 c = textureLod(screen_tex, SCREEN_UV, blur);
	vec4 src = vec4(c.rgb, 1.0);
	COLOR = vec4(
		clamp(dot(row0, src) + off0, 0.0, 1.0),
		clamp(dot(row1, src) + off1, 0.0, 1.0),
		clamp(dot(row2, src) + off2, 0.0, 1.0),
		1.0);
}
