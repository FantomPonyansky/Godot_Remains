extends RefCounted

## One character's progression fields (architecture step R3.1).
## progression.gd forwards a property of the same name to each.

var level: int = 1
var xp: int = 0
var xp_next: int = 5000
var skill_points: int = 0
var perk_points: int = 0
var xp_delta: int = 5000
var level_sk_add: int = 5
var rndpump: bool = false
var _perk_extra: int = 0
var _applied_max: int = 0
var _ranks: Dictionary = {}
var _perks: Dictionary = {}
