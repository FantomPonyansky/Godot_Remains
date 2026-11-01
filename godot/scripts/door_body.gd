extends StaticBody2D

const _Art := preload("res://scripts/door_art.gd")
const _PS := preload("res://scripts/prop_state.gd")

var eid := ""
var kind: StringName = &"door"
var authority: bool = true
var faction := 0
var _fields_live := false
var _field_set: Dictionary = {}
var door_open := false
var lock := 0.0
var hp := 0
var thre := 0
var breakable := false
var dead := false
var usable := true
var blocks_sight := true
var mine := 0
var hackable := false
var locktip := 1
var lock_hp := 10.0
var lock_level := 0
var lock_att := -100
var mine_tip := 3
var allact := ""
var allid := ""
var once := 0
var act_time := 0
var lock_key := ""
var keyloss := 0
var fun := ""
var sec := false
var user_action := ""
var hold_use := false


func _ready() -> void:
	_PS.absorb(self)
	if breakable:
		add_to_group("destructibles")


## amount is char_destroy (block damage), not hit-point damage.
## Tile.udar: thre > hit does nothing. Otherwise the full hit comes off HP.
## Box.damage subtracts thre first; doors do not use that path.
## EMP ammo forces destroy to 0 (Weapon.setBullet).
func take_hit(hit: HitInfo) -> void:
	if hit == null or dead or not breakable:
		return
	if door_open:
		return
	var dmg := int(round(hit.amount))
	if hit.tip == "DAM_EMP":
		dmg = 0
	if thre > dmg or dmg <= 0:
		return
	var left := hp - dmg
	_PS.put(self, "hp", left)
	if left <= 0:
		_Art.break_open(self)


func snapshot() -> Dictionary:
	return _PS.door_record(self)


func restore(d: Dictionary) -> void:
	if bool(d.get("dead", false)):
		_Art.break_open(self)
		var stand_in := get_node_or_null("StandIn") as CanvasItem
		if stand_in:
			stand_in.visible = false
		return
	if d.has("lock"):
		_PS.put(self, "lock", float(d.lock))
	if d.has("hp"):
		_PS.put(self, "hp", int(d.hp))
	var want := bool(d.get("open", false))
	if want == door_open:
		return
	var props: Node = get_tree().get_first_node_in_group("land_props") if is_inside_tree() else null
	if props != null and props.has_method("_apply_door"):
		props.call("_apply_door", self, want)
	else:
		_Art.apply(self, want)


func land_record() -> Dictionary:
	return snapshot()


func apply_land(d: Dictionary) -> void:
	restore(d)
