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
			Fx.particles("expl", at)
			Fx.particles("sparkleexpl", at)
			Fx.particles("iskr", at, {"kol": 16})
			UnitFx.snd("bale_e")
		return
	if own != "":
		Fx.particles(own, at)
		return
	match damage_type:
		"DAM_EMP":
			Fx.particles("impexpl", at)
			UnitFx.snd("emp_e")
		"DAM_COLD":
			Fx.particles("iceexpl", at)
			Fx.particles("snow", at, {"kol": 16})
			UnitFx.snd("cryo_e")
		"DAM_PLASMA":
			Fx.particles("plaexpl", at)
			UnitFx.snd("exppla_e")
		"DAM_VENOM":
			Fx.particles("gas", at)
			UnitFx.snd("gas_e")
		"DAM_PINKCLOUD":
			Fx.particles("pinkgas", at)
			UnitFx.snd("gas_e")
		"DAM_ACID":
			Fx.particles("acidexpl", at)
			Fx.particles("acidkap", at, {"kol": Rng.randi_range(&"fx", 30, 34)})
			UnitFx.snd("acid_e")
		"DAM_BALEFIRE":
			Fx.particles("balefire", at + Vector2(0, -60))
			Fx.particles("baleblast", at)
			UnitFx.snd("bale_e")
		"DAM_EXPLOSION":
			if in_water:
				_underwater(tree, at)
			else:
				Fx.particles("expl", at)
				Fx.particles("flare", at)
				Fx.particles("iskr", at, {"kol": 16})
				UnitFx.snd("expl_e")
		"DAM_BURN":
			if not in_water:
				Fx.particles("fireexpl", at)
				Fx.particles("flare", at)
				Fx.particles("iskr", at, {"kol": 16})
				UnitFx.snd("fire_e")


static func _underwater(_tree: SceneTree, at: Vector2) -> void:
	Fx.particles("explw", at)
	Fx.particles("bubble", at, {"kol": 30, "rx": 100, "ry": 100})
	UnitFx.snd("expl_uw")
