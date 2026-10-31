// Asset-fidelity fix round P2 (2026-10-12, lane RENDER): footprint-aware sampling of a
// vector-sourced raster (the rig parts, the strips) when it is drawn minified. Flash
// re-rasterises vectors at every scale with 4x4-supersampled coverage; the port samples a
// raster 2-3x denser than the screen. One bilinear tap per pixel (GL's LINEAR, no mipmaps
// since 26.7) skips texels below 1/2 scale and aliases (jagged, shimmering edges). Here a
// minified pixel averages N x N bilinear taps spread evenly over its footprint along the
// screen axes (the UV derivatives), N = clamp(ceil(texels per pixel / 2), 1, 4) per axis --
// tap spacing <= 2 texels, so the bilinear tents cover the footprint: a box filter of the
// raster over the pixel, the area model of the audit (assets_rendering.md section 2).
// N = 1 (magnified, or down to 1/2 scale) is exactly the old `texture(TEXTURE, UV)`.
// The taps average premultiplied colour and the result is returned straight, so the
// including shader's colour-transform / v_mod / coverage contract is unchanged.
//
// Two parts: this file at the top level (the switch and the tap count) and
// footprint_fetch.gdshaderinc inside fragment() (TEXTURE cannot be passed to a function).
// `footprint` is 0 by default: only the rig parts (rig_base.gd) and the strips
// (strip_vis.gd) turn it on -- the blits, the room bake and the UI keep their sampling.
// A shader that exists only for footprint sampling (strip_footprint.gdshader) defines FP_DEFAULT_ON.
#ifdef FP_DEFAULT_ON
uniform float footprint = 1.0;
#else
uniform float footprint = 0.0;
#endif

ivec2 fp_taps(vec2 tdx, vec2 tdy) {
	if (footprint < 0.5) {
		return ivec2(1);
	}
	// -0.001: an exact 2-texel step (a 2x strip at scale 1) stays one tap
	return ivec2(clamp(int(ceil(length(tdx) * 0.5 - 0.001)), 1, 4),
			clamp(int(ceil(length(tdy) * 0.5 - 0.001)), 1, 4));
}
