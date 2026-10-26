extends RefCounted

## UnitPlayer.alicornOn / alicornOff (script alicorn 1 / 0, stablePi4 and vse).
## GameContainer.alicorn is ScriptsEngine.alicorn. The effs.xml "alicorn"
## parameters (flight, maxhp, speed, damage) ride on a forever effect, which
## is what Pers.setParameters reads while the flag is up.

const WEAPONS: PackedStringArray = ["a_melee", "a_fire", "a_energ", "a_expl", "a_magic"]
const VISUAL := "ali"


## eff false is the quiet re-apply after a load (UnitPlayer init).
static func on(eff := true) -> void:
	ScriptsEngine.alicorn = true
	Inventory.unworn()
	for id in WEAPONS:
		if Inventory.count(id) <= 0:
			Inventory.add(id, 1)
	Pets.uncall_pet()
	Effects.addictions.clear()
	for e in Effects.player_effects():
		Effects.remove(null, str(e.get("id", "")))
	GameState.rad = 0.0
	Effects.cut = 0.0
	Effects.poison = 0.0
	GameState.heal_raw(1000000.0)
	GameState.heal_organs(1000000.0)
	GameState.heal_blood(1000000.0)
	GameState.mana_hp = GameState.mana_max()
	var rec: Dictionary = Effects.add(null, "alicorn", -1, 1.0, 0.0, false)
	if not rec.is_empty():
		rec["forever"] = true
	Inventory._push_armor(VISUAL)
	if eff:
		var player := Inventory.get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			UnitFx.emit(player.get_tree(), "redray", player.global_position - Vector2(0, 39), {"kol": 40})
		SfxBank.play("al_armor")


## changeWeapon("not", true): the a_* weapons stay in the bag, locked (Inventory.alicorn_locked).
static func off() -> void:
	ScriptsEngine.alicorn = false
	Effects.remove(null, "alicorn")
	Inventory.holster()
	Inventory._push_armor("")
