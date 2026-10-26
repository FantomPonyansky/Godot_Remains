shader_type canvas_item;

// Desintegr: ColorTransform applied once per tick for burnTime1 ticks, then
// BitmapData.pixelDissolve over burnTime2 ticks.
uniform vec3 mul_col = vec3(1.0);
uniform vec3 add_col = vec3(0.0);
uniform float dissolve = 0.0;
uniform float seed = 0.0;
uniform vec4 glow = vec4(0.0);

float hash(vec2 p) {
	return fract(sin(dot(p + seed, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = clamp(c.rgb * mul_col + add_col, 0.0, 1.0);
	if (glow.a > 0.0 && c.a < 0.5) {
		float near = 0.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.7853982;
			near = max(near, texture(TEXTURE, UV + vec2(cos(a), sin(a)) * TEXTURE_PIXEL_SIZE * 3.0).a);
		}
		c = mix(c, vec4(glow.rgb, near), glow.a * near * (1.0 - c.a));
	}
	if (hash(floor(UV / TEXTURE_PIXEL_SIZE)) < dissolve) {
		c.a = 0.0;
	}
	COLOR = c;
}
