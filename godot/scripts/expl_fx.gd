extends RefCounted
## Bullet.explVis: the particles and Sound.ps of a blast, by the weapon's
## vis visexpl (weapons.xml) or else by the blast's damage type.

## weapons.xml <vis visexpl=...> rows.
const VISEXPL := {"incin": "react", "spgren": "sparkle", "eclipse": "eclipse", "ttweap4": "ttexpl", "ttweap5": "ttplaexpl"}


static func vis(tree: SceneTree, at: Vector2, damage_type: String, weapon_id: String, in_water: bool) -> void:
	if tree == null:
		return
	var own := str(VISEXPL.get(weapon_id, ""))
	if own == "sparkle":
		if in_water:
			_underwater(tree, at)
		else:
			UnitFx.emit(tree, "expl", at)
			UnitFx.emit(tree, "sparkleexpl", at)
			UnitFx.emit(tree, "iskr", at, {"kol": 16})
			UnitFx.snd("bale_e")
		return
	if own != "":
		UnitFx.emit(tree, own, at)
		return
	match damage_type:
		"DAM_EMP":
			UnitFx.emit(tree, "impexpl", at)
			UnitFx.snd("emp_e")
		"DAM_COLD":
			UnitFx.emit(tree, "iceexpl", at)
			UnitFx.emit(tree, "snow", at, {"kol": 16})
			UnitFx.snd("cryo_e")
		"DAM_PLASMA":
			UnitFx.emit(tree, "plaexpl", at)
			UnitFx.snd("exppla_e")
		"DAM_VENOM":
			UnitFx.emit(tree, "gas", at)
			UnitFx.snd("gas_e")
		"DAM_PINKCLOUD":
			UnitFx.emit(tree, "pinkgas", at)
			UnitFx.snd("gas_e")
		"DAM_ACID":
			UnitFx.emit(tree, "acidexpl", at)
			UnitFx.emit(tree, "acidkap", at, {"kol": randi_range(30, 34)})
			UnitFx.snd("acid_e")
		"DAM_BALEFIRE":
			UnitFx.emit(tree, "balefire", at + Vector2(0, -60))
			UnitFx.emit(tree, "baleblast", at)
			UnitFx.snd("bale_e")
		"DAM_EXPLOSION":
			if in_water:
				_underwater(tree, at)
			else:
				UnitFx.emit(tree, "expl", at)
				UnitFx.emit(tree, "flare", at)
				UnitFx.emit(tree, "iskr", at, {"kol": 16})
				UnitFx.snd("expl_e")
		"DAM_BURN":
			if not in_water:
				UnitFx.emit(tree, "fireexpl", at)
				UnitFx.emit(tree, "flare", at)
				UnitFx.emit(tree, "iskr", at, {"kol": 16})
				UnitFx.snd("fire_e")


static func _underwater(tree: SceneTree, at: Vector2) -> void:
	UnitFx.emit(tree, "explw", at)
	UnitFx.emit(tree, "bubble", at, {"kol": 30, "rx": 100, "ry": 100})
	UnitFx.snd("expl_uw")
