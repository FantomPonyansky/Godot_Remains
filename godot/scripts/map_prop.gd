extends StaticBody2D

## A begin-land button or explosive. Bullets call take_hit. The land actor node listens.
## Open, lock, loot and alarm flags are fields. Placed actions and art stay meta.

signal triggered

const _PS := preload("res://scripts/prop_state.gd")

var eid := ""
var kind: StringName = &"prop"
var authority: bool = true
var faction := 0
var _fields_live := false
var _field_set: Dictionary = {}
var hp: int = 1
var breaks: bool = false
var lock := 0.0
var dead := false
var usable := true
var spent := false
var opened := false
var box_hp := 0.0
var vis_state := ""
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
var touched := false
var box_open := false
var close_at := 0
var blocks_sight := false
var prize_locked := false


func take_hit(hit: HitInfo) -> void:
	if hit == null:
		return
	if breaks:
		hp -= int(round(hit.amount))
		if hp > 0:
			return
	triggered.emit()
	if breaks:
		queue_free()


func _ready() -> void:
	_PS.absorb(self)


func snapshot() -> Dictionary:
	return _PS.record(self)


func restore(d: Dictionary) -> void:
	_PS.apply_fields(self, d)


func land_record() -> Dictionary:
	return snapshot()


func apply_land(d: Dictionary) -> void:
	restore(d)
