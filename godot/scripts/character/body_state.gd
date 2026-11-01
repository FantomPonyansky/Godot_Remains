extends RefCounted

## One character's game_state fields (ARCHITECTURE_PLAN R3.1).
## game_state.gd forwards a property of the same name to each.

const _Host := preload("res://scripts/autoload/game_state.gd")

var health: int = _Host.MAX_HEALTH
var ammo: int = _Host.MAX_AMMO
var magic: float = _Host.MAX_MAGIC
var mana_hp: float = 400.0
var weapon_name: String = ""
var score: int = 0
var t_battle: float = 0.0
var magic_locked: bool = false
var _dmana: float = 0.0
var _channel_magic: float = 0.0
var _channel_levit: bool = false
var _channel_until: int = 0
var _mana_stage: int = 0
var _shown_magic: int = _Host.MAX_MAGIC
var head_hp: float = 200.0
var torso_hp: float = 200.0
var legs_hp: float = 200.0
var organ_target: String = ""
var blood_hp: float = 200.0
var rad: float = 0.0
var stam: float = 1000.0
var breath: float = 1000.0
var _head_stage: int = 0
var _torso_stage: int = 0
var _legs_stage: int = 0
var _blood_stage: int = 0
var _seen_level: int = -1
var _dead: bool = false
var _running: bool = false
var _swimming: bool = false
var _can_run: bool = true
var _shown: String = ""
var _healhp: float = 0.0
var drad: float = 0.0
var _drad2: float = 0.0
var _hp_carry: float = 0.0
var _dam_carry: float = 0.0
