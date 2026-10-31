shader_type canvas_item;
render_mode blend_premul_alpha;

// Standard color_transform uniforms (compatibility with player rig color system)
uniform vec4 ct_multiply = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 ct_offset = vec4(0.0, 0.0, 0.0, 0.0);
uniform float ct_brightness = 1.0;

// Shape-space constants (from pero SVG viewBox and gradientTransform)
// ViewBox: -176.0 -8.3 181.0 63.6
// Gradient: horizontal linearGradient, canonical [-819.2, 819.2]
// gradientTransform: matrix(0.047104, 0, 0, 0.02298, tx, ty)
const float SHAPE_LEFT = -176.0;
const float SHAPE_WIDTH = 181.0;
const float GRAD_HALF_SPAN = 38.58; // 0.047104 * 819.2

// Sweep range: gradient center tx travels from beyond-right to beyond-left.
const float TX_START = 38.70;   // gradient center beyond right edge of shape
const float TX_END = -213.40;   // gradient center beyond left edge of shape

// Flash timing: 70 frames at 30 FPS = 2.333 seconds total cycle.
// Frames 0-43 (1.467s): idle hold — gradient off-screen right, feather = edge pad white.
// Frames 44-69 (0.833s): sweep — gradient slides right-to-left with pastel rainbow.
const float CYCLE_TIME = 2.333;  // 70 frames / 30 fps
const float IDLE_FRAC = 0.6286;  // 44/70 — fraction of cycle that is idle

// Gradient edge colors (pad outside [0,1] range — semi-transparent white)
const vec4 EDGE_LEFT = vec4(1.0, 1.0, 1.0, 0.439);
const vec4 EDGE_RIGHT = vec4(1.0, 1.0, 1.0, 0.518);

// 10-stop gradient offsets (from Flash linearGradient)
const float S0 = 0.0;
const float S1 = 0.129;
const float S2 = 0.255;
const float S3 = 0.325;
const float S4 = 0.412;
const float S5 = 0.518;
const float S6 = 0.588;
const float S7 = 0.706;
const float S8 = 0.843;
const float S9 = 1.0;

vec4 rainbow_pastel(float t) {
	// Pastel rainbow (from Flash frames 44-69 — the visible sweep phase):
	// WHITE@44% -> FF8A8A -> FFC670 -> FFFF6D -> DAFF77
	//           -> 7EFF7E -> 56F0F0 -> 83ACFF -> DC93FF -> WHITE@52%
	if (t <= S1) return mix(EDGE_LEFT, vec4(1.0, 0.541, 0.541, 1.0), t / S1);
	if (t <= S2) return mix(vec4(1.0, 0.541, 0.541, 1.0), vec4(1.0, 0.776, 0.439, 1.0), (t - S1) / (S2 - S1));
	if (t <= S3) return mix(vec4(1.0, 0.776, 0.439, 1.0), vec4(1.0, 1.0, 0.427, 1.0), (t - S2) / (S3 - S2));
	if (t <= S4) return mix(vec4(1.0, 1.0, 0.427, 1.0), vec4(0.855, 1.0, 0.467, 1.0), (t - S3) / (S4 - S3));
	if (t <= S5) return mix(vec4(0.855, 1.0, 0.467, 1.0), vec4(0.494, 1.0, 0.494, 1.0), (t - S4) / (S5 - S4));
	if (t <= S6) return mix(vec4(0.494, 1.0, 0.494, 1.0), vec4(0.337, 0.941, 0.941, 1.0), (t - S5) / (S6 - S5));
	if (t <= S7) return mix(vec4(0.337, 0.941, 0.941, 1.0), vec4(0.514, 0.675, 1.0, 1.0), (t - S6) / (S7 - S6));
	if (t <= S8) return mix(vec4(0.514, 0.675, 1.0, 1.0), vec4(0.863, 0.576, 1.0, 1.0), (t - S7) / (S8 - S7));
	return mix(vec4(0.863, 0.576, 1.0, 1.0), EDGE_RIGHT, (t - S8) / (S9 - S8));
}

// Asset-fidelity P2 (2026-10-12): the footprint switch (off by default; rigs and strips turn it on)
#include "res://assets/rigs/shaders/footprint.gdshaderinc"
// Node2D.modulate arrives as the vertex colour; apply it explicitly.
varying vec4 v_mod;

void vertex() {
	v_mod = COLOR;
}

void fragment() {
#include "res://assets/rigs/shaders/footprint_fetch.gdshaderinc"
	vec4 tex = fp_tex;   // asset-fidelity P2: footprint sampling when minified (off: texture(TEXTURE, UV))
	float shape_alpha = tex.a;
	if (shape_alpha < 0.001) {
		discard;
	}

	// Flash timing: idle hold then sweep, looping every 2.333 seconds.
	float cycle_t = fract(TIME / CYCLE_TIME);
	float tx;
	if (cycle_t < IDLE_FRAC) {
		// Idle phase: gradient parked off-screen right → feather = edge pad white
		tx = TX_START;
	} else {
		// Sweep phase: gradient slides right-to-left
		float sweep_t = (cycle_t - IDLE_FRAC) / (1.0 - IDLE_FRAC);
		tx = mix(TX_START, TX_END, sweep_t);
	}

	// Map UV.x to gradient parameter [0,1]
	float shape_x = UV.x * SHAPE_WIDTH + SHAPE_LEFT;
	float grad_t = (shape_x - tx) / (2.0 * GRAD_HALF_SPAN) + 0.5;

	// Sample gradient (pad at edges with semi-transparent white)
	vec4 grad;
	if (grad_t < 0.0) {
		grad = EDGE_LEFT;
	} else if (grad_t > 1.0) {
		grad = EDGE_RIGHT;
	} else {
		grad = rainbow_pastel(grad_t);
	}

	// Combine gradient with shape mask
	float final_alpha = shape_alpha * grad.a;

	// Apply color_transform on straight colour, premultiply by coverage
	float inv_br = 1.0 / max(ct_brightness, 0.01);
	float out_a = final_alpha * (ct_multiply.a + ct_offset.a * inv_br);
	COLOR = vec4(
		(grad.rgb * ct_multiply.rgb + ct_offset.rgb * inv_br) * final_alpha * v_mod.rgb * v_mod.a,
		out_a * v_mod.a
	);
}
