shader_type canvas_item;

// Grafon.decal erase: the shape cuts the front wall and shows the back wall.
// back is that wall texture, tiled from world (0, 0) like the broken-cell patch.
uniform sampler2D back : repeat_enable, filter_nearest;
uniform vec2 back_size = vec2(40.0, 40.0);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 b = texture(back, world / back_size);
	COLOR = vec4(b.rgb, b.a * COLOR.a);
}
