extends RefCounted

## Unit.checkWater and the isPlav / inWater branches of Unit.forces for bodies
## without a UnitBrain: swimming adds ddy * ddyPlav and keeps velocity * 0.8
## per tick, wading halves velocity.X per tick.

const TPS := 30.0
const TILE := 40.0
const DDY := 900.0
const MAXDY := 600.0
const _Flags := preload("res://scripts/map/room_flags.gd")
const _UnitMassa := preload("res://scripts/unit_massa.gd")


## True while swimming (gravity handled here).
static func swim(body: CharacterBody2D, delta: float, height: float = -1.0) -> bool:
	if height < 0.0:
		var box: Variant = body.get("body_size")
		height = (box as Vector2).y if box is Vector2 else TILE
	var at := body.global_position
	var was := bool(body.get_meta("in_water", false))
	var plav := _Flags.water_at(at - Vector2(0, height * 0.75))
	var wet := plav or (height > TILE and _Flags.water_at(at - Vector2(0, height * 0.25)))
	if was != wet or wet:
		var box_w: Variant = body.get("body_size")
		splash(body.get_tree(), at, height, (box_w as Vector2).x if box_w is Vector2 else TILE,
			was, wet, plav, body.velocity / TPS, _UnitMassa.massa(body), true)
	body.set_meta("in_water", wet)
	if plav:
		body.velocity.y += DDY * float(body.get_meta("ddy_plav", 1.0)) * delta
		body.velocity *= pow(0.8, delta * TPS)
		return true
	if wet:
		body.velocity.x *= pow(0.5, delta * TPS)
	return false


## Unit.forces over Tile.gravity for bodies without a UnitBrain, read at y - h / 4.
## Returns the velocity.y change this frame (ddy * gravity while below maxdy * gravity).
static func fall(body: CharacterBody2D, delta: float, height: float) -> float:
	var g := _Flags.gravity_at(body.global_position - Vector2(0, height * 0.25))
	var vy := body.velocity.y
	if (g > 0.0 and vy < MAXDY * g) or (g < 0.0 and vy > MAXDY * g):
		return DDY * g * delta
	return 0.0


## Unit.checkWater's change of inWater: 'kap' drops by speed and mass, the
## fall_water sound going in and fall_water2 coming out fast; wading faster
## than 3 px/tick throws drops across the body. v is px/tick.
static func splash(tree: SceneTree, at: Vector2, height: float, width: float, was: bool, now: bool,
		plav: bool, v: Vector2, massa: float, pla_kap: bool) -> void:
	if tree == null:
		return
	if was != now:
		if absf(v.y) > 8.0 or pla_kap:
			UnitFx.emit(tree, "kap", Vector2(at.x, at.y - height * 0.25 + v.y),
				{"dy": -absf(v.y) * (randf() * 0.3 + 0.3), "kol": mini(int(absf(v.y * massa * 2.0) + 1.0), 100)})
		if v.y > 5.0:
			fall_sound(massa, v.y / 10.0)
		if v.y < -5.0 and massa > 0.4:
			UnitFx.snd("fall_water2", -v.y / 10.0)
	if now and not plav and absf(v.x) > 3.0:
		UnitFx.emit(tree, "kap", Vector2(at.x, at.y - height * 0.25), {"rx": width})


## Unit.playFallSound / Box.checkWater: the splash by mass.
static func fall_sound(massa: float, vol: float) -> void:
	if massa > 2.0:
		UnitFx.snd("fall_water0", vol)
	elif massa > 0.4:
		UnitFx.snd("fall_water1", vol)
	elif massa > 0.2:
		UnitFx.snd("fall_water2", vol)
	else:
		UnitFx.snd("fall_item_water", vol)
