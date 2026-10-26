extends Node2D

## Layered wasteland backdrop. Visual only: no collision, no gameplay.

const SKY_FACTOR := 0.06
const RUINS_FACTOR := 0.16
const NEAR_FACTOR := 0.4

const SKY_ANCHOR := Vector2(1600, 300)
const RUINS_ANCHOR := Vector2(1600, 800)

const RUINS_REGION := Rect2(0, 120, 1920, 880)
const RUINS_HEIGHT := 560.0

var _sky: Node2D
var _ruins: Node2D
var _near: Node2D


func _ready() -> void:
	z_index = -40
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hide_placeholders()
	_build_sky()
	_build_ruins()
	_build_near()
	_build_dressing()
	_dress_floor()
	_dress_platforms()
	_follow_camera()


func _process(_delta: float) -> void:
	_follow_camera()


func _follow_camera() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null or _sky == null:
		return
	var cam := camera.get_screen_center_position()
	# factor 0 stays on the camera; factor 1 stays in the world.
	_sky.global_position = SKY_ANCHOR * SKY_FACTOR + cam * (1.0 - SKY_FACTOR)
	_ruins.global_position = RUINS_ANCHOR * RUINS_FACTOR + cam * (1.0 - RUINS_FACTOR)
	_near.global_position = cam * (1.0 - NEAR_FACTOR)


func _hide_placeholders() -> void:
	var game := get_parent()
	if game == null:
		return
	for child in game.get_children():
		if child == self:
			continue
		var node_name := str(child.name)
		if node_name == "Sky" or node_name.begins_with("Scrap"):
			child.visible = false
	var floor_visual := game.get_node_or_null("World/Floor/Visual")
	if floor_visual:
		floor_visual.visible = false


func _build_sky() -> void:
	_sky = Node2D.new()
	_sky.name = "Sky"
	add_child(_sky)
	var fill := _flat_sprite(Color(0.27, 0.29, 0.27), Vector2(3600, 1400))
	fill.name = "Fill"
	_sky.add_child(fill)
	var clouds := Sprite2D.new()
	clouds.name = "Clouds"
	clouds.texture = preload("res://assets/sprites/env/72_tCloud.png")
	clouds.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clouds.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	clouds.centered = true
	clouds.region_enabled = true
	clouds.region_rect = Rect2(0, 0, 3200, 1200)
	clouds.modulate = Color(0.46, 0.48, 0.44)
	_sky.add_child(clouds)


func _build_ruins() -> void:
	_ruins = Node2D.new()
	_ruins.name = "Ruins"
	_ruins.z_index = 5
	add_child(_ruins)
	var skyline := Sprite2D.new()
	skyline.name = "Skyline"
	skyline.texture = preload("res://assets/sprites/env/87.png")
	skyline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	skyline.centered = true
	skyline.region_enabled = true
	skyline.region_rect = RUINS_REGION
	skyline.scale = Vector2.ONE * (RUINS_HEIGHT / RUINS_REGION.size.y)
	skyline.modulate = Color(0.86, 0.88, 0.84)
	_ruins.add_child(skyline)
	_repeat_horizontal(skyline, 2)


func _build_near() -> void:
	_near = Node2D.new()
	_near.name = "NearRuins"
	_near.z_index = 10
	add_child(_near)
	var dim := Color(0.58, 0.56, 0.52)
	var pieces: Array = [
		[preload("res://assets/sprites/env/32_tCave.png"), Vector2(-420, 120), 280.0, dim],
		[preload("res://assets/sprites/env/9_tBackWall.png"), Vector2(40, 90), 240.0, dim],
		[preload("res://assets/sprites/env/6_tTower.png"), Vector2(460, 40), 150.0, Color(0.7, 0.68, 0.62)],
		[preload("res://assets/sprites/env/4_tWindows.png"), Vector2(860, 70), 130.0, Color(0.66, 0.64, 0.58)],
		[preload("res://assets/sprites/env/26_tConcrete.png"), Vector2(1180, 130), 190.0, dim],
		[preload("res://assets/sprites/env/28_tBrick.png"), Vector2(1520, 160), 110.0, Color(0.62, 0.58, 0.52)],
		[preload("res://assets/sprites/env/41_tRock.png"), Vector2(1780, 150), 170.0, dim],
		[preload("res://assets/sprites/env/9_tBackWall.png"), Vector2(-80, 200), 160.0, Color(0.5, 0.48, 0.45)],
	]
	for piece in pieces:
		var sprite := _scaled_sprite(piece[0], piece[2], piece[3])
		sprite.position = piece[1]
		_near.add_child(sprite)


func _build_dressing() -> void:
	var dressing := Node2D.new()
	dressing.name = "Dressing"
	dressing.z_index = 15
	add_child(dressing)
	var ground_y := 652.0
	var props: Array = [
		[preload("res://assets/sprites/env/46_tPipes.png"), Vector2(200, ground_y), 210.0, Color(0.78, 0.8, 0.78)],
		[preload("res://assets/sprites/env/46_tPipes.png"), Vector2(1680, ground_y), 180.0, Color(0.72, 0.74, 0.72)],
		[preload("res://assets/sprites/env/18_tSkol.png"), Vector2(820, ground_y), 120.0, Color(0.8, 0.8, 0.78)],
		[preload("res://assets/sprites/env/18_tSkol.png"), Vector2(2480, ground_y), 100.0, Color(0.75, 0.75, 0.72)],
		[preload("res://assets/sprites/env/41_tRock.png"), Vector2(1140, ground_y), 130.0, Color(0.7, 0.7, 0.68)],
		[preload("res://assets/sprites/env/41_tRock.png"), Vector2(3040, ground_y), 150.0, Color(0.66, 0.66, 0.64)],
		[preload("res://assets/sprites/env/1_tWoodPlanks.png"), Vector2(2140, ground_y), 130.0, Color(0.7, 0.66, 0.58)],
		[preload("res://assets/sprites/env/38_tRust.png"), Vector2(1380, ground_y), 90.0, Color(0.8, 0.74, 0.64)],
		[preload("res://assets/sprites/env/28_tBrick.png"), Vector2(540, ground_y), 80.0, Color(0.75, 0.7, 0.64)],
	]
	for prop in props:
		var sprite := _scaled_sprite(prop[0], prop[2], prop[3])
		sprite.position = Vector2(prop[1].x, prop[1].y - prop[2] * 0.5)
		dressing.add_child(sprite)


func _dress_floor() -> void:
	var game := get_parent()
	if game == null:
		return
	var floor := game.get_node_or_null("World/Floor") as Node2D
	if floor == null or floor.get_node_or_null("GroundTiles"):
		return
	var size := Vector2(3200, 64)
	var shape_node := floor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		size = (shape_node.shape as RectangleShape2D).size
	var dirt := _tiled_sprite(preload("res://assets/sprites/env/34_tDirt.png"), size)
	dirt.name = "GroundTiles"
	dirt.modulate = Color(0.9, 0.86, 0.78)
	floor.add_child(dirt)
	var lip_height := 20.0
	var lip := _tiled_sprite(preload("res://assets/sprites/env/20_tFloor.png"), Vector2(size.x, 10))
	lip.name = "GroundLip"
	lip.scale = Vector2(1, lip_height / 10.0)
	lip.position = Vector2(0, -size.y * 0.5 + lip_height * 0.5)
	lip.z_index = 1
	floor.add_child(lip)


func _dress_platforms() -> void:
	var game := get_parent()
	if game == null:
		return
	var world := game.get_node_or_null("World")
	if world == null:
		return
	var concrete := preload("res://assets/sprites/env/26_tConcrete.png")
	for child in world.get_children():
		if not str(child.name).begins_with("Platform"):
			continue
		var sprite := child.get_node_or_null("Sprite2D") as Sprite2D
		var shape_node := child.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if sprite == null or shape_node == null or not shape_node.shape is RectangleShape2D:
			continue
		var size := (shape_node.shape as RectangleShape2D).size
		sprite.texture = concrete
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.centered = true
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 160, size.x, size.y)
		sprite.scale = Vector2.ONE
		sprite.position = Vector2.ZERO
		sprite.modulate = Color(0.92, 0.91, 0.88)


func _tiled_sprite(texture: Texture2D, size: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.centered = true
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, size)
	return sprite


func _scaled_sprite(texture: Texture2D, height: float, tint: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	var tex_h := texture.get_size().y
	var scale_factor := height / tex_h
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.modulate = tint
	return sprite


func _flat_sprite(color: Color, size: Vector2) -> Sprite2D:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.scale = size / 4.0
	return sprite


func _repeat_horizontal(sprite: Sprite2D, copies_each_side: int) -> void:
	var width := sprite.region_rect.size.x * sprite.scale.x
	var parent := sprite.get_parent()
	for i in range(1, copies_each_side + 1):
		for sign in [-1.0, 1.0]:
			var copy := sprite.duplicate()
			copy.position.x = width * float(i) * sign
			parent.add_child(copy)
