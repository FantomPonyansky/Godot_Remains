extends RefCounted

## Load on demand (PORT_RULES): on a land change the land art caches are
## emptied, so textures only the left land used are freed with its nodes.
## Player, weapon, projectile, effect, loot and UI caches stay. One switch:
## project setting foe/art/load_on_demand, console `artcache`, launch flag
## --art-on-demand / --art-preload (after `--` too).

const SETTING := "foe/art/load_on_demand"
const LAND_CACHES := [
	"res://scripts/enemy.gd",
	"res://scripts/door_art.gd",
	"res://scripts/map/obj_art.gd",
	"res://scripts/map/back_decor.gd",
	"res://scripts/map/checkpoint.gd",
	"res://scripts/wall_span.gd",
	"res://scripts/story/npc_vis.gd",
	"res://scripts/map/room_file.gd",
	"res://scripts/map/tile_outline.gd",
]

static var _override: Variant = null


static func enabled() -> bool:
	if _override != null:
		return bool(_override)
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if args.has("--art-on-demand"):
		return true
	if args.has("--art-preload"):
		return false
	return bool(ProjectSettings.get_setting(SETTING, true))


static func set_enabled(on: bool) -> void:
	_override = on


## game.enter_land, before the next land is built.
static func drop_land_art() -> void:
	var on := enabled()
	(load("res://scripts/enemy.gd") as GDScript).call("set_keep_plans", 0 if on else 1)
	if not on:
		return
	for path in LAND_CACHES:
		(load(path) as GDScript).call("drop_cache")
