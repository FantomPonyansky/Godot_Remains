class_name TileCatalog
extends RefCounted

## One map from a room-grid code to the original art.
## Piece table: reference/Remains-Source2 tilePieces.json, read the way TileRegistry.decode does.
## Material bitmaps: texture.swf symbols (Grafon numbMat). texture1.swf has no tile bitmaps.
## Ladders and slopes: pfe.swf tileFront frames (spriteFrame, 1-based). Grafon places that
## clip at the tile's top-left. In the exported frame, that origin is pixel (5, 30).
## Floor lips: maskFloor is the top 10px of the block. Beams: TileMask is the whole 40px tile.

const FRONT_ORIGIN := Vector2(5, 30)
const FLOOR_LIP := 10.0
# Opaque rail in the tileFront export. Left body frame is sprite x 3..21.
# Right body frame is sprite x 27..45.
const LADDER_RAIL_W := 19.0

const _DIR := "res://assets/sprites/tiles/"

## Block letter -> [texture, top texture, wall left behind the block, edge texture].
## Empty wall means the block leaves none. Empty edge means the piece has no outline bitmap.
## Edge names are tilePieces edgeTexture. tMoss is only the mossy-concrete outline (L).
const BLOCK := {
	"A": ["tMetal", "", "tConcreteBack", "tKlep"],
	"B": ["tSuperCon", "", "tConcreteBack", "tBorder"],
	"C": ["tConcrete", "tFloor", "tConcreteBack", "tBorder"],
	"D": ["tConcreteD", "", "tConcreteBack", "tSkol"],
	"E": ["tCracked", "", "tConcreteBack", "tSkol"],
	"F": ["tWood", "", "", ""],
	"G": ["tRock", "", "tConcreteBack", "tSkol"],
	"H": ["tStones", "", "tDirt2", "tDirt2"],
	"I": ["tBrick2", "tFloor", "tConcreteBack", ""],
	"J": ["tMWall", "tFloorMetal", "tConcreteBack", "tKlep2"],
	"K": ["tMWall2", "tFloorMetal", "tConcreteBack", ""],
	"L": ["tConcreteMoss", "", "tConcreteBack", "tMoss"],
	"M": ["tRust", "", "tConcreteBack", "tKlep"],
	"N": ["tBuild", "tFloor", "tConcreteBack", "tConRough"],
	"O": ["tBaseMetal", "tFloorMetal", "tConcreteBack", "tKlep2"],
	"P": ["tCanBrick", "tFloor", "tConcreteBack", ""],
	"Q": ["tConRough", "tFloor", "tConcreteBack", "tBorder"],
	"R": ["tRoof", "tRoofFloor", "tConcreteBack", ""],
	"S": ["tEncl1", "tFloorMetal", "tConcreteBack", "tKlep3"],
	"T": ["tEncl2", "tFloorMetal", "tConcreteBack", "tKlep3"],
}

## Overlay letter -> [kind, texture, side, tileFront frame].
const OVERLAY := {
	"-": ["beam", "tShelf", "", 0],
	"Д": ["beam", "tWoodBeam", "", 0],
	"Е": ["beam", "tStShelf", "", 0],
	"К": ["beam", "tConBeam", "", 0],
	"Н": ["beam", "tCanBeam", "", 0],
	"Р": ["beam", "tCloudBeam", "", 0],
	"А": ["ladder", "", "right", 3],
	"Б": ["ladder", "", "left", 1],
	"В": ["slope", "", "right", 6],
	"Г": ["slope", "", "left", 5],
	"Ж": ["slope", "", "right", 8],
	"З": ["slope", "", "left", 7],
	"И": ["slope", "", "right", 10],
	"Й": ["slope", "", "left", 9],
	"Л": ["slope", "", "right", 12],
	"М": ["slope", "", "left", 11],
	"О": ["slope", "", "right", 14],
	"П": ["slope", "", "left", 13],
	"С": ["slope", "", "right", 16],
	"Т": ["slope", "", "left", 15],
	"A": ["patch", "tConcreteBack", "", 0],
	"B": ["patch", "tKaf", "", 0],
	"C": ["patch", "tConPlates", "", 0],
	"D": ["patch", "tBrick", "", 0],
	"E": ["patch", "tBlocks", "", 0],
	"F": ["patch", "tMetalPlates", "", 0],
	"G": ["patch", "tMetalVert", "", 0],
	"H": ["patch", "tMetalRust", "", 0],
	"I": ["patch", "tVent", "", 0],
	"J": ["patch", "tShtuk", "", 0],
	"K": ["patch", "tSetka", "", 0],
	"L": ["patch", "tDirt2", "", 0],
	"M": ["patch", "tWoodPlanks", "", 0],
	"N": ["patch", "tStPlates", "", 0],
	"O": ["patch", "tMeh", "", 0],
	"P": ["patch", "tDarkMetal", "", 0],
	"Q": ["patch", "tDarkPlates", "", 0],
	"R": ["patch", "tDarkRivets", "", 0],
	"S": ["patch", "tPipes", "", 0],
	"T": ["patch", "tRustPlates", "", 0],
	"U": ["patch", "tBase", "", 0],
	"V": ["patch", "tCanStuc", "", 0],
	"W": ["patch", "tCanTiles", "", 0],
	"X": ["patch", "tOrn", "", 0],
	"Y": ["patch", "tEncl2", "", 0],
	"Z": ["patch", "tCloud", "", 0],
}

const MIRROR := {
	"А": "Б", "Б": "А", "В": "Г", "Г": "В", "Ж": "З", "З": "Ж",
	"И": "Й", "Й": "И", "Л": "М", "М": "Л", "О": "П", "П": "О", "С": "Т", "Т": "С",
}


static func file_for(texture_name: String) -> String:
	if texture_name == "":
		return ""
	var path := _DIR + texture_name + ".png"
	if ResourceLoader.exists(path):
		return path
	return ""


static func front_file(frame: int) -> String:
	if frame < 1 or frame > 16:
		return ""
	var path := "%stile_front_%02d.png" % [_DIR, frame]
	if ResourceLoader.exists(path):
		return path
	return ""


static func mirror_char(ch: String) -> String:
	return str(MIRROR.get(ch, ch))


static func ladder_frame(side: String) -> int:
	return 1 if side == "left" else 3


static func ladder_rail_sprite_x(side: String) -> float:
	return 3.0 if side == "left" else 27.0


static func decode(code: String) -> Dictionary:
	var info := {
		"block": "",
		"texture": "",
		"top": "",
		"wall": "",
		"edge": "",
		"patch": "",
		"height": 4,
		"beams": [],
		"slope_frame": 0,
		"slope_side": "",
		"slope_code": "",
		"ladder_frame": 0,
		"ladder_side": "",
	}
	if code.is_empty():
		return info
	var head := code.substr(0, 1)
	var i := 1
	if head == "_":
		pass
	elif head.unicode_at(0) > 64 and BLOCK.has(head):
		var row: Array = BLOCK[head]
		info.block = head
		info.texture = str(row[0])
		info.top = str(row[1])
		info.wall = str(row[2])
		if row.size() > 3:
			info.edge = str(row[3])
	for n in range(i, code.length()):
		var ch := code.substr(n, 1)
		if ch == ",":
			info.height = 3
		elif ch == ";":
			info.height = 2
		elif ch == ":":
			info.height = 1
		elif ch == "*" or ch == "_":
			continue
		elif OVERLAY.has(ch):
			var piece: Array = OVERLAY[ch]
			var kind := str(piece[0])
			if kind == "patch":
				info.patch = ch
				info.wall = str(piece[1])
			elif kind == "beam":
				(info.beams as Array).append(ch)
			elif kind == "slope":
				info.slope_side = str(piece[2])
				info.slope_frame = int(piece[3])
				info.slope_code = ch
			elif kind == "ladder":
				info.ladder_side = str(piece[2])
				info.ladder_frame = int(piece[3])
	if str(info.patch) == "" and str(info.block) == "":
		info.wall = ""
	return info


static func beam_texture(ch: String) -> String:
	if not OVERLAY.has(ch):
		return ""
	return str((OVERLAY[ch] as Array)[1])


## tilePieces.json solid blocks. hp, damageThreshold, material, indestructible.
## A missing threshold is 0 (TilePiece_Definition). Junk is the only solid with none.
## Room edges are not in this table: TileRegistry.viewBorderDefinition forces
## 10000 HP, indestructible, and the land border block's threshold.
const WALL := {
	"A": [30000, 1200, "metal", true],
	"B": [5000, 1200, "stone", false],
	"C": [1000, 100, "stone", false],
	"D": [1000, 100, "stone", false],
	"E": [150, 10, "stone", false],
	"F": [40, 0, "wood", false],
	"G": [1000, 100, "stone", false],
	"H": [1000, 100, "earth", false],
	"I": [1000, 100, "brick", false],
	"J": [5000, 1200, "metal", false],
	"K": [1000, 100, "metal", false],
	"L": [1000, 100, "stone", false],
	"M": [5000, 1200, "metal", false],
	"N": [1000, 100, "stone", false],
	"O": [5000, 4000, "metal", false],
	"P": [1000, 100, "stone", false],
	"Q": [1000, 100, "stone", false],
	"R": [150, 10, "brick", false],
	"S": [5000, 4000, "metal", false],
	"T": [1000, 100, "metal", false],
}

## Lands.xml options border. LandAct defaults to steel (A) when the attribute is absent.
const BORDER := {
	"random_sewer": "M",
	"random_mane": "N",
	"mtn": "N",
	"random_canter": "Q",
	"minst": "Q",
	"random_mbase": "O",
	"bunker": "O",
	"art": "O",
	"random_encl": "S",
	"comm": "S",
}


static func wall_of(code: String) -> Dictionary:
	var info := decode(code)
	var letter := str(info.block)
	if letter == "" or not WALL.has(letter) or not BLOCK.has(letter):
		return {}
	var row: Array = WALL[letter]
	var block: Array = BLOCK[letter]
	return {
		"letter": letter,
		"hp": int(row[0]),
		"thre": int(row[1]),
		"mat": str(row[2]),
		"indestruct": bool(row[3]),
		"wall": str(block[2]),
		"texture": str(block[0]),
	}


static func border_for(land_id: String) -> String:
	return str(BORDER.get(land_id, "A"))
