extends RefCounted
class_name DungeonGen

## The playable preview asks for a plant grid. The real build is LandGen.
## generation.json is notes; it is not the room pool.

const LandGen := preload("res://scripts/map/land_gen.gd")


static func generate(_seed_value: int = -1) -> Dictionary:
	var built: Dictionary = LandGen.build("random_plant")
	if str(built.get("error", "")) != "":
		return {"error": built.error}
	return LandGen.to_preview(built)
