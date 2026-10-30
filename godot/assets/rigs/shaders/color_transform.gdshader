shader_type canvas_item;
render_mode blend_premul_alpha;

// Flash ColorTransform: output = input * multiply + offset, applied on the
// straight (un-premultiplied) colour of the covered pixel and then
// composited by coverage — so the offset is scaled by the texel's alpha and
// transparent texels stay transparent (no rectangular halos).
// Standard tinting uses multiply only (offset stays 0); the offset is the
// death glow (UnitPlayer.as dieTransform).
uniform vec4 ct_multiply = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 ct_offset = vec4(0.0, 0.0, 0.0, 0.0);
// Brightness compensation: matches bone Node2D.modulate RGB (set by animation
// brightness tracks). Pre-divides ct_offset so that when Godot multiplies
// shader output by modulate, the offset survives unchanged:
//   shader: premul * ct_multiply + ct_offset / ct_brightness
//   final:  (premul * ct_multiply + ct_offset / br) * br = premul * ct_multiply * br + ct_offset
// When ct_brightness = 1.0 (default), the division is a no-op.
uniform float ct_brightness = 1.0;

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
	// Straight colour * multiply + offset, then premultiplied by coverage.
	float out_a = tex.a * (ct_multiply.a + ct_offset.a * inv_br);
	COLOR = vec4(
		(tex.rgb * ct_multiply.rgb + ct_offset.rgb * inv_br) * tex.a * v_mod.rgb * v_mod.a,
		out_a * v_mod.a
	);
}
