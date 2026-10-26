shader_type canvas_item;

uniform vec4 fill : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	COLOR = vec4(fill.rgb, texture(TEXTURE, UV).a * fill.a);
}
