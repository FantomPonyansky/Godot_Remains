@tool
extends StyleBox

## fl.controls ScrollBar thumb: the ScrollThumb skin stretched as a nine-patch
## with the ScrollBar_thumbIcon grip centred: 4 lines 5 x 1, one pixel apart,
## the same size whatever the thumb length.

@export var texture: Texture2D
@export var margin := 3.0
@export var flat_row := 10
@export var grip_color := Color8(0x00, 0xFF, 0x99)
@export var grip_size := Vector2(5, 1)
@export var grip_lines := 4
@export var grip_step := 2.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if texture != null:
		# The skin's middle carries a bevelled block; stretch one flat row
		# (flat_row) between the caps instead.
		var ts := texture.get_size()
		var rid := texture.get_rid()
		var w := rect.size.x
		RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, Rect2(rect.position, Vector2(w, margin)), rid, Rect2(0, 0, ts.x, margin))
		RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, Rect2(rect.position + Vector2(0, margin), Vector2(w, rect.size.y - margin * 2.0)), rid, Rect2(0, flat_row, ts.x, 1))
		RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, Rect2(rect.position + Vector2(0, rect.size.y - margin), Vector2(w, margin)), rid, Rect2(0, ts.y - margin, ts.x, margin))
		# The exported skin lost its bottom edge: repeat the top edge row there.
		RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, Rect2(rect.position + Vector2(0, rect.size.y - 1.0), Vector2(w, 1.0)), rid, Rect2(0, 0, ts.x, 1))
	var h := grip_step * (grip_lines - 1) + grip_size.y
	if rect.size.y < h + margin * 2.0:
		return
	var at := (rect.position + (rect.size - Vector2(grip_size.x, h)) * 0.5).floor()
	for i in grip_lines:
		RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(at + Vector2(0, grip_step * i), grip_size), grip_color)
