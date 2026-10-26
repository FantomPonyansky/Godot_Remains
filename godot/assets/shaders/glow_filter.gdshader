shader_type canvas_item;

// Flash GlowFilter(color, alpha 1, blurX 6, blurY 6, strength 1, quality 3).
// Three box passes of width 6 have sigma ~2.96 px. Outer glow, no knockout:
// this copy draws behind the art and the art covers its own interior.
// margin grows the quad so unpadded art still gets its halo. region is the
// drawn rect in UV space (min.xy, max.xy); texels outside it count as clear.
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float strength = 1.0;
uniform float sigma = 2.96;
uniform float margin = 0.0;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 flip = vec2(1.0, 1.0);
// Tap spacing in texels, for blurs wider than the 13-tap kernel.
uniform float spread = 1.0;

void vertex() {
	if (margin > 0.0) {
		vec2 t = (UV - region.xy) / max(region.zw - region.xy, vec2(0.000001));
		vec2 side = sign(t - 0.5);
		VERTEX += side * flip * margin;
		UV += side * margin * TEXTURE_PIXEL_SIZE;
	}
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float acc = 0.0;
	float total = 0.0;
	float k = 1.0 / (2.0 * sigma * sigma);
	for (int y = -6; y <= 6; y++) {
		for (int x = -6; x <= 6; x++) {
			float w = exp(-float(x * x + y * y) * k);
			vec2 at = UV + vec2(float(x), float(y)) * px * spread;
			vec2 inside = step(region.xy, at) * step(at, region.zw);
			acc += texture(TEXTURE, at).a * inside.x * inside.y * w;
			total += w;
		}
	}
	float a = clamp(acc / total * strength, 0.0, 1.0);
	COLOR = vec4(glow_color.rgb, a * glow_color.a);
}
