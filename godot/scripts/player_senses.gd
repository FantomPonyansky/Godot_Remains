extends RefCounted
## How hidden the player is, and whether a hit lands.
## Lurk, lurk_cut, dexter_now, can_be_hit and dodge_roll.
## p is the player body. Tick order stays in player.gd; these names forward.

const _Body := preload("res://scripts/player.gd")

var p: _Body

func _init(host: _Body) -> void:
	p = host

var _lurked := false

var _lurk_tip := 0

var _lurk_box: Node2D = null

var _lurk_raised: Node2D = null

var _lurk_box_at := Vector2.ZERO

var _lurk_x := 0.0

var _lurk_work := ""

var _lurk_t := 0

var _lurk_up_t := 0

## UnitPlayer lurk: a short tap of up while standing hides in a box (Box.lurk
## 1 niche, 2 beside its edge, 3 behind) or between two hiding-spot tiles.
## Returns true while the hide or its exit owns the movement keys.
func _tick_lurk(_delta: float, key_left: bool, key_right: bool, up: bool, down: bool, jump_just: bool) -> bool:
	var ticks := Sim.frame_steps
	if _lurk_work != "":
		_lurk_t -= ticks
		if _lurk_work == "lurk":
			p.velocity.x = 0.0
			p.global_position.x = move_toward(p.global_position.x, _lurk_x, 4.0 * ticks)
			if _lurk_t <= 10.0:
				_lurk_layer(true)
		else:
			p.velocity.x = 0.0
			if _lurk_t <= 5.0:
				_lurk_layer(false)
		if _lurk_t <= 0.0:
			_lurk_work = ""
		return true
	if _lurked:
		var box_moved := _lurk_box != null and (not is_instance_valid(_lurk_box) or _lurk_box.global_position.distance_to(_lurk_box_at) > 2.0)
		if not p.is_on_floor() or absf(p.global_position.x - _lurk_x) > 10.0 or box_moved:
			_lurk_lose()
			return false
		if up or down or jump_just:
			_unlurk()
			return true
		if (key_left or key_right) and (_lurk_tip == 1 or _lurk_tip == 3):
			p.facing = -1.0 if key_left else 1.0
		p.velocity.x = 0.0
		return true
	var stay: bool = p.is_on_floor() and not p._climbing and not p._move._levitating
	if stay and up:
		_lurk_up_t += 1
	else:
		if _lurk_up_t > 0 and _lurk_up_t <= 7 and not key_left and not key_right:
			_try_lurk()
		if not up:
			_lurk_up_t = 0
	return false

func _try_lurk() -> void:
	_lurk_tip = 0
	if not p.is_on_floor() or p._sit or absf(p.velocity.x) >= 150.0 or _lurk_work != "":
		return
	var feet := p.global_position
	_lurk_box = null
	var best_rect := Rect2()
	for node in _lurk_candidates():
		var id := str(node.get_meta("id", ""))
		var tip: int = p._LandRegistry.int_of(p._LandRegistry.obj(id).get("lurk"), 0) if id != "" else 0
		if tip <= _lurk_tip:
			continue
		var rect := _lurk_rect(node)
		if feet.x > rect.position.x and feet.x < rect.end.x and feet.y - 10.0 > rect.position.y and feet.y - 10.0 < rect.end.y:
			_lurk_tip = tip
			_lurk_box = node
			best_rect = rect
	if _lurk_box != null:
		_lurk_box_at = _lurk_box.global_position
		if _lurk_tip == 2:
			if feet.x > best_rect.get_center().x:
				p.facing = 1.0
				_lurk_x = best_rect.end.x - 10.0
			else:
				p.facing = -1.0
				_lurk_x = best_rect.position.x + 10.0
		else:
			_lurk_x = best_rect.get_center().x
	elif p._Flags.hiding_at(feet + Vector2(-20.0, -10.0)) and p._Flags.hiding_at(feet + Vector2(20.0, -10.0)):
		_lurk_tip = 1
		_lurk_x = roundf(feet.x / 40.0) * 40.0
	else:
		var quick := p.get_node_or_null("QuickKeys")
		if quick != null and quick.has_method("armor_ability"):
			quick.call("armor_ability")
		return
	p.velocity.x = 0.0
	_lurk_t = 20
	_lurk_work = "lurk"
	_lurked = true
	p.set_meta("foe_detecting", 0.0)
	p.set_meta("foe_vis_mult", 0.5)

## Unit.observation: the share of pers.sneakLurk taken off a looker's view (sitting is a fifth).
func lurk_cut() -> float:
	if _lurked:
		return 1.0
	if p._sit:
		return 0.2
	return 0.0

## Unit.udarBullet dexter + dexterPlus (sitDexterPlus 0.3, lurkDexterPlus 2). 0 is always hit.
func dexter_now() -> float:
	var dex := Progression.player_dexter() if Progression != null else 1.0
	if dex <= 0.0:
		return 0.0
	if _lurked:
		return dex + 2.0
	if p._sit:
		return dex + 0.3
	return dex

## Unit.udarUnit: a body or club hit misses on rnd < dodge (1 + dodgePlus while dashing).
func can_be_hit() -> bool:
	return p._invuln <= 0.0 and not p.control_off and Sim.run_tick >= _dodge_until

## udarUnit sets neujaz before the roll, so a dodged contact is not rolled again at once.
func dodge_roll() -> bool:
	if Sim.run_tick < _dodge_until:
		return true
	if p._invuln > 0.0:
		return false
	var dodge := Progression.player_dodge_plus() if Progression != null else 0.0
	if p._move._kdash_left > 0.0:
		dodge += 1.0
	if dodge > 0.0 and Rng.randf(&"combat") < dodge:
		# run_tick stands still while paused, so the window survives the PipBuck.
		var ms := int(GameState.hit_invuln_time() * 1000.0)
		_dodge_until = Sim.run_tick + Sim.ticks_from_ms(ms)
		return true
	return false

## Sim.run_tick when the dodge window ends. Paused ticks do not spend it.
var _dodge_until := 0

func _lurk_candidates() -> Array:
	var out: Array = []
	for group in ["floor_box", "levitatable", "tk_use"]:
		for node in p.get_tree().get_nodes_in_group(group):
			if node is Node2D and node.has_meta("id") and not out.has(node):
				out.append(node)
	for props in p.get_tree().get_nodes_in_group("land_props"):
		for node in props.get_children():
			if node is Node2D and node.has_meta("id") and not out.has(node):
				out.append(node)
	return out

func _lurk_rect(node: Node2D) -> Rect2:
	if node.has_meta("feet") and node.has_meta("size"):
		var size: Vector2 = node.get_meta("size")
		var at: Vector2 = node.get_meta("feet")
		if not node is PhysicsBody2D:
			return Rect2(at - Vector2(size.x * 0.5, size.y), size)
	return p._aim_rect(node)

func _unlurk() -> void:
	if _lurked and p.is_on_floor():
		_lurk_t = 10
		_lurk_work = "unlurk"
	else:
		_lurk_layer(false)
	_lurk_end()

func _lurk_lose() -> void:
	_lurk_layer(false)
	_lurk_end()

func _lurk_end() -> void:
	_lurked = false
	_lurk_box = null
	p.remove_meta("foe_detecting")
	p.remove_meta("foe_vis_mult")

## chSloy(0) for lurk 1 puts the pony under the objects (a hiding-spot niche also
## under the wall patches). For 2 and 3 it stays on the unit layer and the box goes
## to the top of it.
func _lurk_layer(hidden: bool) -> void:
	var box := _lurk_box if is_instance_valid(_lurk_box) else null
	if p.puppet != null and p.puppet.has_method("set_flat_layers"):
		p.puppet.set_flat_layers(hidden)
	if not hidden:
		p.z_index = 0
		if is_instance_valid(_lurk_raised) and _lurk_raised.has_meta("lurk_z"):
			_lurk_raised.z_index = int(_lurk_raised.get_meta("lurk_z"))
			_lurk_raised.remove_meta("lurk_z")
		_lurk_raised = null
		return
	if _lurk_tip != 1:
		p.z_index = 0
		if box != null and not box.has_meta("lurk_z"):
			box.set_meta("lurk_z", box.z_index)
			box.z_index = maxi(box.z_index, 4)
			_lurk_raised = box
	else:
		p.z_index = -4 if box != null else -9

