class_name UnitBrains
extends RefCounted

## enemies.json "brain" -> the script that runs that Unit* class.
const SCRIPTS := {
	"turret": "res://scripts/units/brain_turret.gd",
	"dron": "res://scripts/units/brain_dron.gd",
	"bat": "res://scripts/units/brain_bat.gd",
	"fish": "res://scripts/units/brain_fish.gd",
	"slime": "res://scripts/units/brain_slime.gd",
	"roller": "res://scripts/units/brain_roller.gd",
	"msp": "res://scripts/units/brain_msp.gd",
	"vortex": "res://scripts/units/brain_vortex.gd",
	"spritebot": "res://scripts/units/brain_spritebot.gd",
	"robot": "res://scripts/units/brain_robot.gd",
	"emitter": "res://scripts/units/brain_emitter.gd",
	"bloat": "res://scripts/units/brain_bloat.gd",
	"destr": "res://scripts/units/brain_destr.gd",
	"transmitter": "res://scripts/units/brain_transmitter.gd",
	"thunderhead": "res://scripts/units/brain_thunderhead.gd",
	"thunder_turret": "res://scripts/units/brain_thunder_turret.gd",
	"pet": "res://scripts/units/brain_pet.gd",
	"wild_phoenix": "res://scripts/units/brain_wild_phoenix.gd",
	"mine": "res://scripts/units/brain_mine.gd",
	"boss_raider": "res://scripts/units/brain_boss_raider.gd",
	"boss_ultra": "res://scripts/units/brain_boss_ultra.gd",
	"boss_necr": "res://scripts/units/brain_boss_necr.gd",
	"boss_dron": "res://scripts/units/brain_boss_dron.gd",
	"boss_alicorn": "res://scripts/units/brain_boss_alicorn.gd",
	"scythe": "res://scripts/units/brain_scythe.gd",
}

static var _loaded := {}


static func make(brain: String) -> UnitBrain:
	if brain == "" or not SCRIPTS.has(brain):
		return null
	var script: Script = _loaded.get(brain)
	if script == null:
		if not ResourceLoader.exists(SCRIPTS[brain]):
			return null
		script = load(SCRIPTS[brain]) as Script
		if script == null:
			return null
		_loaded[brain] = script
	return script.new() as UnitBrain
