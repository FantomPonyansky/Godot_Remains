shader_type canvas_item;
render_mode blend_mul;

#include "res://assets/shaders/menu_screen.gdshaderinc"

void fragment() {
	COLOR = vec4(vec3(1.0) - screen_src(TEXTURE, UV, TEXTURE_PIXEL_SIZE, COLOR), 1.0);
}
