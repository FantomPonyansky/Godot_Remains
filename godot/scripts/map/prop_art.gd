class_name PropArt
extends RefCounted

## One still for a room-editor object id. tex is the image to draw. anchor is the
## pixel in that image (or in region, when set) that sits on the object's feet,
## the bottom centre of its footprint. region is one cell of a sheet. scale is
## an extra draw scale (checkpoint frames were exported at 2x).

const _ObjArt := preload("res://scripts/map/obj_art.gd")
const _Door := preload("res://scripts/door_art.gd")
const _Registry := preload("res://scripts/map/land_registry.gd")

const _PROPS := "res://assets/sprites/props/"
const _DOORS := "res://assets/sprites/doors/"
const _UNITS := "res://assets/sprites/sheets/units/"
## Rigged units: tests/rig_stills.gd.
const _RIG_STILLS := "res://assets/sprites/rig_stills/"
const _TRAPS := "res://assets/sprites/sheets/traps/"
const _NPCS := "res://assets/sprites/npcs/"
const _SHEETS := "res://assets/sprites/sheets/"

## Same paths as land_props._CRATE_ART. A props/<id>.png wins over this.
const _CRATE := {
	"woodbox": "res://assets/sprites/props/woodbox.png",
	"box": "res://assets/sprites/props/box.png",
	"mcrate1": "res://assets/sprites/props/mcrate1.png",
	"mcrate2": "res://assets/sprites/props/mcrate2.png",
	"mcrate3": "res://assets/sprites/props/mcrate3.png",
	"mcrate4": "res://assets/sprites/props/mcrate4.png",
	"mcrate5": "res://assets/sprites/props/mcrate5.png",
	"bigbox": "res://assets/sprites/props/bigbox.png",
	"bigbox2": "res://assets/sprites/props/bigbox2.png",
}

## objs.xml cl -> the unit id Unit.create uses when the placed tag has no tr.
const _FIXED := {
	"UnitRobobrain": "robobrain", "UnitEqd": "eqd", "UnitSentinel": "sentinel",
	"UnitSpriteBot": "spritebot", "UnitVortex": "vortex", "UnitMsp": "msp",
	"UnitCaptive": "captive_s0", "UnitPonPon": "ponpon", "UnitTrain": "train",
	"UnitTransmitter": "transmitter", "UnitNecros": "necros", "UnitSpectre": "spectre",
	"UnitBossRaider": "bossraider", "UnitBossAlicorn": "bossalicorn", "UnitBossUltra": "bossultra",
	"UnitBossNecr": "bossnecr", "UnitBossDron": "bossdron", "UnitBossEncl": "bossencl",
	"UnitThunderHead": "thunderhead",
}
const _KIN := {
	"UnitRaider": "raider", "UnitSlaver": "slaver", "UnitZebra": "zebra",
	"UnitRanger": "ranger", "UnitEncl": "encl", "UnitMerc": "merc",
}
const _TURRET_TIP := {"land": 1, "wall": 2, "arm": 3, "combat": 4, "boss": 5}
const _MINE_TR := ["", "hmine", "mine", "plamine", "impmine", "zebmine", "balemine"]

static var _anchors: Dictionary = {}
static var _manifests: Dictionary = {}
static var _cache: Dictionary = {}


static func still(id: String) -> Dictionary:
	if id == "":
		return {}
	var tip := str(_Registry.obj(id).get("tip", ""))
	if tip in ["spawnpoint", "enspawn", "area", "up"]:
		return {}
	if tip == "bonus" or id == "xp":
		return _obj("bonus_xp")
	if id.begins_with("checkpoint"):
		var cp := _checkpoint()
		if not cp.is_empty():
			return cp
	if tip == "door":
		var door := _door(id)
		if not door.is_empty():
			return door
	if tip == "trap":
		var trap := _obj("trap_" + id)
		if not trap.is_empty():
			return trap
	var prop := _prop(id)
	if not prop.is_empty():
		return prop
	var key := _unit_key(id)
	var pic := _from_sheets(key if key != "" else id)
	if pic.is_empty() and key != "" and key != id:
		pic = _from_sheets(id)
	if pic.is_empty() and (id == "thunderhead" or key == "thunderhead"):
		pic = _thunderhead()
	return pic


static func _prop(id: String) -> Dictionary:
	var closed := _PROPS + id + ".png"
	if ResourceLoader.exists(closed):
		var tex := _load(closed)
		if tex == null:
			return {}
		return {"tex": tex, "anchor": _png_anchor(id, tex)}
	if not _CRATE.has(id) and _ObjArt.has(id):
		return _obj(id)
	var crate := str(_CRATE.get(id, ""))
	if crate == "":
		return {}
	var art := _load(crate)
	if art == null:
		return {}
	return {"tex": art, "anchor": _png_anchor(id, art)}


static func _obj(key: String) -> Dictionary:
	if not _ObjArt.has(key):
		return {}
	var fr := _ObjArt.label_frame(key, "close")
	if fr <= 0:
		fr = 1
	var tex := _ObjArt.texture(key, fr)
	if tex == null:
		return {}
	return {"tex": tex, "anchor": -_ObjArt.offset(key)}


static func _door(id: String) -> Dictionary:
	var spec: Array = _Door.SPEC.get(id, [])
	var tex := _load(_DOORS + id + "_close.png")
	if tex == null:
		var fr := _ObjArt.label_frame(id, "close")
		tex = _ObjArt.texture(id, fr) if fr > 0 else null
	if tex == null:
		return {}
	var hit_w: float = float(spec[0]) if spec.size() > 0 else tex.get_width()
	var hit_h: float = float(spec[1]) if spec.size() > 1 else tex.get_height()
	var sx: float = float(spec[2]) if spec.size() > 2 else 0.0
	var sy: float = float(spec[3]) if spec.size() > 3 else 0.0
	return {"tex": tex, "anchor": Vector2(hit_w * 0.5 - sx, hit_h - sy)}


## Hull is centered, drawn at 3x, offset from the feet (brain_thunderhead).
static func _thunderhead() -> Dictionary:
	var tex := _load("res://assets/fx_blits/11_sprThunderHead.png")
	if tex == null:
		return {}
	var at := Vector2(45.0, -750.0)
	return {"tex": tex, "anchor": tex.get_size() * 0.5 - at / 3.0, "scale": 3.0}


## vischeckpoint osn frame 1. Exported at zoom 2; origin is the feet.
static func _checkpoint() -> Dictionary:
	var tex := _load(_PROPS + "checkpoint/osn/1.png")
	if tex == null:
		return {}
	return {"tex": tex, "anchor": Vector2(131.0, 240.0), "scale": 0.5}


static func _png_anchor(id: String, tex: Texture2D) -> Vector2:
	var a: Variant = _anchor_map().get(id)
	if a is Array and (a as Array).size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return Vector2(tex.get_width() * 0.5, tex.get_height())


static func _anchor_map() -> Dictionary:
	if not _anchors.is_empty():
		return _anchors
	for path in [_PROPS + "term_anchors.json", _PROPS + "platform_anchors.json"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for k in parsed:
				_anchors[k] = parsed[k]
	if _anchors.is_empty():
		_anchors["_"] = []
	return _anchors


static func _unit_key(id: String) -> String:
	match id:
		"mwall", "scythe", "ttur":
			return id
		"mines":
			return "hmine"
	var info := _Registry.obj(id)
	var cl := str(info.get("cl", ""))
	var cid := str(info.get("cid", ""))
	if _FIXED.has(cl):
		return str(_FIXED[cl])
	if _KIN.has(cl):
		var n := _variant(cid, 1)
		return "%s%d" % [str(_KIN[cl]), n if n > 0 else 1]
	match cl:
		"UnitTurret":
			return "turret%d" % int(_TURRET_TIP.get(cid, 0))
		"UnitSlime":
			var slim := _variant(cid, 0)
			var bare := slim - 10 if slim >= 10 else slim
			return "cryoslime" if bare == 1 else ("pinkslime" if bare == 2 else "slime")
		"UnitBat":
			var bat := _variant(cid, 0)
			return "bloodwing" + (str(bat) if bat > 1 else "")
		"UnitFish":
			return "fish%d" % maxi(_variant(cid, 1), 1)
		"UnitZombie":
			return "zombie%d" % maxi(_variant(cid, 0), 0)
		"UnitAlicorn":
			return "alicorn%d" % maxi(_variant(cid, 1), 1)
		"UnitHellhound":
			return "hellhound%d" % maxi(_variant(cid, 1), 1)
		"UnitAnt":
			return "ant%d" % maxi(_variant(cid, 1), 1)
		"UnitProtect", "UnitGutsy":
			var tr := _variant(cid, 0)
			var stem := "protect" if cl == "UnitProtect" else "gutsy"
			return stem + (str(tr) if tr > 0 else "")
		"UnitRoller":
			var roller := maxi(_variant(cid, 1), 1)
			return "roller%d" % roller if roller >= 2 else "roller"
		"UnitDron":
			return "dron%d" % maxi(_variant(cid, 1), 1)
		"UnitBloat":
			return "bloat%d" % maxi(_variant(cid, 0), 0)
		"UnitMonstrik":
			if cid == "scorp":
				return "scorp1"
			return cid if cid != "" else id
		"UnitNPC":
			if cid == "doctor":
				return "doctor"
			return "vendor" if cid == "" or cid == "npc" else cid
		"UnitBloatEmitter":
			return cid if cid != "" else "ebloat"
		"UnitTrap":
			return cid if cid != "" else "mtrap"
		"UnitTrigger":
			return cid if cid != "" else "triglaser"
		"UnitDamager":
			return cid if cid != "" else "damshot"
		"UnitDestr":
			return "destr%d" % maxi(_variant(cid, 1), 1)
		"Mine":
			if cid != "":
				return cid
			return "hmine"
		_:
			return ""


static func _variant(cid: String, fallback: int) -> int:
	if cid != "" and cid.is_valid_int():
		return int(cid)
	return fallback


static func _from_sheets(key: String) -> Dictionary:
	if key == "":
		return {}
	var still: Dictionary = _manifest(_RIG_STILLS).get(key, {})
	if not still.is_empty():
		var tex := _load(_RIG_STILLS + key + ".png")
		if tex != null:
			var a: Array = still.get("anchor", [0, 0])
			return {"tex": tex, "anchor": Vector2(float(a[0]), float(a[1]))}
	for dir in [_UNITS, _TRAPS, _NPCS]:
		var pic := _packed(dir, key)
		if not pic.is_empty():
			return pic
	var row := _Registry.unit_row(key)
	var vis := str(row.get("vis", ""))
	if vis != "" and vis != key:
		var vis_pic := _packed(_UNITS, vis)
		if not vis_pic.is_empty():
			return vis_pic
	var pack := str(row.get("pack", ""))
	if pack != "" and pack != key:
		var pack_pic := _packed(_UNITS, pack)
		if not pack_pic.is_empty():
			return pack_pic
	return _classic(key)


static func _packed(dir: String, key: String) -> Dictionary:
	var e: Dictionary = _manifest(dir).get(key, {})
	if e.is_empty():
		return {}
	var tex := _load(dir + str(e.get("sheet", "")))
	if tex == null:
		return {}
	var cell: Array = e.get("cell", [0, 0])
	if cell.size() < 2:
		return {}
	var cw := float(cell[0])
	var ch := float(cell[1])
	if cw < 1.0 or ch < 1.0:
		return {}
	var cols := maxi(int(e.get("cols", 1)), 1)
	var frame := _idle_frame(e.get("clips", {}))
	var anchor: Array = e.get("anchor", [cw * 0.5, ch])
	return {
		"tex": tex,
		"anchor": Vector2(float(anchor[0]), float(anchor[1]) if anchor.size() > 1 else ch),
		"region": Rect2(float(frame % cols) * cw, float(frame / cols) * ch, cw, ch),
	}


static func _idle_frame(clips: Dictionary) -> int:
	for name in ["stay", "idle"]:
		if not clips.has(name):
			continue
		var list: Array = (clips[name] as Dictionary).get("frames", [])
		if not list.is_empty():
			return int(list[0])
	return 0


## Pony sheets: centered on the feet, catalog offset, stay clip's first cell.
static func _classic(id: String) -> Dictionary:
	var row := _Registry.unit_row(id)
	if row.is_empty():
		return {}
	var tex_name := str(row.get("texture", ""))
	var cell: Array = row.get("cell", [])
	if tex_name == "" or cell.size() < 2:
		return {}
	var tex := _load(_SHEETS + tex_name)
	if tex == null:
		return {}
	var stay: Dictionary = (row.get("clips", {}) as Dictionary).get("stay", {})
	var col := int(stay.get("ff", 0))
	var row_i := int(stay.get("y", 0))
	var cw := float(cell[0])
	var ch := float(cell[1])
	var off: Array = row.get("offset", [0, 0])
	var ox: float = float(off[0]) if off.size() > 0 else 0.0
	var oy: float = float(off[1]) if off.size() > 1 else 0.0
	return {
		"tex": tex,
		"anchor": Vector2(cw * 0.5 - ox, ch * 0.5 - oy),
		"region": Rect2(col * cw, row_i * ch, cw, ch),
	}


static func _manifest(dir: String) -> Dictionary:
	if _manifests.has(dir):
		return _manifests[dir]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "manifest.json"))
	_manifests[dir] = parsed if parsed is Dictionary else {}
	return _manifests[dir]


static func _load(path: String) -> Texture2D:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path] as Texture2D
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_cache[path] = tex
	return tex
