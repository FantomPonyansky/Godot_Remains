shader_type canvas_item;
render_mode blend_premul_alpha;

// Flash ColorTransform + mask clipping for pupil (zrak) sprites.
// Identical to color_transform.gdshader but samples a mask texture
// (eyelid aperture) and clips output alpha. Used instead of Godot's
// clip_children which doesn't work inside CanvasGroup (bug #85243).
uniform vec4 ct_multiply = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 ct_offset = vec4(0.0, 0.0, 0.0, 0.0);
uniform float ct_brightness = 1.0;
// Eyelid aperture mask: alpha channel defines visible region.
uniform sampler2D mask_texture : filter_linear;
// Affine map from sprite UV to mask texture UV (the sprite's full local
// transform incl. rotation/skew, set by player_rig._recompute_mask_uv):
//   mask_uv = mask_uv_xform * UV + mask_uv_offset
uniform mat2 mask_uv_xform = mat2(vec2(1.0, 0.0), vec2(0.0, 1.0));
uniform vec2 mask_uv_offset = vec2(0.0, 0.0);

// Asset-fidelity P2 (2026-10-12): the footprint switch (off by default; rigs and strips turn it on)
#include "res://assets/rigs/shaders/footprint.gdshaderinc"
// Node2D.modulate (brightness tracks, magic/inhibitor alpha) arrives as the
// vertex colour; a custom fragment must apply it explicitly.
varying vec4 v_mod;

void vertex() {
	v_mod = COLOR;
}

void fragment() {
#include "res://assets/rigs/shaders/footprint_fetch.gdshaderinc"
	vec4 tex = fp_tex;   // asset-fidelity P2: footprint sampling when minified (off: texture(TEXTURE, UV))
	float inv_br = 1.0 / max(ct_brightness, 0.01);
	// Straight colour * multiply + offset, premultiplied by coverage
	float out_a = tex.a * (ct_multiply.a + ct_offset.a * inv_br);
	// Mask clipping: sample eyelid aperture
	vec2 muv = mask_uv_xform * UV + mask_uv_offset;
	float mask_a = texture(mask_texture, muv).a;
	// Clip pixels outside mask bounds
	mask_a *= step(0.0, muv.x) * step(muv.x, 1.0) * step(0.0, muv.y) * step(muv.y, 1.0);
	// The mask is coverage: in premultiplied output it must scale rgb as well
	// as alpha, otherwise blend_premult_alpha adds the clipped colour on top
	// of the background (an additive white ring around the eye aperture).
	out_a *= mask_a;
	COLOR = vec4(
		(tex.rgb * ct_multiply.rgb + ct_offset.rgb * inv_br) * tex.a * mask_a * v_mod.rgb * v_mod.a,
		out_a * v_mod.a
	);
}
