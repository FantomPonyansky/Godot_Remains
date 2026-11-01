extends Area2D

## Trigger, spike trap or bonus pickup. enabled/taken/cool are the live state.
## mess, actions and the rect stay meta: they are the placed row, not a change.

const _PS := preload("res://scripts/prop_state.gd")

var eid := ""
var kind: StringName = &"area"
var authority: bool = true
var faction := 0
var _fields_live := false
var _field_set: Dictionary = {}
var enabled := true
var once := false
var allact := ""
var allid := ""
var taken := false
var cool := 0.0
var damage := 0
var ceiling := false


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
