shader_type canvas_item;

// Location.cTransform (ColorFilter): the room's colour multipliers over
// everything drawn under it. A BackBufferCopy of the rect comes first.
// Near an edge the multipliers ease toward the neighbour room's: halfway at
// the shared edge, so two filtered rooms meet without a seam, and fully at
// `feather` past it, where the rect is extended over an unfiltered room.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec3 mult = vec3(1.0);
uniform vec2 room_size = vec2(1920.0, 1000.0);
// Extension past the room edge: left, top, right, bottom.
uniform vec4 ext = vec4(0.0);
uniform vec3 n_left = vec3(1.0);
uniform vec3 n_top = vec3(1.0);
uniform vec3 n_right = vec3(1.0);
uniform vec3 n_bottom = vec3(1.0);
uniform float feather = 120.0;

float edge_w(float d) {
	return clamp(0.5 - d / (2.0 * feather), 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * (room_size + ext.xy + ext.zw) - ext.xy;
	vec3 c = mult;
	c = mix(c, n_left, edge_w(p.x));
	c = mix(c, n_right, edge_w(room_size.x - p.x));
	c = mix(c, n_top, edge_w(p.y));
	c = mix(c, n_bottom, edge_w(room_size.y - p.y));
	COLOR = vec4(texture(screen_tex, SCREEN_UV).rgb * c, 1.0);
}
