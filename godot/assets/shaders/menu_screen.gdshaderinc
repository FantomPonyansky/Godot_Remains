// Flash blendMode "screen" for the main-menu parts (Displ.as), drawn as two
// passes: multiply by (1 - src), then add src. src is the premultiplied
// colour after the optional effects below.

// A child placed with blendMode "multiply" inside the part (magic.krug).
uniform bool use_ring = false;
uniform sampler2D ring_tex : filter_linear;
uniform vec2 ring_origin;
uniform vec2 ring_size = vec2(1.0);
uniform float ring_angle = 0.0;
uniform float ring_scale = 1.0;
// Another clip's alpha as the mask (groza.tuchi.mask = groza.maska).
uniform bool use_mask = false;
uniform sampler2D mask_tex : filter_linear;
uniform vec2 mask_pos;
uniform vec2 mask_scale = vec2(1.0);
uniform vec2 mask_origin;
uniform vec2 mask_size = vec2(1.0);
// GlowFilter (outer) on the part.
uniform bool use_glow = false;
uniform vec4 glow_color : source_color = vec4(1.0, 0.4, 0.0, 1.0);
uniform float glow_radius = 6.0;
uniform float glow_strength = 2.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

vec4 inside(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, uv);
}

vec3 screen_src(sampler2D tex, vec2 uv, vec2 px, vec4 modulate) {
	vec4 c = texture(tex, uv);
	vec3 pre = c.rgb * c.a;
	float a = c.a;
	if (use_glow) {
		float sum = 0.0;
		for (int i = 0; i < 12; i++) {
			float ang = float(i) * 0.5235988;
			vec2 dir = vec2(cos(ang), sin(ang)) * px;
			sum += texture(tex, uv + dir * glow_radius).a + texture(tex, uv + dir * glow_radius * 0.5).a;
		}
		float g = clamp(sum / 24.0 * glow_strength, 0.0, 1.0);
		pre += glow_color.rgb * g * (1.0 - a);
		a += g * (1.0 - a);
	}
	if (use_ring) {
		float s = sin(-ring_angle);
		float co = cos(-ring_angle);
		vec2 p = vec2(local.x * co - local.y * s, local.x * s + local.y * co) / ring_scale;
		vec4 k = inside(ring_tex, (p + ring_origin) / ring_size);
		pre *= mix(vec3(1.0), k.rgb, k.a);
	}
	if (use_mask) {
		vec2 p = (local - mask_pos) / mask_scale;
		pre *= inside(mask_tex, (p + mask_origin) / mask_size).a;
	}
	return clamp(pre * modulate.rgb * modulate.a, 0.0, 1.0);
}
