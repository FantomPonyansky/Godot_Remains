// Step 26.5 (D26-067, contract D-J): the shader mask of a runtime Flash mask (`maskee.mask =
// masker`: GUI.as:121-122 the AP bar, PipPageInfo.as:43 the map). FlashMaskClip (scripts/ui/
// flash_mask_clip.gd) replaces 20.3's `clip_children` -- which kept stale pixels when the masked
// content shrank on 4.7.2 GL Compatibility -- by this factor on every drawing descendant of the
// maskee: the masker's flattened frame-1 raster (20.1's `_flat.png`) sampled at the fragment's
// canvas position through the masker's current global transform (the uniforms are refreshed every
// frame). `mask_on` 0 = no mask (the default: the including shaders draw as before).
uniform float mask_on = 0.0;
uniform sampler2D mask_tex : repeat_disable, filter_linear;
// canvas position p -> mask uv: (dot(mask_row_u.xy, p) + mask_row_u.z, dot(mask_row_v.xy, p) + mask_row_v.z)
uniform vec4 mask_row_u = vec4(0.0);
uniform vec4 mask_row_v = vec4(0.0);

float flash_mask_at(vec2 p) {
	if (mask_on < 0.5) {
		return 1.0;
	}
	vec2 muv = vec2(dot(mask_row_u.xy, p) + mask_row_u.z, dot(mask_row_v.xy, p) + mask_row_v.z);
	if (muv.x < 0.0 || muv.y < 0.0 || muv.x > 1.0 || muv.y > 1.0) {
		return 0.0;
	}
	return texture(mask_tex, muv).a;
}
