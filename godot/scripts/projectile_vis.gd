extends RefCounted

## Projectile art from WeaponFactory: visbul + vis_vbul, else visualBullet.
## Thrown explosives use the weapon clip (WThrow sets vBullet = vWeapon).
## Melee is absent, so a hoof or club does not pick up a bullet sprite.

const DIR := "res://assets/sprites/projectiles/"
## visualRainbow is the player alicorn's visualBullet (Bullet.as). The strip is
## OTHER's 2× export; scale 0.5 is the Flash size. bullet.gd _apply_stretch
## assigns scale after show_frame, so the swap has to keep that 0.5.
const RAINBOW_STRIP := "res://assets/fx_blits/visualRainbow.png"
const RAINBOW_FRAME := Vector2(196, 60)
const RAINBOW_ORIGIN := Vector2(182, 36)
const RAINBOW_COLS := 2
const RAINBOW_FRAMES := 4
const RAINBOW_SCALE := 0.5

static var _data: Dictionary = {}
static var _loaded := false
static var _textures: Dictionary = {}


static func lookup(weapon_id: String) -> Dictionary:
	_ensure()
	var weapons: Dictionary = _data.get("weapons", {})
	if weapons.has(weapon_id):
		return weapons[weapon_id]
	var base := weapon_id.split("^")[0]
	if weapons.has(base):
		return weapons[base]
	return {}


static func is_beam(info: Dictionary) -> bool:
	return bool(_symbol(str(info.get("symbol", ""))).get("beam", false))


static func frame_count(info: Dictionary) -> int:
	if str(info.get("symbol", "")) == "visualRainbow":
		return RAINBOW_FRAMES
	var frames: Array = _symbol(str(info.get("symbol", ""))).get("frames", [])
	return frames.size()


## Bullet.as swaps visualBullet for visualRainbow when the owner is the player
## and World.w.alicorn. Call this from bullet.gd _dress_projectile after lookup.
static func alicorn_bullet(info: Dictionary, from_player: bool, alicorn: bool) -> Dictionary:
	if not from_player or not alicorn or str(info.get("symbol", "")) != "visualBullet":
		return info
	var next := info.duplicate()
	next["symbol"] = "visualRainbow"
	return next


static func show_frame(sprite: Sprite2D, info: Dictionary, index: int) -> bool:
	if str(info.get("symbol", "")) == "visualRainbow":
		return _show_rainbow(sprite, index)
	var frames: Array = _symbol(str(info.get("symbol", ""))).get("frames", [])
	if frames.is_empty():
		return false
	var item: Variant = frames[clampi(index, 0, frames.size() - 1)]
	if typeof(item) != TYPE_DICTIONARY:
		return false
	var rec: Dictionary = item
	var tex := _texture(str(rec.get("file", "")))
	if tex == null:
		return false
	sprite.texture = tex
	sprite.centered = false
	var anchor: Array = rec.get("anchor", [0, 0])
	if anchor.size() >= 2:
		sprite.offset = -Vector2(float(anchor[0]), float(anchor[1]))
	else:
		sprite.offset = Vector2.ZERO
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return true


static func _show_rainbow(sprite: Sprite2D, index: int) -> bool:
	if sprite == null or not ResourceLoader.exists(RAINBOW_STRIP):
		return false
	var tex := load(RAINBOW_STRIP) as Texture2D
	if tex == null:
		return false
	var i := clampi(index, 0, RAINBOW_FRAMES - 1)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2((i % RAINBOW_COLS) * RAINBOW_FRAME.x, int(float(i) / float(RAINBOW_COLS)) * RAINBOW_FRAME.y, RAINBOW_FRAME.x, RAINBOW_FRAME.y)
	sprite.texture = at
	sprite.centered = false
	sprite.offset = -RAINBOW_ORIGIN
	sprite.scale = Vector2(RAINBOW_SCALE, RAINBOW_SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return true


static func _symbol(name: String) -> Dictionary:
	_ensure()
	var symbols: Dictionary = _data.get("symbols", {})
	var found: Variant = symbols.get(name, {})
	if found is Dictionary:
		return found
	return {}


static func _texture(file: String) -> Texture2D:
	if file == "":
		return null
	if _textures.has(file):
		return _textures[file]
	var path := DIR + file
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	_textures[file] = tex
	return tex


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var path := DIR + "manifest.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		_data = parsed
