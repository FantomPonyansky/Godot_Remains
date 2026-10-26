shader_type canvas_item;

// Grafon.drawFon / setFonSize: the land's fon picture, fixed on screen and
// stretched from the top-left corner to cover it. Per room (cells texture):
// rgb undoes the room's colour filter (and applies colorfon instead), alpha is
// the colorBmp black (0xAA + darkness) left over the gaps unless the room is
// sky / transpfon. Outside the rooms it is black.
// mask: a back "hole" sprite, shaped by its own texture alpha.
uniform sampler2D fon : source_color, filter_linear;
uniform sampler2D cells : filter_nearest;
uniform vec2 grid = vec2(1.0);
uniform vec2 room_px = vec2(1920.0, 1000.0);
uniform vec2 origin = vec2(0.0);
uniform vec2 crop = vec2(1.0);
uniform bool mask = false;
// Screen UV to world: origin + view_x * u + view_y * v (set every frame).
uniform vec2 view_origin = vec2(0.0);
uniform vec2 view_x = vec2(1.0, 0.0);
uniform vec2 view_y = vec2(0.0, 1.0);

void fragment() {
	vec2 world = view_origin + view_x * SCREEN_UV.x + view_y * SCREEN_UV.y - origin;
	vec2 cell = floor(world / room_px);
	vec4 c = vec4(1.0);
	if (all(greaterThanEqual(cell, vec2(0.0))) && all(lessThan(cell, grid))) {
		c = texture(cells, (cell + 0.5) / grid);
	}
	vec3 rgb = texture(fon, SCREEN_UV * crop).rgb * c.rgb * (1.0 - c.a);
	COLOR = vec4(rgb, mask ? texture(TEXTURE, UV).a : 1.0);}
