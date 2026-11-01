extends RefCounted

## Melee for an enemy body: swing band, strike, bite, and ram.
## State lives here. The body forwards a name only when another script uses it.
## u is that body. Balance consts and the node stay on u.

const _Body := preload("res://scripts/enemy.gd")

var u: _Body


func _init(body: _Body) -> void:
	u = body

var melee_damage: int = 12

var _swing_x: float = 0.0

var _swing_above: float = 0.0

var _swing_below: float = 0.0

var _strike_cd: float = 0.0

var _strike_windup: float = 0.0

var _strike_hold: float = 1.0

var _contact_bite: bool = false

var _attack_reach: float = INF

var _windup_left: int = 0

var _smash: bool = false

var _body_damage: int = 0

var _body_cd: int = 0

var _swing_chance: float = 0.0

var _band_min: float = 0.0

var _band_max: float = 0.0

var _band_up: float = 0.0

var _band_down: float = 0.0

var _leap_above: float = 0.0

var _ram_while_chase: bool = false

var _melee_while_chase: bool = false

var _ram_x: float = 0.0

var _ram_y: float = 0.0

var _bite_hop: float = 0.0


func _melee_swing() -> void:
	if not u._senses._player_valid() or u._attack_cd > 0.0 or _windup_left > 0.0 or not _in_swing_band():
		return
	u._attack_cd = u._ticks(_strike_cd)
	if u._show_attack:
		u._attack_left = u._ticks(u.PUNCH_TICKS / u.TPS)
	if _strike_windup > 0.0:
		_windup_left = u._ticks(_strike_windup)
		return
	_deliver_strike()

func _deliver_strike() -> void:
	if not u._senses._player_valid() or not _in_swing_band():
		return
	if u._player.has_method("take_hit") and not _player_dodges():
		_udar_fx(u._weapons._bullet_type)
		u._player.take_hit(HitInfo.melee_hit(melee_damage, u))
	if u._zlo > 0.0 and u._rage > 80.0:
		u._rage = maxf(0.0, u._rage - 25.0)

func _in_swing_band() -> bool:
	if not u._senses._player_valid():
		return false
	if _contact_bite:
		if u._senses._target_distance() > _attack_reach:
			return false
		return _boxes_touch()
	var dx := absf(u._player.global_position.x - u.global_position.x)
	var dy := u._player.global_position.y - u.global_position.y
	if dx > _swing_x:
		return false
	if dy >= 0.0:
		return dy <= _swing_below
	return -dy <= _swing_above

func _boxes_touch() -> bool:
	var mine := u._body_size(u)
	var theirs := u._body_size(u._player)
	var dx := absf(u._player.global_position.x - u.global_position.x)
	if dx > (mine.x + theirs.x) * 0.5:
		return false
	var dy := u._player.global_position.y - u.global_position.y
	return -mine.y < dy and dy - theirs.y < 0.0



func _udar_fx(damage_type: String) -> void:
	preload("res://scripts/impact_fx.gd").udar_unit(u.get_tree(), u._body_center(u._player), u._body_center(u), damage_type)

func _melee_try() -> void:
	# WeaponAttack: chance per tick inside the weapon's reach. Scorpions leap at a target above.
	# A raider's levitated swing stops while shocked (stopsWhenShocked).
	if u._attack_cd > 0.0 or _windup_left > 0.0:
		return
	if u._raider_type and u._shok > 0:
		return
	if not _in_swing_band():
		return
	var swung := false
	for _i in u._frame_ticks:
		if Rng.randf(&"combat") < _swing_chance:
			swung = true
			break
	if not swung:
		return
	if _leap_above > 0.0 and u._move._cel_dy < -_leap_above and u.is_on_floor():
		u._move._do_jump(1.0)
		u.velocity.x = 0.0
	_melee_swing()



## Unit.udarUnit returns at once while the target's neujaz runs: no hit, no udar sound.
func _player_dodges() -> bool:
	if u._player.has_method("can_be_hit") and not bool(u._player.call("can_be_hit")):
		return true
	return u._player.has_method("dodge_roll") and bool(u._player.call("dodge_roll"))

func _ram_hit() -> void:
	# BodyAttack.attKorp when the boxes overlap. The player's own invuln spaces the hits.
	if not u._senses._player_valid():
		return
	if _ram_x > 0.0 and absf(u._move._cel_dx) > _ram_x:
		return
	if _ram_y > 0.0 and absf(u._move._cel_dy) > _ram_y:
		return
	if not _boxes_touch():
		return
	if u._player.has_method("take_hit") and not _player_dodges():
		var dmg := _body_damage if _body_damage > 0 else melee_damage
		_udar_fx(u._weapons._bullet_type)
		u._player.take_hit(HitInfo.melee_hit(dmg, u))
	if _bite_hop > 0.0 and u.is_on_floor():
		u._move._do_jump(_bite_hop)



func _body_bite() -> void:
	if _body_damage <= 0 or _body_cd > 0.0 or not u._senses._player_valid():
		return
	if u.ai_state == u.ST_HOLD and not u._show_attack:
		return
	if not _boxes_touch():
		return
	_body_cd = u._ticks(10.0 / u.TPS)
	if u._player.has_method("take_hit") and not _player_dodges():
		_udar_fx("DAM_BITE")
		u._player.take_hit(HitInfo.melee_hit(_body_damage, u, "DAM_BITE"))

func _maybe_smash() -> void:
	if not _smash or not u.wall_check.is_colliding():
		return
	if u.ai_state != u.ST_CHASE and u.ai_state != u.ST_SEARCH:
		return
	if u._senses._player_valid() and absf(u._player.global_position.y - u.global_position.y) > 80.0:
		return
	var body := u.wall_check.get_collider()
	if body is Node and (body as Node).has_method("take_hit"):
		var dmg := 5000 if u.hp <= int(round(float(u.max_hp) * 0.3)) else 1000
		(body as Node).take_hit(HitInfo.melee_hit(dmg, u, "DAM_BLUNT"))

