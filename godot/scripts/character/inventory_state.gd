extends RefCounted

## One character's inventory fields (architecture step R3.1).
## inventory.gd forwards a property of the same name to each.

var worn: String = ""
var amulet: String = ""
var weapon_id: String = ""
var spell_id: String = ""
var leg_pip: bool = false
var kit_granted: bool = false
var _counts: Dictionary = {}
var _order: Array[String] = []
var _applied_player: int = 0
var _overload_t: int = 0
var _max_speed: float = 100.0
var _jump_mult: float = 1.0
var _mana_res: float = 1.0
