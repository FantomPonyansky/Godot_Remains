// Asset-fidelity P2: statements inside fragment() (see footprint.gdshaderinc, which the shader
// includes at the top level). Reads TEXTURE at FP_UV (define it before including; UV when not
// defined) and leaves the straight RGBA in `fp_tex`.
#ifndef FP_UV
#define FP_UV UV
#endif
vec2 fp_ddx = dFdx(FP_UV);
vec2 fp_ddy = dFdy(FP_UV);
ivec2 fp_n = fp_taps(fp_ddx / TEXTURE_PIXEL_SIZE, fp_ddy / TEXTURE_PIXEL_SIZE);
vec4 fp_tex;
if (fp_n.x * fp_n.y <= 1) {
	fp_tex = texture(TEXTURE, FP_UV);
} else {
	vec4 fp_acc = vec4(0.0);
	for (int fp_j = 0; fp_j < 4; fp_j++) {
		if (fp_j >= fp_n.y) {
			break;
		}
		for (int fp_i = 0; fp_i < 4; fp_i++) {
			if (fp_i >= fp_n.x) {
				break;
			}
			vec2 fp_uv = FP_UV + ((float(fp_i) + 0.5) / float(fp_n.x) - 0.5) * fp_ddx
					+ ((float(fp_j) + 0.5) / float(fp_n.y) - 0.5) * fp_ddy;
			// outside the texture: transparent (the project repeats textures; a tap must not wrap)
			if (fp_uv.x >= 0.0 && fp_uv.y >= 0.0 && fp_uv.x <= 1.0 && fp_uv.y <= 1.0) {
				vec4 fp_t = textureLod(TEXTURE, fp_uv, 0.0);
				fp_acc += vec4(fp_t.rgb * fp_t.a, fp_t.a);
			}
		}
	}
	fp_acc /= float(fp_n.x * fp_n.y);
	fp_tex = fp_acc.a > 0.0 ? vec4(fp_acc.rgb / fp_acc.a, fp_acc.a) : vec4(0.0);
}
