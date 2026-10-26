extends Node2D

## Emitter parts the weapons cast, stepped like Part.step at 30 Hz.
## gilza: visualGilza, liv 20-29, grav 1, rdx 4, rdy 4, dr -15 * scaleX.
## iskr_bul: sprIskr 3x3 blit, liv 15-19, grav 0.7, minv 5 rv 3, alpha fade, screen.
## Flares (parts.xml anim 1): the clip plays from frame 1 for minliv ticks.

const _WeaponVis := preload("res://scripts/weapon_vis.gd")
const TICK := 1.0 / 30.0
const MAX_PARTS := 100
const FLARES := {
	"spark": ["flSpark", 3], "sparkl": ["flSparkl", 3],
	"laser": ["flLaser", 3], "blump": ["flLaser", 3], "laser2": ["flLaser2", 3],
	"plasma": ["flPlasma", 3], "plasma1": ["flPlasma", 3], "plasma2": ["flPlasma2", 3],
	"laser3": ["flPlasma2", 3], "plevok": ["flPlevok", 3], "dray": ["flDray", 3],
	"telebullet": ["visualTeleFlare", 4], "ice": ["visualIceFlare", 4],
	"flare": ["visualFlare", 10], "bum": ["visualBum", 5], "bumn": ["visualBumNecro", 5],
	"eclipse": ["visualEclipse", 25],
}

const ISKR := "res://assets/sprites/fx/sprIskr.png"
const SCREEN := "res://assets/shaders/blend_screen.gdshader"

static var _iskr: Texture2D
static var _screen_mat: ShaderMaterial

var _parts: Array = []
var _acc := 0.0


static func shell(tree: SceneTree, at: Vector2, scale_x: float) -> void:
	var host := _host(tree)
	if host == null:
		return
	var clip := _WeaponVis.fx_clip("visualGilza")
	if clip == null:
		return
	var sprite := Sprite2D.new()
	clip.show(sprite)
	host.call("_add", {
		"node": sprite, "at": at,
		"vel": Vector2((randf() - 0.5) * 4.0, (randf() - 0.5) * 4.0),
		"ddy": 1.0, "dr": -15.0 * scale_x, "liv": 20 + randi() % 10,
	})


static func sparks(tree: SceneTree, at: Vector2, count: int) -> void:
	var host := _host(tree)
	if host == null:
		return
	var tex := _spark_texture()
	if tex == null:
		return
	var frames := maxi(tex.get_width() / 3, 1)
	for _i in mini(count, 20):
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.region_enabled = true
		sprite.region_rect = Rect2(float(randi() % frames) * 3.0, 0.0, 3.0, 3.0)
		sprite.material = _screen()
		var turn := randf() * TAU
		var speed := randf() * 3.0 + 5.0
		host.call("_add", {
			"node": sprite, "at": at, "vel": Vector2(sin(turn), cos(turn)) * speed,
			"ddy": 0.7, "dr": 0.0, "liv": 15 + randi() % 5, "alph": true,
		})


static func flare(tree: SceneTree, at: Vector2, id: String) -> void:
	if not FLARES.has(id):
		return
	var host := _host(tree)
	if host == null:
		return
	var spec: Array = FLARES[id]
	var clip := _WeaponVis.fx_clip(str(spec[0]))
	if clip == null:
		return
	var sprite := Sprite2D.new()
	clip.goto_play(1)
	clip.show(sprite)
	host.call("_add", {"node": sprite, "at": at, "vel": Vector2.ZERO, "ddy": 0.0, "dr": 0.0,
		"liv": int(spec[1]), "clip": clip})


static func _host(tree: SceneTree) -> Node:
	if tree == null or tree.current_scene == null:
		return null
	var found := tree.get_first_node_in_group("weapon_fx")
	if found != null:
		return found
	var made := (load("res://scripts/weapon_fx.gd") as GDScript).new() as Node2D
	made.name = "WeaponFx"
	made.z_index = 4
	made.add_to_group("weapon_fx")
	tree.current_scene.add_child(made)
	return made


## sprIskr: six 3x3 sparks side by side. A blit part shows one at random.
static func _spark_texture() -> Texture2D:
	if _iskr == null and ResourceLoader.exists(ISKR):
		_iskr = load(ISKR) as Texture2D
	return _iskr


static func _screen() -> Material:
	if _screen_mat == null:
		_screen_mat = ShaderMaterial.new()
		_screen_mat.shader = load(SCREEN)
	return _screen_mat


func _add(part: Dictionary) -> void:
	if _parts.size() >= MAX_PARTS:
		return
	var node := part["node"] as Node2D
	add_child(node)
	node.global_position = part["at"]
	_parts.append(part)


func _physics_process(delta: float) -> void:
	_acc += delta
	var guard := 0
	while _acc >= TICK and guard < 3:
		_acc -= TICK
		guard += 1
		_step()


func _step() -> void:
	var keep: Array = []
	for part in _parts:
		var node := part["node"] as Node2D
		if not is_instance_valid(node):
			continue
		var vel: Vector2 = part["vel"]
		if vel != Vector2.ZERO or float(part["ddy"]) != 0.0:
			node.position += vel
			vel.y += float(part["ddy"])
			part["vel"] = vel
			node.rotation_degrees += float(part["dr"])
		var clip: Variant = part.get("clip")
		if clip != null:
			clip.advance()
			clip.show(node as Sprite2D)
		var liv := int(part["liv"])
		if part.get("alph", false):
			node.modulate.a = float(liv) / 10.0 if liv < 9 else 1.0
		liv -= 1
		part["liv"] = liv
		if liv <= 0:
			node.queue_free()
		else:
			keep.append(part)
	_parts = keep
