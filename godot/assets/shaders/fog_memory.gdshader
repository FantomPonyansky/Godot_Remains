shader_type canvas_item;

// fog.gd bitmap: alpha is 1 - live visibility, red the most a tile was ever
// lit (0 in @retdark rooms). Remembered-only places draw dim and greyish.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float mem_level = 0.4;
uniform float mem_saturation = 0.55;

void fragment() {
	vec4 fog = texture(TEXTURE, UV);
	float live = 1.0 - fog.a;
	float mem = fog.r * mem_level;
	vec3 under = texture(screen_tex, SCREEN_UV).rgb;
	float recall = clamp((mem - live) / mem_level, 0.0, 1.0);
	float grey = dot(under, vec3(0.299, 0.587, 0.114));
	vec3 tone = mix(under, vec3(grey), recall * (1.0 - mem_saturation));
	COLOR = vec4(tone * max(live, mem), 1.0);
}
