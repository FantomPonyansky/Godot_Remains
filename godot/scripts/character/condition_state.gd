extends RefCounted

## One character's condition fields (architecture step R3.1).
## condition.gd forwards a property of the same name to each.

var _hp: Dictionary = {}
var _armor_lvl: Dictionary = {}
var _shot_ok: bool = false
var _wore_shot: bool = false
var _said: Dictionary = {}
