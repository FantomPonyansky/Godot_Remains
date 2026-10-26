shader_type canvas_item;

// Box.dsf: DropShadowFilter(distance 0, angle 90, black, alpha 0.8, blurX 8, blurY 8,
// strength 1, quality 3, hideObject). Three box passes of width 8 have sigma ~3.97 px.
// 7x7 linearly filtered taps 3 px apart reach +-9 px (2.3 sigma), so the node must use
// linear filtering. margin grows the quad so the blur is not cut at the texture edge
// (unflipped sprites only); texels outside the texture count as clear.
uniform float alpha = 0.8;
uniform float sigma = 3.97;
uniform float margin = 10.0;

void vertex() {
	vec2 side = sign(UV - 0.5);
	VERTEX += side * margin;
	UV += side * margin * TEXTURE_PIXEL_SIZE;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * 3.0;
	float k = 9.0 / (2.0 * sigma * sigma);
	float acc = 0.0;
	float total = 0.0;
	for (int y = -3; y <= 3; y++) {
		for (int x = -3; x <= 3; x++) {
			float w = exp(-float(x * x + y * y) * k);
			vec2 at = UV + vec2(float(x), float(y)) * px;
			vec2 inside = step(vec2(0.0), at) * step(at, vec2(1.0));
			acc += texture(TEXTURE, at).a * inside.x * inside.y * w;
			total += w;
		}
	}
	COLOR = vec4(0.0, 0.0, 0.0, acc / total * alpha);
}
