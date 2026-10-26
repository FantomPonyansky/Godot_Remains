extends UnitBrain

## UnitThunderTurret: one of the 28 guns bound to the thunderhead hull. It rides
## head + bind, and while the head attacks and it is 200 px inside the arena it
## fires ttweap<tr> at the player, reloading faster for every turret already lost.
## Mega turrets show their shield pole, cannot be hurt and have 10x hp.

const SCALE := 3.0
const MARGIN := 200.0

var head: CharacterBody2D = null
var bind := Vector2.ZERO
var korp_rot := 0
var mega := false
var t_wait := 0
var cur: UnitGun


func configure() -> void:
	var h: Variant = u.get_meta("head", null)
	if h is CharacterBody2D:
		head = h
	bind = u.get_meta("bind", Vector2.ZERO)
	korp_rot = int(u.get_meta("korp_rot", 0))
	mega = bool(u.get_meta("mega", false))
	flips_sprite = false
	is_fly = true
	always_active = true
	u.set("fixed_post", true)
	u.set("_can_lift", false)
	u.set("_trup", false)
	u.set("_flying", true)
	var mult := 1.5 if global_dif() == 3 else (2.0 if global_dif() == 4 else 1.0)
	if mega:
		mult *= 10.0
	u.set("max_hp", int(round(float(u.get("max_hp")) * mult)))
	t_wait = randi_range(0, 100)


func ready() -> void:
	u.hp = int(u.get("max_hp"))
	u.collision_mask = 0
	u.set("_detect_delay", 0.0)
	cur = gun("ttweap%d" % tr)
	if cur != null:
		cur.find_cel = true
	weapon_dy = -body().y * 0.5
	u.anim.visible = false
	var entry := vis_entry()
	var parts: Dictionary = entry.get("parts", {})
	var korp := _part(parts.get("korp", {}))
	if korp != null:
		korp.rotation = korp_rot * PI * 0.5
	var pole := _part(parts.get("pole", {}))
	if pole != null:
		pole.visible = mega


func _part(p: Dictionary) -> Sprite2D:
	if p.is_empty():
		return null
	var tex := load("res://assets/sprites/sheets/units/%s" % str(p.get("sheet", ""))) as Texture2D
	if tex == null:
		return null
	var cell: Array = p.cell
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, float(cell[0]), float(cell[1]))
	var spr := Sprite2D.new()
	spr.texture = at
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var anchor: Array = p.get("anchor", [0, 0])
	var pivot: Array = p.get("pivot", [0, 0])
	var m: Array = p.get("rot", [1, 0, 0, 1])
	spr.offset = -Vector2(float(anchor[0]), float(anchor[1]))
	spr.scale = Vector2(float(m[0]), float(m[3])) * SCALE
	spr.position = Vector2(0.0, -body().y * 0.5) + Vector2(float(pivot[0]), float(pivot[1])) * SCALE
	u.add_child(spr)
	return spr


func forces() -> void:
	vel = Vector2.ZERO


func move_body() -> void:
	pass


func after_move(_pushed: Vector2) -> void:
	vel = Vector2.ZERO


func on_damage(amount: float, type: String, bullet: Node, tt: bool) -> float:
	if mega:
		return 0.0
	return super.on_damage(amount, type, bullet, tt)


## The head moves its turrets after it moves (UnitThunderHead.setUgolPos -> run).
func follow(head_center: Vector2) -> void:
	u.global_position = head_center + bind + Vector2(0.0, body().y * 0.5)
	# room_bounds.gd holds a flyer outside every room at room_safe.
	u.set_meta("room_safe", u.global_position)


func control() -> void:
	if head == null or not is_instance_valid(head) or cur == null:
		return
	var hb: Variant = head.get("_brain")
	if hb == null or hb.dying or hb.wrecked or not hb.is_att:
		return
	var c := center()
	var arena: Rect2 = hb.arena
	if not arena.grow(-MARGIN).has_point(c):
		return
	if t_wait > 0:
		t_wait -= 1
		return
	cur.reload_mult = 1.0 / float(hb.reload_div)
	var p := player_node()
	if p == null:
		return
	set_cel(p)
	storona = 1.0 if cel.x > u.global_position.x else -1.0
	cur.attack()
	if cur.is_shoot:
		hb.att_tur = 15
		cur.is_shoot = false


func expl() -> void:
	if head != null and is_instance_valid(head):
		var hb: Variant = head.get("_brain")
		if hb != null:
			hb.die_turret()
	new_part("metal", 4)
	new_part("expl")


func animate() -> void:
	pass
