extends StaticBody2D

## Placed spell wall.
## Magical barrier is UnitMWall: 40×120, hp = spell hp × spellPower, loses 0.2 hp
## per 30 Hz tick, and dies at 0. It is a unit, so it does not block walking.
## Ghost wall is one 40×40 tile (collision 3). ghostTimer is the spell dam ×
## spellPower in seconds. Units without transT cannot walk through it.
## The caster's fraction passes both walls. Any other fraction stops and spends hp.
## Ghost tiles stay on the ghost layer, so enemies still cannot walk through.
## The caster is not on that layer, so a ghost wall does not block their walk.

const BULLET_LAYER := 128
const GHOST_LAYER := 256
## Unit.F_PLAYER. Spell.cast_mwall copies owner.fraction; player casts omit it.
const F_PLAYER := 100

var hp: float = 1.0
var decay_per_sec: float = 0.0
var life: float = -1.0
var blocks_ghost: bool = false
## Caster's Unit.fraction. -1 until setup. Same-fraction shots pass.
var fraction: int = -1

const _FxClip := preload("res://scripts/fx_clip.gd")

var _vis: Sprite2D


func _ready() -> void:
	add_to_group("magic_barriers")
	collision_mask = 0
	z_index = 1


func setup_mwall(max_hp: float, caster_fraction: int = -1) -> void:
	_adopt_fraction(caster_fraction)
	hp = max_hp
	# UnitMWall.control: hp -= 0.2 each tick.
	decay_per_sec = 0.2 * 30.0
	life = -1.0
	blocks_ghost = false
	collision_layer = BULLET_LAYER
	_build(Vector2(40, 120))
	# vismwall: origin at the unit's feet.
	_vis = _FxClip.make("fx_mwall", Vector2(0, 60), 1.0, [20])
	add_child(_vis)
	_vis.call("play_from", 1)


func setup_gtile(max_hp: float, seconds: float, caster_fraction: int = -1) -> void:
	_adopt_fraction(caster_fraction)
	hp = max_hp
	decay_per_sec = 0.0
	life = seconds
	blocks_ghost = true
	collision_layer = BULLET_LAYER | GHOST_LAYER
	_build(Vector2(40, 40))
	# Grafon.gwall draws tileGwall into frontBmp at the tile corner.
	_vis = _FxClip.make("fx_gwalltile", Vector2(-20, -20))
	add_child(_vis)
	_vis.call("play_from", 1)


func passes_fraction(shot_fraction: int) -> bool:
	# Bullet.control hits a unit only when un.fraction != owner.fraction.
	return fraction >= 0 and shot_fraction == fraction


func _adopt_fraction(caster_fraction: int) -> void:
	if caster_fraction >= 0:
		fraction = caster_fraction
	elif fraction < 0:
		fraction = F_PLAYER


func absorb(amount: float) -> void:
	hp -= maxf(0.0, amount)
	_paint()
	if hp <= 0.0:
		queue_free()


func _physics_process(delta: float) -> void:
	if decay_per_sec > 0.0:
		hp -= decay_per_sec * delta
	if life >= 0.0:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
	if hp <= 0.0:
		queue_free()
		return
	_paint()


func _build(size: Vector2) -> void:
	var shape_node := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape_node.shape = box
	add_child(shape_node)


func _paint() -> void:
	if _vis == null or blocks_ghost:
		return
	# UnitMWall.visDetails: if (hp<50) vis.alpha=hp/50.
	_vis.modulate.a = 1.0 if hp >= 50.0 else clampf(hp / 50.0, 0.0, 1.0)
