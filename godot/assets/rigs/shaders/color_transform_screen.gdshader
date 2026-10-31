shader_type canvas_item;
render_mode blend_premul_alpha;

// Flash ColorTransform + screen blend against background.
// Used for the inhibitor (inh) and sky-light (svet) attachments of
// visualLittlePip (Flash blend mode: screen = 1 - (1-a)(1-b)).
// CT applied on straight colour, output premultiplied (see color_transform.gdshader).
uniform vec4 ct_multiply = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 ct_offset = vec4(0.0, 0.0, 0.0, 0.0);
uniform float ct_brightness = 1.0;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

// Node2D.modulate (brightness tracks, attachment alpha) arrives as the
// vertex colour; a custom fragment must apply it explicitly.
// 26.5 (D26-067): the runtime mask factor (identity unless FlashMaskClip sets mask_on)
#include "res://assets/rigs/shaders/flash_mask.gdshaderinc"
// Asset-fidelity P2 (2026-10-12): the footprint switch (off by default; rigs and strips turn it on)
#include "res://assets/rigs/shaders/footprint.gdshaderinc"
varying vec2 v_canvas;
varying vec4 v_mod;

void vertex() {
	v_mod = COLOR;
	v_canvas = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
#include "res://assets/rigs/shaders/footprint_fetch.gdshaderinc"
	vec4 src = fp_tex;   // asset-fidelity P2: footprint sampling when minified (off: texture(TEXTURE, UV))
	float inv_br = 1.0 / max(ct_brightness, 0.01);
	// Straight colour * multiply + offset (the blend formula needs 0-1
	// straight values); coverage is applied to the result below.
	float ct_a = src.a * (ct_multiply.a + ct_offset.a * inv_br) * flash_mask_at(v_canvas);
	vec3 ct_rgb = clamp(src.rgb * ct_multiply.rgb + ct_offset.rgb * inv_br, 0.0, 1.0);
	vec4 base = texture(screen_tex, SCREEN_UV);
	vec3 blended = 1.0 - (1.0 - base.rgb) * (1.0 - ct_rgb);
	COLOR.rgb = blended * ct_a * v_mod.rgb * v_mod.a;
	COLOR.a = ct_a * v_mod.a;
}
