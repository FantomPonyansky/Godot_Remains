extends ResourceFormatLoader

## Serves mod art and sounds for the paths ModLoader registered.
## take_over_path of the source and the .ctex remap is not enough: load() of an
## imported texture still reads a new CompressedTexture2D. This loader sits at
## the front of the list and returns the runtime resource for the source path,
## the remap path, and the uid.

var _by_path := {}


func clear_overrides() -> void:
	_by_path.clear()


func override_path(path: String, resource: Resource) -> void:
	if path != "" and resource != null:
		_by_path[path] = resource


func _recognize_path(path: String, _type: StringName) -> bool:
	return _by_path.has(path)


func _handles_type(type: StringName) -> bool:
	var name := String(type)
	if name == "" or name == "Resource":
		return true
	return name.contains("Texture") or name.contains("Image") or name.contains("Audio") or name.contains("Stream")


func _get_resource_type(path: String) -> String:
	if not _by_path.has(path):
		return ""
	var res: Resource = _by_path[path]
	return res.get_class()


func _load(path: String, original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
	var hit: Resource = _by_path.get(path, null)
	if hit == null:
		hit = _by_path.get(original_path, null)
	if hit == null:
		return ERR_FILE_UNRECOGNIZED
	if hit.resource_path == "" or hit.resource_path == path:
		return hit
	var copy: Variant = hit.duplicate()
	if copy is Resource:
		return copy
	return hit
