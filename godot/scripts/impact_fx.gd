extends RefCounted

## What a shot or a blow leaves where it lands.
## popadalo: Bullet.popadalo sparks and flare.
## sound: Bullet.sound / hitSound, one material clip per 3-6 ticks across all shots.
## dyrka / tile_die: Grafon.dyrka and Grafon.tileDie decals, kept per wall span.

const _WeaponVis := preload("res://scripts/weapon_vis.gd")
const _WeaponFx := preload("res://scripts/weapon_fx.gd")
const _Resistances := preload("res://scripts/resistances.gd")

## E_Material.
const NONE := 0
const METAL := 1
const STONE := 2
const WOOD := 3
const BRICK := 4
const GLASS := 5
const EARTH := 6
const FORCE_FIELD := 7
const MEAT := 10
const SLIME := 12

## E_Decal.
const BULLET_SMALL := 1
const BULLET_MEDIUM := 2
const BULLET_LARGE := 3
const BLOW_SMALL := 4
const BLOW_MEDIUM := 5
const BLOW_LARGE := 6
const EXPLOSION := 9
const FIRE := 11
const LASER := 12
const LASER_SMALL := 13
const PLASMA := 15
const PLASMA_BLUE := 16
const PLASMA_PINK := 17
const CRYO := 18
const ENERGY_EXPLOSION := 19

const _SURFACE := {
	"metal": METAL, "stone": STONE, "wood": WOOD, "brick": BRICK,
	"glass": GLASS, "earth": EARTH, "force": FORCE_FIELD,
}
## objs.xml units whose class sets mat = METAL (UnitAIRobot, UnitTurret, UnitDron, ...),
## under both the original ids and the ids the port spawns them with.
const _METAL_UNITS := [
	"bossalicorn", "turret", "landturret", "armturret", "hturret", "hturret2", "wturret",
	"cturret", "bossturret", "robot", "robobrain", "protect", "gutsy", "eqd", "sentinel",
	"roller", "spritebot", "vortex", "dron", "msp", "trap", "trcans", "trridge", "trplate",
	"trlaser", "trigcans", "trigridge", "trigplate", "triglaser", "damshot", "damgren",
	"damexpl", "expl1", "stolp", "destr", "ttur",
]
const _SLIME_UNITS := ["slime", "cryoslime", "pinkslime"]
const _DECALS := "res://assets/sprites/decals/"
const _HARDLIGHT := "res://assets/shaders/blend_hardlight.gdshader"
const _ERASE := "res://assets/shaders/wall_erase.gdshader"
const TICK_MS := 1000.0 / 30.0

static var _hit_ready_at := 0
static var _table: Dictionary = {}
static var _textures: Dictionary = {}
static var _materials: Dictionary = {}


static func surface(name: String) -> int:
	return int(_SURFACE.get(name.to_lower(), NONE))


static func surface_of(node: Object) -> int:
	if node is Node and (node as Node).has_meta("surface"):
		return surface(str((node as Node).get_meta("surface")))
	return NONE


## Unit.udarBullet: a hit that does nothing sounds and sparks like metal.
static func unit_material(node: Node, damage_type: String) -> int:
	var res := _Resistances.of(node)
	if res != null and damage_type != "" and res.multiplier_for(damage_type) <= 0.0:
		return METAL
	var id := str(node.get_meta("unit_id", "")).strip_edges().to_lower()
	if id == "":
		id = String(node.name).to_lower().get_slice("@", 0)
	if id in _METAL_UNITS:
		return METAL
	if id in _SLIME_UNITS:
		return SLIME
	return MEAT


static func popadalo(tree: SceneTree, at: Vector2, mat: int, tip: int, damage: float, flare: String) -> void:
	if tip >= BULLET_SMALL and tip <= BLOW_LARGE:
		if mat == METAL or mat == STONE or mat == GLASS or mat == FORCE_FIELD:
			_WeaponFx.sparks(tree, at, mini(randi_range(0, 5) + int(damage / 5.0), 20))
			_WeaponFx.flare(tree, at, flare)
	elif flare != "" and mat != NONE:
		_WeaponFx.flare(tree, at, flare)


static func sound(mat: int, damage_type: String, weapon_id: String, tip: int) -> void:
	var clip := ""
	var volume := 0.5
	match mat:
		METAL:
			clip = "hit_metal"
			volume = 0.4
		STONE, BRICK, EARTH:
			clip = "hit_concrete"
		WOOD:
			clip = "hit_wood"
		GLASS:
			clip = "hit_glass"
		FORCE_FIELD:
			clip = "hit_pole"
		MEAT:
			if damage_type == "DAM_PIERCE":
				clip = "hit_bullet"
				volume = 0.8
			elif damage_type == "DAM_CUT":
				clip = "hit_blade"
				volume = 0.8
			else:
				clip = "hit_flesh"
		SLIME:
			clip = "hit_slime"
	hit_sound(clip, volume, weapon_id, tip)


## Unit.udarUnit: a body attack lands; the part and Sound.ps follow the attacker's tipDamage.
static func udar_unit(tree: SceneTree, victim: Vector2, attacker: Vector2, damage_type: String) -> void:
	var mid := (victim + attacker) * 0.5
	match damage_type:
		"DAM_ELECTRIC":
			UnitFx.emit(tree, "moln", victim)
			SfxBank.play("electro")
		"DAM_ACID":
			UnitFx.emit(tree, "buma", mid)
			SfxBank.play("acid")
		"DAM_DEATH":
			_WeaponFx.flare(tree, mid, "bumn")
			SfxBank.play("hit_necr")
		"DAM_BITE":
			_WeaponFx.flare(tree, mid, "bum")
			SfxBank.play("fang_hit")
		_:
			_WeaponFx.flare(tree, mid, "bum")
			SfxBank.play("hit_flesh")


static func hit_sound(clip: String, volume: float, weapon_id: String, tip: int) -> void:
	var own := str(_WeaponVis.fx(weapon_id).get("snd_hit", "")) if weapon_id != "" else ""
	if own != "":
		SfxBank.play(own)
	if tip < BULLET_SMALL or tip > BLOW_LARGE:
		return
	var now := Time.get_ticks_msec()
	if now < _hit_ready_at:
		return
	if clip != "":
		SfxBank.play(clip, volume)
	_hit_ready_at = now + int(randi_range(3, 6) * TICK_MS)


## Grafon.dyrka on the span that was hit and every span the decal reaches.
static func dyrka(wall: Node, at: Vector2, tip: int, mat: int, soft: bool, ver: float) -> void:
	if tip == NONE or mat == NONE:
		return
	var erase := ""
	var draw := ""
	var blend := "normal"
	var sc := randf() * 0.5 + 0.5
	var rc := randf() * 360.0
	match mat:
		METAL:
			if tip >= BULLET_SMALL and tip <= BLOW_LARGE:
				draw = "bullet_metal"
			elif tip == EXPLOSION and not soft and randf() * 0.5 < ver:
				draw = "metal_tre"
		STONE, BRICK, EARTH, WOOD:
			if tip >= BULLET_SMALL and tip <= BULLET_LARGE:
				if mat == WOOD:
					erase = "bullet_dyr"
					draw = "bullet_wood"
					rc = 0.0
				else:
					if tip != BULLET_SMALL and randf() > 0.5:
						erase = "bullet_dyr"
					draw = "bullet_tre"
				sc += 0.5 * float(tip - BULLET_SMALL)
			elif tip >= BLOW_SMALL and tip <= BLOW_LARGE:
				if not soft:
					draw = "punch_tre"
				sc += 0.5 * float(tip - BLOW_SMALL)
			elif tip == EXPLOSION and not soft and randf() * 0.5 < ver:
				draw = "expl_tre"
	if wall.is_inside_tree():
		if mat == FORCE_FIELD:
			UnitFx.emit(wall.get_tree(), "pole", at, {"kol": 5})
		elif tip <= EXPLOSION and not soft and mat in [STONE, BRICK, EARTH, WOOD]:
			var chip := "schepoch" if mat == WOOD else ("kusoch" if mat == STONE else "kusochB")
			UnitFx.emit(wall.get_tree(), chip, at, {"kol": 3})
	match tip:
		FIRE:
			if randf() < 0.1:
				draw = "fire_soft"
		LASER, LASER_SMALL:
			draw = "fire_soft" if soft and randf() * 0.2 > ver else "laser_tre"
			if tip == LASER_SMALL:
				sc *= 0.6
			blend = "hardlight"
		PLASMA, PLASMA_BLUE, PLASMA_PINK:
			if soft:
				draw = "plasma_soft" if tip == PLASMA else "fire_soft"
			else:
				erase = "plasma_dyr"
				draw = {PLASMA: "plasma_tre", PLASMA_BLUE: "bluplasma_tre", PLASMA_PINK: "pinkplasma_tre"}[tip]
			blend = "hardlight"
		CRYO:
			draw = "cryo_soft"
			blend = "hardlight"
		ENERGY_EXPLOSION:
			if not soft and randf() * 0.5 < ver:
				draw = "plaexpl_tre"
	if erase == "" and draw == "":
		return
	place(wall, decal(erase, draw, at, sc, deg_to_rad(rc), blend))


## Grafon.tileDie for a cell that just broke. Force fields leave no scorch.
static func tile_die(wall: Node, at: Vector2, tip: int, mat: int, fake: bool = false) -> void:
	var erase := "block_dyr"
	var draw := "block_tre"
	# Tile.isFakeWall (Area tilehp <= 1): it crumbles to dust, no debris.
	if fake:
		if wall.is_inside_tree():
			UnitFx.emit(wall.get_tree(), "fake", at)
		place(wall, decal(erase, "block_bur", at, 1.0, 0.0, "hardlight"))
		return
	if wall.is_inside_tree():
		var tree := wall.get_tree()
		if mat == FORCE_FIELD:
			UnitFx.emit(tree, "pole", at, {"kol": 10, "rx": 40, "ry": 40})
		elif tip <= EXPLOSION and mat >= METAL and mat <= EARTH:
			var chunk: String = ["", "metal", "kusok", "schep", "kusokB", "steklo", "kusokD"][mat]
			UnitFx.emit(tree, chunk, at, {"kol": 6, "rx": 40, "ry": 40})
	if mat == FORCE_FIELD:
		draw = ""
	elif tip >= PLASMA:
		erase = "block_plav"
		draw = "block_pla"
	elif tip >= FIRE and tip <= LASER_SMALL:
		draw = "block_bur"
	place(wall, decal(erase, draw, at, 1.0, 0.0, "hardlight"))


static func decal(erase: String, draw: String, at: Vector2, sc: float, rot: float, blend: String) -> Dictionary:
	return {
		"erase": erase, "draw": draw, "at": at, "sc": sc, "rot": rot, "blend": blend,
		"ef": _frame(erase), "df": _frame(draw),
	}


## The world rect the decal can touch, rotation included.
static func reach(rec: Dictionary) -> Rect2:
	var half := 0.0
	for key in ["erase", "draw"]:
		var info := _info(str(rec[key]))
		if info.is_empty():
			continue
		var cell: Array = info.cell
		half = maxf(half, Vector2(float(cell[0]), float(cell[1])).length())
	half *= float(rec.sc)
	var at: Vector2 = rec.at
	return Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0)


## Wall spans are siblings under the land's solids node.
static func place(wall: Node, rec: Dictionary) -> void:
	var parent := wall.get_parent()
	if parent == null:
		return
	var area := reach(rec)
	for node in parent.get_children():
		if node.has_method("add_decal") and node.call("decal_rect").intersects(area):
			node.call("add_decal", rec)


## One decal: the erase shape showing the back wall, then the drawn mark.
static func build(rec: Dictionary, back: Texture2D) -> Node2D:
	var root := Node2D.new()
	root.position = rec.at
	root.rotation = float(rec.rot)
	root.scale = Vector2.ONE * float(rec.sc)
	var erase := str(rec.erase)
	if erase != "" and back != null:
		var hole := _sprite(erase, int(rec.ef))
		if hole != null:
			var mat := ShaderMaterial.new()
			mat.shader = load(_ERASE)
			mat.set_shader_parameter("back", back)
			mat.set_shader_parameter("back_size", back.get_size())
			hole.material = mat
			root.add_child(hole)
	var draw := str(rec.draw)
	if draw != "":
		var mark := _sprite(draw, int(rec.df))
		if mark != null:
			if str(rec.blend) == "hardlight":
				mark.material = _hardlight()
			root.add_child(mark)
	return root


static func _sprite(name: String, frame: int) -> Sprite2D:
	var info := _info(name)
	var tex := _texture(name)
	if info.is_empty() or tex == null:
		return null
	var cell: Array = info.cell
	var anchor: Array = info.anchor
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(float(cell[0]) * frame, 0.0, float(cell[0]), float(cell[1]))
	sprite.offset = -Vector2(float(anchor[0]), float(anchor[1]))
	return sprite


static func _frame(name: String) -> int:
	var info := _info(name)
	if info.is_empty():
		return 0
	return randi() % maxi(int(info.frames), 1)


static func _info(name: String) -> Dictionary:
	if name == "":
		return {}
	if _table.is_empty():
		var path := _DECALS + "decals.json"
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_table = parsed
	var info: Variant = _table.get(name, {})
	return info if info is Dictionary else {}


static func _texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var path := _DECALS + name + ".png"
		_textures[name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[name] as Texture2D


static func _hardlight() -> Material:
	if not _materials.has("hardlight"):
		var mat := ShaderMaterial.new()
		mat.shader = load(_HARDLIGHT)
		_materials["hardlight"] = mat
	return _materials["hardlight"] as Material
