extends RefCounted

## What a land holds when it is entered, as data rows.
## Location constructor buckets (spawnpoint / enspawn / up / objsT), then
## Location.setObjects -> createUnit / createObj, setRandomUnits and
## createHidden, with the difficulty from Land.setLocDif. Generated lands add
## Land.buildRandomLand's createExit / createCheck / newRandomProb /
## createClouds and createXpBonuses. Trial rooms come from Land.buildProbs.
## Unit ids are resolved the way Unit.create and each Unit* constructor do.
##
## Room input: x, y (grid cell in the built map), lx, ly, z (original
## coordinates), objs (already mirrored), options, mirror, and for generated
## lands enemy_type, water, setdoor (Location.setDoor picks) and xp spots.

const Registry := preload("res://scripts/map/land_registry.gd")
const LandGen := preload("res://scripts/map/land_gen.gd")

const TILE := 40
const COLS := 48
const ROWS := 25
const TIP_EN := ["", "enl1", "enl2", "enf1", "enc1", "lov"]

## Unit.create: objs.xml cl -> class. The Unit* constructor then names the units.xml id.
const _RAIDER_KIN := {
	"UnitRaider": ["raider", 9], "UnitSlaver": ["slaver", 6], "UnitZebra": ["zebra", 5],
	"UnitRanger": ["ranger", 3], "UnitEncl": ["encl", 1], "UnitMerc": ["merc", 1],
}
const _FIXED := {
	"UnitRobobrain": "robobrain", "UnitEqd": "eqd", "UnitSentinel": "sentinel",
	"UnitSpriteBot": "spritebot", "UnitVortex": "vortex", "UnitMsp": "msp",
	"UnitCaptive": "captive", "UnitPonPon": "ponpon", "UnitTrain": "training",
	"UnitTransmitter": "transmitter", "UnitNecros": "necros", "UnitSpectre": "spectre",
	"UnitBossRaider": "bossraider", "UnitBossAlicorn": "bossalicorn", "UnitBossUltra": "bossultra",
	"UnitBossNecr": "bossnecr", "UnitBossDron": "bossdron", "UnitBossEncl": "bossencl",
	"UnitThunderHead": "thunderhead",
}
const _BOSS := ["UnitBossRaider", "UnitBossAlicorn", "UnitBossUltra", "UnitBossNecr", "UnitBossDron", "UnitBossEncl", "UnitThunderHead"]
const _NPC := ["UnitNPC", "UnitPonPon", "UnitCaptive", "UnitTrain"]
const _TURRET_TIP := {"land": 1, "wall": 2, "arm": 3, "combat": 4, "boss": 5}
const _MINE_TR := ["", "hmine", "mine", "plamine", "impmine", "zebmine", "balemine"]

## Box ids by what the port does with them.
const _BUTTONS := ["knop1", "knop2", "knop3", "knop4", "detonator", "term", "term1", "term2", "termh", "elpanel", "dsph", "alarm"]
const _STATIONS := ["work", "himlab", "stove", "wmap", "stand", "vault", "table3", "p_luna"]
const _PLATFORMS := ["platform2", "platform3"]
const _CLOUDS := ["tcloud1", "pcloud1"]
const _CRATES := ["woodbox", "box", "mcrate1", "mcrate2", "mcrate3", "mcrate4", "mcrate5", "bigbox", "bigbox2"]
const _SCRIPT_ATTRS := {"scr": "", "scrout": "out", "scropen": "open", "scrclose": "close", "scrtouch": "touch", "scrdie": "die", "alarm": "alarm"}


## ctx: land_id, rnd, conf, biom, land_dif, glob_dif, stage, exit_prob, xp, beg (Vector2i), width, height.
static func plan(ctx: Dictionary, rooms: Array) -> Dictionary:
	var out := {"rows": [], "probs": [], "phoenix": 0, "room_dif": {}}
	var by_cell := {}
	for room_v in rooms:
		var room: Dictionary = room_v
		var loc := _new_loc(ctx, room, "")
		by_cell[_key(room)] = loc
		out.room_dif[Vector2i(int(loc.gx), int(loc.gy))] = float(loc.dif)
	if bool(ctx.get("rnd", false)):
		_plan_random(ctx, rooms, by_cell, out)
	else:
		var order := rooms.duplicate()
		order.sort_custom(_room_before)
		for room_v in order:
			var loc: Dictionary = by_cell[_key(room_v)]
			_set_objects(ctx, loc, out)
	return out


## Land.buildProb: one rooms_prob room, its objects, and the doorout at its first spawn point.
static func plan_prob(ctx: Dictionary, room: Dictionary, prob_id: String, out: Dictionary) -> void:
	var loc := _new_loc(ctx, room, prob_id)
	(out.get("room_dif", {}) as Dictionary)[Vector2i(int(loc.gx), int(loc.gy))] = float(loc.dif)
	_set_objects(ctx, loc, out)
	var info := Registry.prob(str(ctx.land_id), prob_id)
	if not info.is_empty():
		out.rows.append(_row("prob", prob_id, loc, 0, 0, {"prob": info}))
	var points: Array = loc.spawn_points
	if not points.is_empty():
		var sp: Vector2i = points[0]
		_create_obj(ctx, loc, "doorout", "box", sp.x, sp.y, {"prob": "", "uid": "begin"}, [], out)


## Land.buildSpecifLand walks x, then y, then z.
static func _room_before(a: Dictionary, b: Dictionary) -> bool:
	for key in ["lx", "ly", "z"]:
		if int(a.get(key, 0)) != int(b.get(key, 0)):
			return int(a.get(key, 0)) < int(b.get(key, 0))
	return false


static func _key(room: Dictionary) -> String:
	return "%d,%d,%d" % [int(room.get("lx", room.x)), int(room.get("ly", room.y)), int(room.get("z", 0))]


static func _new_loc(ctx: Dictionary, room: Dictionary, prob_id: String) -> Dictionary:
	var options: Dictionary = room.get("options", {})
	var conf := int(ctx.get("conf", -1))
	var ly := int(room.get("ly", room.y))
	var deep := 0.0
	if bool(ctx.get("rnd", false)) and prob_id == "":
		if conf == 0:
			deep = float(ly) / 2.0
		elif conf == 1:
			deep = float(ly)
		elif conf == 2:
			deep = float(ly) * 2.5
	var ml := float(ctx.get("land_dif", 0)) + deep
	var loc := {
		"room": room,
		"gx": int(room.x),
		"gy": int(room.y),
		"lx": int(room.get("lx", room.x)),
		"ly": ly,
		"z": int(room.get("z", 0)),
		"prob": prob_id,
		"dif": ml,
		"locks": ml * 0.7,
		"mech": ml / 4.0,
		"enemy_level": ml,
		"biom": int(ctx.get("biom", 0)),
		"water": 100,
		"spawn_points": [],
		"enspawn": [],
		"ups": [[], [], [], [], [], []],
		"objs": [],
		"kol_en": [0, 0, 0, 0, 0, 0],
		"kol_spawn": Registry.int_of(options.get("kolspawn"), 0),
		"tip_spawn": str(options.get("spawn", "enl2")),
		"kol_hid": 0,
		"no_obj": {},
		"kol_phoenix": 0,
		"xp_count": 0,
	}
	if options.has("wlevel"):
		loc.water = Registry.int_of(options.wlevel, 100)
	if room.has("water"):
		loc.water = int(room.water)
	var glob := int(ctx.get("glob_dif", 2))
	if glob > 2:
		loc.enemy_level = ml + float(glob - 2) * 2.0
	var preset := Registry.int_of(options.get("entip"), -1)
	if room.has("enemy_type") and int(room.enemy_type) >= 0:
		loc["tip_enemy"] = int(room.enemy_type)
	else:
		loc["tip_enemy"] = LandGen._enemy_type(loc.biom, ml, preset)
	_set_kol_en(loc, ml)
	for pick_v in room.get("setdoor", []):
		var pick: Array = pick_v
		_set_door(loc, int(pick[0]), int(pick[1]))
	_bucket(loc, room.get("objs", []))
	return loc


## Land.setLocDif enemy counts.
static func _set_kol_en(loc: Dictionary, ml: float) -> void:
	var tip := int(loc.tip_enemy)
	if ml < 4.0:
		_kol(loc, 1, 3, 5, 2)
		_kol(loc, 2, 2, 4, 0)
		_kol(loc, 3, 3, 4, 2)
		_kol(loc, 4, 1, 2, 0)
		_kol(loc, 5, 1, 4, 2)
		if tip == 6:
			_kol(loc, 2, 1, 3, 0)
		if int(loc.kol_spawn) == 0 and tip != 5:
			_kol(loc, -1, 1, 2, 0)
		loc.kol_hid = 0
	elif ml < 10.0:
		_kol(loc, 1, 3, 6, 2)
		if randf() < 0.15:
			_kol(loc, 2, 1, 1, 0)
		elif tip == 6:
			_kol(loc, 2, 2, 3, 0)
		else:
			_kol(loc, 2, 2, 5, 0)
		_kol(loc, 3, 3, 5, 2)
		_kol(loc, 4, 2, 3, 1)
		_kol(loc, 5, 2, 4, 2)
		if int(loc.kol_spawn) == 0 and tip != 5:
			_kol(loc, -1, 2, 3, 0)
		loc.kol_hid = int(randf() * 3.0)
	else:
		_kol(loc, 1, 4, 6, 2)
		if randf() < 0.15:
			_kol(loc, 2, 1, 2, 0)
		elif tip == 6:
			_kol(loc, 2, 3, 4, 0)
		else:
			_kol(loc, 2, 3, 6, 0)
		_kol(loc, 3, 4, 7, 2)
		_kol(loc, 4, 2, 4, 1)
		_kol(loc, 5, 3, 6, 2)
		if int(loc.kol_spawn) == 0:
			if tip != 5:
				_kol(loc, -1, 2, 4, 0)
			elif randf() > 0.4:
				_kol(loc, -1, 1, 3, 0)
		loc.kol_hid = int(randf() * 4.0)
	if tip == 5 or tip == 10:
		_kol(loc, 2, 1, 3, 1)
	if int(loc.biom) == 11:
		_kol(loc, 2, 5, 8, 0)


static func _kol(loc: Dictionary, en: int, lo: int, hi: int, spl: int) -> void:
	var n := lo + int(randf() * float(hi - lo + 1))
	if en == -1:
		loc.kol_spawn = n
		return
	if spl > 0 and randf() < 0.2:
		n += spl
	loc.kol_en[en] = n


## Location.setDoor -> setNoObj: no containers right at a carved passage.
static func _set_door(loc: Dictionary, n: int, fak: int) -> void:
	if fak < 2 or n > 21 or n < 0:
		return
	if n >= 17:
		var q := (n - 17) * 9 + 4
		_no_obj(loc, q + 1, 0, 0, 2)
		_no_obj(loc, q + 2, 0, 0, 2)
		if fak > 2:
			_no_obj(loc, q, 0, 0, 2)
			_no_obj(loc, q + 3, 0, 0, 2)
	elif n >= 11:
		var q := (n - 11) * 4 + 3
		_no_obj(loc, 0, q, 5, 0)
		_no_obj(loc, 0, q - 1, 5, 0)
		loc.enspawn.append(Vector2(TILE, (q + 1) * TILE - 1))
	elif n >= 6:
		var q := (n - 6) * 9 + 4
		_no_obj(loc, q + 1, ROWS - 1, 0, -2)
		_no_obj(loc, q + 2, ROWS - 1, 0, -2)
		if fak > 2:
			_no_obj(loc, q, ROWS - 1, 0, -2)
			_no_obj(loc, q + 3, ROWS - 1, 0, -2)
	else:
		var q := n * 4 + 3
		_no_obj(loc, COLS - 1, q, -5, 0)
		_no_obj(loc, COLS - 1, q - 1, -5, 0)
		loc.enspawn.append(Vector2((COLS - 1) * TILE, (q + 1) * TILE - 1))


static func _no_obj(loc: Dictionary, nx: int, ny: int, dx: int, dy: int) -> void:
	var cells: Dictionary = loc.no_obj
	if dx > 0:
		for i in range(nx, nx + dx + 1):
			cells[Vector2i(i, ny)] = true
	if dx < 0:
		for i in range(nx + dx, nx + 1):
			cells[Vector2i(i, ny)] = true
	if dy > 0:
		for i in range(ny, ny + dy + 1):
			cells[Vector2i(nx, i)] = true
	if dy < 0:
		for i in range(ny + dy, ny + 1):
			cells[Vector2i(nx, i)] = true


static func _can_place(loc: Dictionary, x: int, y: int) -> bool:
	return not (loc.no_obj as Dictionary).has(Vector2i(x, y))


## Location constructor: objs.xml tip sorts each placed obj.
static func _bucket(loc: Dictionary, objs: Array) -> void:
	for obj_v in objs:
		var obj: Dictionary = obj_v
		if str(obj.get("tag", "obj")) != "obj":
			continue
		var id := str(obj.get("id", ""))
		var info := Registry.obj(id)
		if info.is_empty():
			continue
		var tip := str(info.get("tip", ""))
		var x := int(obj.get("x", 0))
		var y := int(obj.get("y", 0))
		var attrs: Dictionary = obj.get("attrs", {})
		var kids: Array = obj.get("kids", [])
		match tip:
			"spawnpoint":
				loc.spawn_points.append(Vector2i(x, y))
			"enspawn":
				var size := maxi(Registry.int_of(info.get("size"), 1), 1)
				loc.enspawn.append(Vector2((x + 0.5 * size) * TILE, (y + 1) * TILE - 1))
			"up":
				var n := TIP_EN.find(id)
				if n > 0:
					loc.ups[n].append({"x": x, "y": y, "attrs": attrs, "kids": kids})
			_:
				loc.objs.append({"id": id, "tip": tip, "rem": Registry.int_of(info.get("rem"), 0), "x": x, "y": y, "attrs": attrs, "kids": kids, "size": int(obj.get("size", 1))})


static func _set_objects(ctx: Dictionary, loc: Dictionary, out: Dictionary) -> void:
	var rnd := bool(ctx.get("rnd", false))
	for obj_v in loc.objs:
		var obj: Dictionary = obj_v
		if rnd and int(obj.rem) > 0 and not _can_place(loc, int(obj.x), int(obj.y)):
			continue
		if str(obj.tip) == "unit":
			_create_unit(ctx, loc, str(obj.id), int(obj.x), int(obj.y), obj.attrs, obj.kids, "", out)
		else:
			_create_obj(ctx, loc, str(obj.id), str(obj.tip), int(obj.x), int(obj.y), obj.attrs, obj.kids, out, int(obj.size))
	_set_random_units(ctx, loc, out)
	for sp_v in loc.spawn_points:
		var sp: Vector2i = sp_v
		out.rows.append(_row("spawnpoint", "player", loc, sp.x, sp.y, {}))
	for at_v in loc.enspawn:
		var at: Vector2 = at_v
		var row := _row("enspawn", "enspawn", loc, int(at.x / TILE), int(at.y / TILE), {})
		row["feet"] = [float(loc.gx * COLS * TILE) + at.x, float(loc.gy * ROWS * TILE) + at.y]
		row["spawn"] = _spawn_info(ctx, loc)
		out.rows.append(row)


## What en_spawn.gd needs to run _create_unit for this room later.
static func _spawn_info(ctx: Dictionary, loc: Dictionary) -> Dictionary:
	var keep := {}
	for key in ["gx", "gy", "lx", "ly", "z", "prob", "dif", "enemy_level", "biom", "water", "tip_enemy"]:
		keep[key] = loc.get(key)
	return {
		"kol": int(loc.kol_spawn),
		"tip": str(loc.get("tip_spawn", "enl2")),
		"loc": keep,
		"ctx": {"rnd": bool(ctx.get("rnd", false)), "conf": int(ctx.get("conf", -1))},
	}


static func _set_random_units(ctx: Dictionary, loc: Dictionary, out: Dictionary) -> void:
	var rnd := bool(ctx.get("rnd", false))
	for i in range(1, TIP_EN.size()):
		var ups: Array = loc.ups[i]
		if int(loc.kol_en[i]) <= 0 or ups.is_empty():
			continue
		if rnd:
			var kept: Array = []
			for up_v in ups:
				if _can_place(loc, int(up_v.x), int(up_v.y)):
					kept.append(up_v)
			ups = kept
			loc.ups[i] = ups
		for _k in int(loc.kol_en[i]):
			if ups.is_empty():
				break
			var n := int(randf() * float(ups.size()))
			var up: Dictionary = ups[n]
			_create_unit(ctx, loc, TIP_EN[i], int(up.x), int(up.y), up.attrs, up.kids, "", out)
			if ups.size() <= 1:
				ups.clear()
				break
			ups.remove_at(n)
	var hid: Array = loc.ups[2]
	if int(loc.kol_hid) > 0 and not hid.is_empty():
		for _j in int(loc.kol_hid):
			var n := int(randf() * float(hid.size()))
			var up: Dictionary = hid[n]
			_create_hidden(ctx, loc, int(up.x), int(up.y), out)
			if hid.size() <= 1:
				break
			hid.remove_at(n)


static func _create_hidden(ctx: Dictionary, loc: Dictionary, nx: int, ny: int, out: Dictionary) -> void:
	var biom := int(loc.biom)
	if biom == 10 or biom == 11:
		return
	var tip := int(loc.tip_enemy)
	if tip == 0:
		_create_unit(ctx, loc, "zombie", nx, ny, {"dig": "2"}, [], "", out)
	elif tip == 2:
		_create_obj(ctx, loc, "robocell", "box", nx, ny, {}, [], out)
	elif tip == 1 or tip == 3:
		_create_obj(ctx, loc, "alarm", "box", nx, ny, {}, [], out)
	elif tip == 6:
		_create_unit(ctx, loc, "lov", nx, ny, {}, [], "", out)


static func _create_unit(ctx: Dictionary, loc: Dictionary, tip: String, nx: int, ny: int, attrs: Dictionary, kids: Array, cid: String, out: Dictionary) -> void:
	if tip == "mines":
		for dx in [0, 2, 4]:
			_create_unit(ctx, loc, "mine", nx + dx, ny, {}, [], "", out)
		return
	var rnd := bool(ctx.get("rnd", false))
	if rnd and tip == "transm" and not attrs.has("on") and randf() < 0.5:
		return
	var in_water := false
	var biom := int(loc.biom)
	if biom == 1 or biom == 5:
		in_water = ny >= int(loc.water)
	var made := {}
	var s := _random_unit(ctx, loc, tip, in_water)
	if s != "":
		var scid := cid if cid != "" else _random_cid(ctx, loc, s)
		if s == "slmine":
			s = "slime"
		made = _make_unit(s, scid, attrs, float(loc.dif))
	if made.is_empty():
		var scid2 := cid if cid != "" else _random_cid(ctx, loc, tip)
		made = _make_unit(tip, scid2, attrs, float(loc.dif))
	if made.is_empty():
		if not TIP_EN.has(tip):
			out.rows.append(_row("unknown", tip, loc, nx, ny, attrs))
		return
	var hero := 0
	if rnd and str(loc.prob) == "":
		if randf() < minf(0.05, float(loc.dif) / 100.0 + 0.02):
			hero = int(randf() * 4.0 + 1.0)
	if attrs.has("hero"):
		hero = Registry.int_of(attrs.hero, hero)
	var level := float(loc.enemy_level)
	if hero == 0 and not bool(made.boss):
		level = round(level * (1.1 - randf() * 0.4))
	var unit_id := str(made.id)
	var catalog := Registry.unit_row(unit_id)
	var size := maxi(Registry.int_of(Registry.obj(tip).get("size"), 1), 1)
	var body: Array = catalog.get("body", [])
	if body.size() >= 2:
		size = int(floor((float(body[0]) - 1.0) / float(TILE))) + 1
	var row := _row(_unit_cat(str(made.cl)), tip, loc, nx, ny, attrs)
	# UnitTurret: cid hidden/hidden2 first, the map's @hidden overrides it.
	if made.has("hidden") and not attrs.has("hidden"):
		row.attrs = attrs.duplicate()
		row.attrs["hidden"] = str(made.hidden)
	row["feet"] = _world(loc, (nx + 0.5 * size) * TILE, (ny + 1) * TILE - 1)
	row["unit_id"] = unit_id
	row["cl"] = made.cl
	row["tr"] = made.tr
	row["level"] = int(level)
	row["hero"] = hero
	row["boss"] = made.boss
	row["supported"] = not catalog.is_empty()
	row["stats"] = Registry.has_stats(unit_id)
	row["friendly"] = int(ctx.get("conf", -1)) == 10
	row["tip_enemy"] = int(loc.tip_enemy)
	row["scripts"] = _scripts(attrs, kids)
	out.rows.append(row)


static func _unit_cat(cl: String) -> String:
	match cl:
		"Mine":
			return "mine"
		"UnitTrap", "UnitDamager":
			return "trap"
		"UnitTrigger":
			return "laser"
		"UnitTransmitter":
			return "alarm"
	if cl in _NPC:
		return "npc"
	return "unit"


## Unit.create and the class constructors. Returns {id, cl, tr, boss} or {}.
static func _make_unit(id: String, cid: String, attrs: Dictionary, dif: float) -> Dictionary:
	match id:
		"mwall":
			return {"id": "mwall", "cl": "UnitMWall", "tr": 0, "boss": false}
		"scythe":
			return {"id": "scythe", "cl": "UnitScythe", "tr": 0, "boss": false}
		"ttur":
			return {"id": "ttur", "cl": "UnitThunderTurret", "tr": 0, "boss": false}
	var node := Registry.obj(id)
	if node.is_empty():
		return {}
	var cl := str(node.get("cl", ""))
	if cl == "" or cl == "None":
		return {}
	if cid == "" and node.has("cid"):
		cid = str(node.cid)
	var tr := 0
	var name := ""
	if _RAIDER_KIN.has(cl):
		var kin: Array = _RAIDER_KIN[cl]
		tr = _variant(cid, attrs, 1 + int(randf() * float(kin[1])))
		if tr <= 0:
			tr = 1
		name = "%s%d" % [kin[0], tr]
	elif _FIXED.has(cl):
		name = str(_FIXED[cl])
		tr = _variant(cid, attrs, 0)
	else:
		match cl:
			"UnitZombie":
				tr = _variant(cid, attrs, int(randf() * 7.0))
				name = "zombie%d" % tr
			"UnitAlicorn":
				tr = _variant(cid, attrs, int(randf() * 7.0))
				if tr < 0:
					tr = int(randf() * 3.0 + 1.0)
				name = "alicorn%d" % tr
			"UnitHellhound":
				tr = _variant(cid, attrs, 1)
				name = "hellhound%d" % tr
			"UnitAnt":
				tr = _variant(cid, attrs, 1)
				name = "ant%d" % tr
			"UnitProtect", "UnitGutsy":
				tr = _variant(cid, attrs, 0)
				name = ("protect" if cl == "UnitProtect" else "gutsy") + (str(tr) if tr > 0 else "")
			"UnitTurret":
				if attrs.has("tr"):
					tr = Registry.int_of(attrs.tr, 1)
				elif dif < 10.0:
					tr = int(randf() * 3.0 + 1.0)
				elif dif < 15.0:
					tr = int(randf() * 5.0 + 1.0)
				else:
					tr = int(randf() * 7.0 + 1.0)
				name = "turret%d" % int(_TURRET_TIP.get(cid, 0))
			"UnitBat":
				tr = _variant(cid, attrs, 0)
				name = "bloodwing" + (str(tr) if tr > 1 else "")
			"UnitFish":
				tr = _variant(cid, attrs, 1)
				name = "fish%d" % tr
			"UnitBloat":
				tr = _variant(cid, attrs, int(randf() * 5.0))
				name = "bloat%d" % tr
			"UnitDron":
				tr = _variant(cid, attrs, int(randf() * 2.0 + 1.0))
				name = "dront" if tr == 100 else "dron%d" % tr
			"UnitMonstrik":
				name = cid
				if name == "scorp":
					name += str(1 + int(randf() * 2.0))
			"UnitSlime":
				tr = _variant(cid, attrs, 0)
				var bare := tr - 10 if tr >= 10 else tr
				name = "cryoslime" if bare == 1 else ("pinkslime" if bare == 2 else "slime")
			"UnitRoller":
				tr = maxi(_variant(cid, attrs, 1), 1)
				name = "roller%d" % tr if tr >= 2 else "roller"
			"UnitNPC":
				name = cid if cid != "" else "npc"
			"UnitDestr":
				tr = Registry.int_of(cid, 0)
				name = "destr%d" % tr
			"UnitBloatEmitter":
				name = cid if cid != "" else "ebloat"
			"UnitTrap":
				name = cid if cid != "" else "mtrap"
			"UnitTrigger":
				name = cid if cid != "" else "triglaser"
			"UnitDamager":
				name = cid if cid != "" else "damshot"
			"Mine":
				if attrs.has("tr"):
					tr = Registry.int_of(attrs.tr, 1)
				elif cid != "":
					name = cid
				else:
					tr = 1
				if tr > 0:
					name = _MINE_TR[tr] if tr < _MINE_TR.size() else "hmine"
			_:
				return {}
	if name == "":
		return {}
	var made := {"id": name, "cl": cl, "tr": tr, "boss": cl in _BOSS}
	if cl == "UnitTurret" and (cid == "hidden" or cid == "hidden2"):
		made["hidden"] = 2 if cid == "hidden2" else 1
	return made


## Unit.resolveVariant: map tr, then the creation id, then the fallback.
static func _variant(cid: String, attrs: Dictionary, fallback: int) -> int:
	if attrs.has("tr"):
		return Registry.int_of(attrs.tr, fallback)
	if cid != "":
		return Registry.int_of(cid, 0)
	return fallback


## Location.randomUnit.
static func _random_unit(ctx: Dictionary, loc: Dictionary, tip: String, in_water: bool) -> String:
	var biom := int(loc.biom)
	var te := int(loc.tip_enemy)
	var dif := float(loc.dif)
	var even := (int(loc.lx) + int(loc.ly)) % 2 == 0
	match tip:
		"enl2":
			if biom == 10:
				return "stabpon"
			if te == 0:
				return "zombie"
			if te == 2:
				if biom == 2 and dif >= 12.0 and randf() < minf(dif / 100.0, 0.15):
					return "eqd"
				if dif >= 5.0 and randf() < 0.1:
					return "landturret"
				if dif >= 6.0 and randf() < minf(dif / 40.0, 0.3):
					return "gutsy"
				if dif >= 2.0 and randf() < minf(dif / 10.0, 0.5):
					return "protect"
				return "robot"
			match te:
				3:
					return "slaver"
				4:
					return "merc"
				5:
					return "alicorn"
				6:
					return "zebra"
				7:
					if randf() < 0.4:
						return "gutsy" if randf() < 0.5 else "protect"
					return "ranger"
				8:
					return "zombie" if randf() < 0.75 else "necros"
				9:
					if randf() < 0.1:
						return "hellhound"
					if randf() < 0.07:
						return "landturret"
					return "encl"
				10:
					return "hellhound"
				11:
					return "hellhound" if randf() < 0.3 else "encl"
			return "raider"
		"enl1":
			if biom == 10 or biom == 11:
				return ""
			if (biom == 1 or biom == 5) and in_water:
				return "fish"
			if biom == 5:
				return "scorp3" if randf() < 0.3 else "slime"
			if biom == 6:
				return "roller"
			if (te == 2 and dif >= 4.0) or te == 7 or te == 9 or te == 10:
				return "roller" if even else "msp"
			if te == 0 or te == 5 or te == 6:
				var s := ""
				if dif >= 2.0 and randf() < minf(dif / 30.0, 0.5):
					s = "scorp"
				elif even:
					s = "slime"
				else:
					s = "ant"
				if biom == 1 and randf() < 0.25:
					s = "rat"
				return s
			if dif >= 2.0 and randf() < minf(dif / 30.0, 0.5):
				return "molerat"
			return "tarakan" if randf() < 0.6 else "rat"
		"enc1":
			if biom == 10:
				return "turret"
			if (biom == 1 or biom == 5) and in_water:
				return "fish"
			if biom == 5:
				return "bloodwing" if even else "slime"
			if biom == 6 or biom == 4:
				return "cturret"
			if te == 0 or te == 5 or te == 6:
				if biom == 1 and randf() < 0.6:
					return "slime"
				return "bloodwing"
			return "turret"
		"enf1":
			if biom == 10:
				return ""
			if (biom == 1 or biom == 5) and in_water:
				return "fish"
			if biom == 5:
				return "bloat"
			if te == 0 or te == 5:
				return "bloat"
			if (te == 1 or te == 3 or te == 4 or te == 6) and dif >= 3.0:
				return "vortex"
			if te == 2 and dif >= 3.0:
				return "spritebot"
			if te == 11 or te == 7 or te == 9 or te == 10 or (te == 2 and dif > 10.0 and randf() < minf(dif / 40.0, 0.5)):
				return "dron"
			return ""
		"lov":
			if biom == 10 or biom == 11:
				return ""
			if biom == 5:
				return "slmine"
			if te == 0:
				return "slmine" if even else "trap"
			if (te == 1 or te == 3 or te == 4 or te == 6) and even:
				if dif >= 10.0 and randf() < 0.5:
					return "trridge"
				if randf() < 0.5:
					return "trplate"
				return "trcans"
			if ((biom == 2 and te == 2) or te == 7 or te == 9) and even:
				return "trlaser"
			return "mine"
	return ""


## Location.randomCid.
static func _random_cid(ctx: Dictionary, loc: Dictionary, tip: String) -> String:
	var dif := float(loc.dif)
	var biom := int(loc.biom)
	var te := int(loc.tip_enemy)
	var tr := 0
	match tip:
		"raider":
			if dif >= 5.0:
				tr = int(randf() * 9.0 + 1.0)
			elif dif >= 2.0:
				tr = int(randf() * 5.0 + 1.0)
			else:
				tr = int(randf() * 2.0 + 1.0)
		"slaver":
			if dif >= 18.0:
				tr = int(randf() * 6.0 + 1.0)
			elif dif >= 15.0:
				tr = int(randf() * 5.0 + 1.0)
			else:
				tr = int(randf() * 4.0 + 1.0)
		"zebra":
			tr = int(randf() * 4.0 + 1.0) if dif >= 15.0 else int(randf() * 2.0 + 1.0)
			if dif >= 25.0 and randf() < 0.1:
				tr = 5
		"ranger":
			if int(ctx.get("conf", -1)) == 7:
				tr = int(randf() * 3.0 + 1.0)
			elif int(loc.ly) == 0:
				tr = 1
			else:
				tr = int(randf() * 2.0 + 1.0)
		"merc":
			if dif >= 19.0:
				tr = int(randf() * 5.0 + 1.0)
			elif dif >= 15.0 and randf() > 0.5:
				tr = int(randf() * 4.0 + 1.0)
			else:
				tr = int(randf() * 2.0 + 1.0)
		"encl":
			tr = int(randf() * 4.0 + 1.0)
		"protect", "gutsy":
			tr = 1 if te == 7 else 0
		"dron":
			if te == 9:
				tr = mini(int(randf() * 4.0 + 1.0), 3)
			else:
				tr = int(randf() * 2.0 + 1.0)
		"roller":
			tr = 2 if biom == 6 else 1
		"zombie":
			if biom == 5:
				tr = 9 if dif >= 20.0 and randf() < 0.1 else int(randf() * 4.0 + 5.0)
			elif biom >= 1 and dif >= 8.0:
				tr = int(randf() * 7.0)
			elif dif >= 5.0:
				tr = int(randf() * 5.0)
			elif dif >= 2.0:
				tr = int(randf() * 4.0)
		"alicorn":
			tr = int(randf() * 3.0 + 1.0)
		"hellhound":
			tr = 1
		"bloat":
			if biom == 5:
				tr = int(randf() * 3.0 + 4.0)
			elif dif >= 10.0:
				tr = int(randf() * 5.0)
			elif dif >= 4.0:
				tr = int(randf() * 4.0)
			elif dif >= 2.0:
				tr = int(randf() * 3.0)
		"ant":
			if biom >= 1 and dif >= 6.0:
				tr = int(randf() * 3.0 + 1.0)
			elif dif >= 3.0:
				tr = int(randf() * 2.0 + 1.0)
			else:
				tr = 1
		"fish":
			tr = 3 if biom == 5 else int(randf() * 2.0 + 1.0)
		"slime":
			tr = 2 if biom == 5 else 0
		"slmine":
			tr = 12 if biom == 5 else 10
		"bloodwing":
			tr = 2 if biom == 5 else 1
		"scorp":
			tr = int(randf() * 2.0 + 1.0) if dif >= 5.0 else 1
			return "scorp%d" % tr
		"mine":
			if biom == 4:
				return "plamine"
			if biom == 2 and randf() < minf(dif / 20.0, 0.4):
				return "plamine"
			if randf() < minf(dif / 20.0, 0.75):
				return "mine"
			return "hmine"
		_:
			return ""
	return str(tr)


## Location.createObj.
static func _create_obj(ctx: Dictionary, loc: Dictionary, id: String, tip: String, nx: int, ny: int, attrs: Dictionary, kids: Array, out: Dictionary, placed_size: int = 0) -> void:
	var info := Registry.obj(id)
	var size := maxi(Registry.int_of(info.get("size"), 1), 1)
	var wid := maxi(Registry.int_of(info.get("wid"), 1), 1)
	var row: Dictionary
	match tip:
		"box", "door":
			row = _row(_box_cat(id, info, attrs), id, loc, nx, ny, attrs)
			row["feet"] = _world(loc, (nx + 0.5 * size) * TILE, (ny + 1) * TILE - 1)
			row["w"] = size * TILE
			row["h"] = wid * TILE
			row["lock"] = _lock(loc, info, attrs)
			row["items"] = _items(kids)
			row["open"] = str(attrs.get("open", "")) not in ["", "0"]
			_add_transition(row, id, info, attrs, loc)
			for kid_v in kids:
				if str((kid_v as Dictionary).get("tag", "")) == "move":
					row["move"] = (kid_v as Dictionary).get("attrs", {})
			if tip == "box":
				_box_riders(ctx, loc, row, attrs, out)
		"trap":
			row = _row("trap", id, loc, nx, ny, attrs)
			row["feet"] = _world(loc, (nx + 0.5 * size) * TILE, (ny + 1) * TILE - 1)
			row["damage"] = int(round(50.0 * (1.0 + float(loc.dif) * 0.1)))
			row["ceiling"] = id == "fspikes"
		"checkpoint":
			row = _row("checkpoint", id, loc, nx, ny, attrs)
			row["feet"] = _world(loc, (nx + 0.5 * size) * TILE, (ny + 1) * TILE - 1)
			row["lock"] = _lock(loc, info, attrs)
		"area":
			row = _row("area", id, loc, nx, ny, attrs)
			var w := Registry.int_of(attrs.get("w"), 2)
			var h := Registry.int_of(attrs.get("h"), 2)
			var bx := nx
			var room: Dictionary = loc.room
			if bool(room.get("mirror", false)):
				var raw := COLS - nx - maxi(placed_size, 1)
				bx = COLS - raw - w
			var origin := Vector2(loc.gx * COLS * TILE, loc.gy * ROWS * TILE)
			var bottom := float((ny + 1) * TILE)
			row["rect"] = [origin.x + bx * TILE, origin.y + bottom - h * TILE, w * TILE, h * TILE]
			row["enabled"] = Registry.int_of(attrs.get("off"), 0) <= 0
			row["mess"] = str(attrs.get("mess", ""))
			row["area_tip"] = str(attrs.get("tip", "gg"))
		"bonus":
			row = _row("bonus", id, loc, nx, ny, attrs)
			row["feet"] = _world(loc, (nx + 0.5) * TILE, (ny + 0.5) * TILE)
			row["xp"] = int(ctx.get("xp", 100))
			loc.xp_count = int(loc.xp_count) + 1
		_:
			row = _row("unknown", id, loc, nx, ny, attrs)
	row["scripts"] = _scripts(attrs, kids)
	out.rows.append(row)
	if str(loc.prob) == "" and str(attrs.get("prob", "")) != "":
		var pid := str(attrs.prob)
		if not (out.probs as Array).has(pid):
			out.probs.append(pid)


static func _box_cat(id: String, info: Dictionary, attrs: Dictionary) -> String:
	if str(info.get("tip", "")) == "door":
		return "door"
	if str(info.get("allact", "")) in ["comein", "exit", "probreturn"] or id in ["doorprob", "doorboss"]:
		return "transition"
	if attrs.has("prob"):
		return "transition"
	if id in _BUTTONS:
		return "alarm" if id == "alarm" else "button"
	if id in _STATIONS:
		return "station"
	if id in _PLATFORMS:
		return "platform"
	if id in _CLOUDS:
		return "cloud"
	if info.has("cont") or attrs.has("cont") or id in _CRATES:
		return "container"
	return "furniture"


static func _add_transition(row: Dictionary, id: String, info: Dictionary, attrs: Dictionary, loc: Dictionary) -> void:
	if str(row.cat) != "transition":
		return
	var act := str(attrs.get("allact", info.get("allact", "")))
	if act == "":
		act = "prob"
	row["kind"] = act
	row["prob"] = str(attrs.get("prob", ""))
	if act == "comein":
		row["layer"] = 1 - int(loc.z)


## Interact: a random lock unless the map sets one.
static func _lock(loc: Dictionary, info: Dictionary, attrs: Dictionary) -> float:
	if attrs.has("lock"):
		return Registry.float_of(attrs.lock, 0.0)
	if not info.has("lock"):
		return 0.0
	var lk := Registry.float_of(info.lock, 0.0)
	if info.has("lockch") and randf() >= Registry.float_of(info.lockch, 1.0):
		return lk - floor(lk)
	var tip := Registry.int_of(info.get("locktip"), 1)
	if tip == 1 or tip == 2:
		return lk + (0.3 + randf()) * float(loc.locks)
	return lk + randf() * float(loc.mech)


## Location.createObj phoenix / transmitter on top of a box.
static func _box_riders(ctx: Dictionary, loc: Dictionary, row: Dictionary, attrs: Dictionary, out: Dictionary) -> void:
	var info := Registry.obj(str(row.id))
	var wall := Registry.int_of(info.get("wall"), 0) > 0
	if wall or Registry.int_of(info.get("size"), 1) * TILE < 40:
		return
	var top: Array = [float(row.feet[0]), float(row.feet[1]) - float(row.h)]
	var rider := ""
	if str(attrs.get("ph", "")) == "1":
		rider = "phoenix"
	elif bool(ctx.get("rnd", false)) and int(ctx.get("biom", 0)) == 0 and int(loc.kol_phoenix) == 0 and int(out.phoenix) < 3 and randf() < 0.02:
		rider = "phoenix"
	if rider == "phoenix":
		loc.kol_phoenix = 1
		out.phoenix = int(out.phoenix) + 1
		var bird := _row("unit", "phoenix", loc, int(row.cell[0]), int(row.cell[1]), {})
		bird["feet"] = top
		bird["unit_id"] = "phoenix"
		bird["cl"] = "UnitPhoenix"
		bird["supported"] = not Registry.unit_row("phoenix").is_empty()
		bird["stats"] = true
		bird["level"] = 0
		bird["hero"] = 0
		out.rows.append(bird)
	if str(attrs.get("transm", "")) == "1" and not (bool(ctx.get("rnd", false)) and randf() < 0.5):
		var tr := _row("alarm", "transm", loc, int(row.cell[0]), int(row.cell[1]), {})
		tr["feet"] = top
		tr["unit_id"] = "transmitter"
		tr["cl"] = "UnitTransmitter"
		tr["supported"] = not Registry.unit_row("transmitter").is_empty()
		tr["level"] = int(loc.enemy_level)
		out.rows.append(tr)


static func _items(kids: Array) -> Array:
	var items: Array = []
	for kid_v in kids:
		var kid: Dictionary = kid_v
		if str(kid.get("tag", "")) != "item":
			continue
		var a: Dictionary = kid.get("attrs", {})
		items.append({"id": str(a.get("id", "")), "n": Registry.int_of(a.get("kol"), 1), "imp": a.has("imp")})
	return items


## Attached <scr> children and scr* attributes resolved through Scripts.xml.
static func _scripts(attrs: Dictionary, kids: Array) -> Dictionary:
	var found := {}
	for kid_v in kids:
		var kid: Dictionary = kid_v
		if str(kid.get("tag", "")) != "scr":
			continue
		var script := script_of(kid)
		found[str(script.get("eve", ""))] = script
	for key in _SCRIPT_ATTRS:
		if not attrs.has(key):
			continue
		var named := Registry.script(str(attrs[key]))
		if named.is_empty():
			continue
		var copy := named.duplicate(true)
		copy["id"] = str(attrs[key])
		found[str(_SCRIPT_ATTRS[key])] = copy
	return found


## Script.as: the element's own act, then each <s> step. Delays are seconds.
static func script_of(node: Dictionary) -> Dictionary:
	var attrs: Dictionary = node.get("attrs", {})
	var acts: Array = []
	if attrs.has("act"):
		acts.append(_step(attrs))
	for kid_v in node.get("kids", []):
		var kid: Dictionary = kid_v
		if str(kid.get("tag", "")) == "s":
			acts.append(_step(kid.get("attrs", {})))
	var script := {"acts": acts}
	if attrs.has("eve"):
		script["eve"] = str(attrs.eve)
	if attrs.has("id"):
		script["id"] = str(attrs.id)
	return script


static func _step(attrs: Dictionary) -> Dictionary:
	var step := {}
	for key in ["act", "targ", "val", "t", "n", "opt1", "opt2"]:
		if attrs.has(key):
			step[key] = str(attrs[key])
	return step


static func _row(cat: String, id: String, loc: Dictionary, nx: int, ny: int, attrs: Dictionary) -> Dictionary:
	return {
		"cat": cat,
		"id": id,
		"room": [int(loc.gx), int(loc.gy)],
		"lroom": [int(loc.lx), int(loc.ly), int(loc.z)],
		"cell": [nx, ny],
		"feet": _world(loc, (nx + 0.5) * TILE, (ny + 1) * TILE - 1),
		"uid": str(attrs.get("uid", "")),
		"attrs": attrs,
		"prob_room": str(loc.prob),
	}


static func _world(loc: Dictionary, x: float, y: float) -> Array:
	return [float(int(loc.gx) * COLS * TILE) + x, float(int(loc.gy) * ROWS * TILE) + y]


## Land.buildRandomLand: rooms bottom row first, then the conf's exits,
## checkpoints, trial doors, gas clouds and xp bonuses.
static func _plan_random(ctx: Dictionary, rooms: Array, by_cell: Dictionary, out: Dictionary) -> void:
	var conf := int(ctx.conf)
	var width := int(ctx.width)
	var height := int(ctx.height)
	var beg: Vector2i = ctx.beg
	var stage := int(ctx.get("stage", 0))
	var main := {}
	var back := {}
	for room_v in rooms:
		var room: Dictionary = room_v
		var at := Vector2i(int(room.lx), int(room.ly))
		if int(room.get("z", 0)) == 0:
			main[at] = by_cell[_key(room)]
		else:
			back[at] = by_cell[_key(room)]
	if conf == 2 and main.has(Vector2i(3, 0)):
		_random_prob(ctx, main[Vector2i(3, 0)], stage, true, out)
	if conf == 3 and stage >= 1 and main.has(Vector2i(1, 4)):
		_random_prob(ctx, main[Vector2i(1, 4)], stage, true, out)
	for j in range(height - 1, -1, -1):
		for i in width:
			var at := Vector2i(i, j)
			if not main.has(at):
				continue
			var loc: Dictionary = main[at]
			var bonuses := true
			_set_objects(ctx, loc, out)
			var is_beg := i == beg.x and j == beg.y
			match conf:
				0, 1:
					if (i + j) % 2 == 0:
						if j == height - 1:
							var deep_exit := (conf == 0 and stage >= 2) or (conf == 1 and stage >= 1)
							_create_exit(ctx, loc, "1" if deep_exit else "", out)
						else:
							_create_check(ctx, loc, is_beg, out)
					else:
						if j == height - 1:
							_random_prob(ctx, loc, stage, true, out)
						elif randf() < 0.3:
							_random_prob(ctx, loc, stage, false, out)
				2, 5:
					if i != 0 or j != 0:
						_create_clouds(ctx, loc, j, out)
					if conf == 2 and i == width - 1:
						_create_exit(ctx, loc, "", out)
					if conf == 5 and i == width - 1 and j == 0:
						_create_exit(ctx, loc, "1" if stage >= 1 else "", out)
					elif (i + j) % 2 == 0:
						if (conf == 2 and j < 2 and i < width - 1) or (conf == 5 and (i == 0 or j > 0)):
							_create_check(ctx, loc, is_beg, out)
					if ((j > 1 and i < width - 1) or (conf == 2 and i < width - 1 and randf() < 0.25)) and (i + j) % 2 == 1:
						_random_prob(ctx, loc, stage, false, out)
				3:
					if i != 2:
						if (i + j) % 2 == 0:
							if j == 0:
								_create_exit(ctx, loc, "1" if stage >= 1 else "", out)
							else:
								_create_check(ctx, loc, is_beg, out)
						else:
							if j == 0:
								_random_prob(ctx, loc, stage, true, out)
							elif j != 4 and randf() < 0.25:
								_random_prob(ctx, loc, stage, false, out)
				4:
					if is_beg or i == 3:
						_create_check(ctx, loc, is_beg, out)
						if is_beg:
							bonuses = false
				6:
					if j == 0:
						if i == 0 or i == 2:
							_create_exit(ctx, loc, "1" if stage >= 1 else "", out)
						if i == 1:
							_random_prob(ctx, loc, stage, true, out)
					elif is_beg or i == ((7 - j) % 3):
						_create_check(ctx, loc, is_beg, out)
					elif randf() < 0.25:
						_random_prob(ctx, loc, stage, false, out)
				7:
					if is_beg:
						_create_check(ctx, loc, true, out)
						bonuses = false
				10, 11:
					if is_beg:
						_create_check(ctx, loc, true, out)
			if back.has(at):
				_set_objects(ctx, back[at], out)
			if bonuses and conf != 10 and conf != 11:
				_xp_bonuses(ctx, loc, out)


static func _create_check(ctx: Dictionary, loc: Dictionary, active: bool, out: Dictionary) -> void:
	var points: Array = loc.spawn_points
	if points.is_empty():
		return
	var sp: Vector2i = points[int(randf() * float(points.size()))]
	var id := "checkpoint"
	if not active and bool(ctx.get("rnd", false)) and randf() < 0.5:
		id += str(int(randf() * 5.0 + 1.0))
	_create_obj(ctx, loc, id, "checkpoint", sp.x, sp.y, {"active": "1"} if active else {}, [], out)


static func _create_exit(ctx: Dictionary, loc: Dictionary, s: String, out: Dictionary) -> void:
	var points: Array = loc.spawn_points
	if points.is_empty():
		return
	var sp: Vector2i = points[int(randf() * float(points.size()))]
	var attrs := {"name": "exit", "prob": str(ctx.get("exit_prob", "")) + s, "time": "20", "inter": "8", "sign": "1"}
	_create_obj(ctx, loc, "exit", "box", sp.x, sp.y, attrs, [], out)


## Land.newRandomProb: a trial not yet used whose level fits; doorboss for tip 2.
static func _random_prob(ctx: Dictionary, loc: Dictionary, maxlevel: int, imp: bool, out: Dictionary) -> void:
	var pool: Array = []
	var imp_id := ""
	for row_v in Registry.land(str(ctx.land_id)).get("probs", []):
		var row: Dictionary = row_v
		var pid := str(row.get("id", ""))
		if (out.probs as Array).has(pid) or (ctx.get("probs_done", []) as Array).has(pid):
			continue
		if Registry.int_of(row.get("level"), 0) > maxlevel:
			continue
		pool.append(row)
		if row.has("imp"):
			imp_id = pid
	if pool.is_empty():
		return
	var pick: Dictionary
	if imp and imp_id != "":
		for row_v in pool:
			if str(row_v.id) == imp_id:
				pick = row_v
	elif pool.size() == 1:
		pick = pool[0]
	else:
		pick = pool[int(randf() * float(pool.size()))]
	var did := "doorboss" if str(pick.get("tip", "")) == "2" else "doorprob"
	var points: Array = loc.spawn_points
	if points.is_empty():
		return
	var sp: Vector2i = points[int(randf() * float(points.size()))]
	_create_obj(ctx, loc, did, "box", sp.x, sp.y, {"prob": str(pick.id), "time": "20", "inter": "8"}, [], out)


static func _create_clouds(ctx: Dictionary, loc: Dictionary, lvl: int, out: Dictionary) -> void:
	var biom := int(loc.biom)
	var cloud := ""
	var kol := 1
	if biom == 1:
		if lvl >= 2:
			return
		cloud = "tcloud1"
		kol = int(randf() * 5.0)
	elif biom == 5:
		cloud = "pcloud1"
		kol = int(randf() * 2.0) if lvl == 0 else int(randf() * 3.0)
	if cloud == "":
		return
	for _i in kol:
		var nx := int(randf() * float(COLS - 4) + 2.0)
		var ny := int(randf() * float(ROWS - 4) + 2.0)
		if biom == 1 and lvl == 1 and ny > 15:
			ny = 15
		if biom == 5 and lvl == 0:
			ny = int(randf() * 15.0 + 9.0)
		_create_obj(ctx, loc, cloud, "box", nx, ny, {}, [], out)


static func _xp_bonuses(ctx: Dictionary, loc: Dictionary, out: Dictionary) -> void:
	var spots: Array = (loc.room as Dictionary).get("xp", [])
	var first := (out.rows as Array).size()
	for spot_v in spots:
		var spot: Vector2i = spot_v
		_create_obj(ctx, loc, "xp", "bonus", spot.x, spot.y, {}, [], out)
	for k in range(first, (out.rows as Array).size()):
		out.rows[k]["max"] = spots.size()
