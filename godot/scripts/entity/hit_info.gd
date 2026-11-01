class_name HitInfo
extends RefCounted

## One hit. Replaces the positional arguments of take_hit and hit_by_bullet.
## Building a HitInfo does not draw from Rng. The enemy bullet variance
## (0.7–1.3) still runs inside enemy.take_hit when from_bullet is set.
## resisted: Resistances.apply already scaled this hit (the old take_hit(dealt, "")).
## from_bullet: the old hit_by_bullet path (prior target, pierce, desintegr).
## contact: the hurtbox knows the touching body. Knock uses source.
## tt: damage over time. No armor and no shock.
## crit and sneak are carried for the caller. A shot's crit is already in amount.

var amount: float = 0.0
var tip: String = ""
var source: Node = null
var source_eid: String = ""
var knock: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var crit: bool = false
var sneak: bool = false
var weapon_id: String = ""
## The bullet's eid. weapon_id is the catalog id.
var bullet_id: String = ""
var effect_id: String = ""
var effect_amount: float = 0.0
var effect_chance: float = 0.0
var explosion: bool = false
var melee: bool = false
var contact: bool = false
var tt: bool = false
var resisted: bool = false
var from_bullet: bool = false
var from_player: bool = false
var pier: float = 0.0
var desintegr: float = 0.0


static func make(amount: float, tip: String = "", source: Node = null) -> HitInfo:
	var hit := HitInfo.new()
	hit.amount = amount
	hit.tip = tip
	hit._set_source(source)
	return hit


static func plain(amount: float, source: Node = null) -> HitInfo:
	return make(amount, "", source)


## Hurtbox contact. Knock is away from source, not the nearest enemy in 160 px.
static func touching(amount: float, source: Node) -> HitInfo:
	var hit := make(amount, "", source)
	hit.contact = true
	return hit


static func melee_hit(amount: float, source: Node, tip: String = "") -> HitInfo:
	var hit := make(amount, tip, source)
	hit.melee = true
	return hit


static func dot(amount: float, tip: String) -> HitInfo:
	var hit := make(amount, tip)
	hit.tt = true
	return hit


## bullet is the projectile. amount is health damage already softened for a blast.
## The 0.7–1.3 roll is not applied here.
static func of_bullet(bullet: Node, amount: float, blast: bool) -> HitInfo:
	var hit := HitInfo.new()
	hit.amount = amount
	hit.from_bullet = true
	hit.explosion = blast
	hit._set_source(bullet)
	if bullet == null:
		return hit
	hit.tip = str(bullet.get("damage_type"))
	hit.weapon_id = str(bullet.get("weapon_id"))
	hit.bullet_id = Entity.eid_of(bullet)
	hit.effect_id = str(bullet.get("dop_effect"))
	var dop: Variant = bullet.get("dop_damage")
	if dop is float or dop is int:
		hit.effect_amount = float(dop)
	var chance: Variant = bullet.get("dop_chance")
	if chance is float or chance is int:
		hit.effect_chance = float(chance)
	hit.from_player = bool(bullet.get("from_player"))
	var pier: Variant = bullet.get("pier")
	if pier is float or pier is int:
		hit.pier = float(pier)
	var des: Variant = bullet.get("desintegr")
	if des is float or des is int:
		hit.desintegr = float(des)
	var dir: Variant = bullet.get("direction")
	if dir is Vector2:
		hit.direction = dir
	if bullet.has_meta("crit"):
		hit.crit = bool(bullet.get_meta("crit"))
	if bullet.has_meta("sneak"):
		hit.sneak = bool(bullet.get_meta("sneak"))
	return hit


func dup() -> HitInfo:
	var copy := HitInfo.new()
	copy.amount = amount
	copy.tip = tip
	copy.source = source
	copy.source_eid = source_eid
	copy.knock = knock
	copy.direction = direction
	copy.crit = crit
	copy.sneak = sneak
	copy.weapon_id = weapon_id
	copy.bullet_id = bullet_id
	copy.effect_id = effect_id
	copy.effect_amount = effect_amount
	copy.effect_chance = effect_chance
	copy.explosion = explosion
	copy.melee = melee
	copy.contact = contact
	copy.tt = tt
	copy.resisted = resisted
	copy.from_bullet = from_bullet
	copy.from_player = from_player
	copy.pier = pier
	copy.desintegr = desintegr
	return copy


func _set_source(node: Node) -> void:
	source = node
	source_eid = Entity.eid_of(node)
