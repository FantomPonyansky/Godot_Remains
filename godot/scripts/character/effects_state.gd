extends RefCounted

## One character's effects fields (architecture step R3.1).
## effects.gd forwards a property of the same name to each.

var cut: float = 0.0
var poison: float = 0.0
var stun: int = 0
var addictions: Dictionary = {}
var curse_trigger: int = 0
var _list: Array = []
var _ops: Dictionary = {}
var _res: Dictionary = {}
var _dirty: bool = true
var _t_hp: int = 0
var _bleed_carry: float = 0.0
var _poison_carry: float = 0.0
var _fet: Vector2 = Vector2.ZERO
var _tinted: bool = false
var _auto_attack: bool = false
var _vote_aim: bool = false
var _vote_cel: Vector2 = Vector2.ZERO
