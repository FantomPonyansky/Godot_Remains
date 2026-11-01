class_name ModLoader
extends RefCounted

## Discovers user://mods/<mod>/mod.json, remembers the player's enabled flags
## and order in settings/mods.cfg, and at boot takes over res:// art and sound
## for enabled mods. DataLib merges the data files. RoomFile reads rooms/.
##
## `rooms` is the built-in loose-rooms mod (mods/rooms/, per-file _disabled.json).
## A mod that fails data JSON or schema is skipped whole, including its rooms
## and art. The report is a log line, not push_error.
##
## Scene boots call boot() from UserDir._init, before later autoload scripts
## load, so their preload() of an overridden path sees the mod resource.
## A -s run does not construct UserDir. DataLib boots mods on first load when
## --user-dir= is set; without that, -s leaves mods off and does not read the
## real profile.

const LOOSE_ID := "rooms"
const _UserDir = preload("res://scripts/user_dir.gd")

const IMAGE_EXT: PackedStringArray = ["png", "jpg", "jpeg", "webp", "bmp", "tga"]
const AUDIO_EXT: PackedStringArray = ["ogg", "wav", "mp3"]

static var _did_boot := false
static var _good: Array = []
static var _skip := {}
static var _applied: Array = []
static var _scan_notes := {}
static var _import_rx = null
static var _uid_rx = null
static var _assets = null


static func booted() -> bool:
	return _did_boot


static func boot() -> void:
	if _did_boot:
		return
	_did_boot = true
	var lib = load("res://scripts/data_lib.gd")
	if not _allow() or lib == null:
		if lib != null:
			lib.vet_mods([])
		_good = []
		_skip = {}
		_applied = []
		return
	var enabled: Array = []
	for mod_v in _scan():
		var mod: Dictionary = mod_v
		if not bool(mod.get("enabled", false)):
			continue
		mod["files"] = data_files(mod)
		enabled.append(mod)
	var result: Dictionary = lib.vet_mods(enabled)
	_good = result.get("good", [])
	_skip = result.get("skip", {})
	_applied = result.get("applied", [])
	_apply_art(_good)


## The mods check writes a mod into the sandbox after the first boot, then reloads.
static func rescan() -> void:
	_did_boot = false
	_good = []
	_skip = {}
	_applied = []
	var lib = load("res://scripts/data_lib.gd")
	if lib != null:
		lib.drop_overlays()
	boot()


static func applied() -> Array:
	if not _did_boot:
		boot()
	return _applied.duplicate(true)


static func skip_reason(id: String) -> String:
	if not _did_boot:
		return ""
	return str(_skip.get(id, ""))


## Every mod, including disabled ones, in load order. Fresh from disk so the
## menu checkbox matches the cfg. Does not reload data already cached.
static func catalog() -> Array:
	if not _allow():
		return []
	return _scan()


static func stored_enabled(id: String, default_on: bool) -> bool:
	var cfg := _cfg()
	if cfg.has_section_key("enabled", id):
		return bool(cfg.get_value("enabled", id))
	return default_on


static func set_enabled(id: String, on: bool) -> void:
	var cfg := _cfg()
	cfg.set_value("enabled", id, on)
	cfg.save(_UserDir.settings("mods.cfg"))


## Null when the slot has no mods key (old saves). Otherwise the active array.
static func slot_mods_differ(slot: int) -> bool:
	var saved = _slot_active(slot)
	if saved == null:
		return false
	return not _same_active(saved, applied())


## Enabled mods that survived vetting, in load order. Loose rooms included.
static func room_sources() -> Array:
	if not _did_boot:
		boot()
	var out: Array = []
	for mod_v in _good:
		var mod: Dictionary = mod_v
		var dir := str(mod.get("rooms_dir", ""))
		if bool(mod.get("loose", false)) or _dir_exists(dir):
			out.append({
				"id": str(mod.get("id", "")),
				"dir": dir,
				"loose": bool(mod.get("loose", false)),
			})
	return out


static func data_files(mod: Dictionary) -> Array:
	if bool(mod.get("loose", false)):
		return []
	var out: Array = []
	# data/ maps to res://assets/data/; JSON under assets/ (weapon manifest, rig
	# symbols) merges the same way, at its res://assets/ path.
	for pair in [["data", "res://assets/data/"], ["assets", "res://assets/"]]:
		var root := str(mod.get("dir", "")).path_join(str(pair[0]))
		var rels: Array = []
		_walk(root, "", rels, true)
		rels.sort()
		for rel in rels:
			out.append({
				"rel": str(pair[0]) + "/" + str(rel),
				"abs": root.path_join(str(rel)),
				"res": str(pair[1]) + str(rel),
			})
	return out


static func _allow() -> bool:
	var scripted := false
	var sandbox := false
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var s := str(arg)
		if s == "-s" or s == "--script" or s.begins_with("--script="):
			scripted = true
		if s.begins_with("--user-dir="):
			sandbox = true
	return (not scripted) or sandbox


static func _scan() -> Array:
	var mods: Array = [_loose()]
	var seen := {LOOSE_ID: true}
	var root := _UserDir.mods()
	if _dir_exists(root):
		var subs: Array = []
		for sub in DirAccess.get_directories_at(root):
			subs.append(str(sub))
		subs.sort()
		for sub_v in subs:
			var sub := str(sub_v)
			if sub == LOOSE_ID or sub.begins_with(".") or sub.begins_with("_"):
				continue
			var dir := root.path_join(sub)
			var meta_path := dir.path_join("mod.json")
			if not FileAccess.file_exists(meta_path):
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
			if parsed is not Dictionary:
				_scan_skip(sub, "mod.json did not parse")
				continue
			var id := str((parsed as Dictionary).get("id", "")).strip_edges()
			if not _id_ok(id):
				_scan_skip(sub, "mod.json id missing or reserved")
				continue
			if seen.has(id):
				_scan_skip(sub, "duplicate id %s" % id)
				continue
			seen[id] = true
			var default_on := true
			if (parsed as Dictionary).has("enabled"):
				default_on = bool((parsed as Dictionary)["enabled"])
			var after: Array = []
			if (parsed as Dictionary).get("after", null) is Array:
				for a in (parsed as Dictionary)["after"]:
					after.append(str(a))
			mods.append({
				"id": id,
				"name": str((parsed as Dictionary).get("name", id)),
				"version": str((parsed as Dictionary).get("version", "")),
				"description": str((parsed as Dictionary).get("description", "")),
				"dir": dir,
				"rooms_dir": dir.path_join("rooms"),
				"after": after,
				"order": int((parsed as Dictionary).get("order", 0)),
				"default_enabled": default_on,
				"enabled": true,
				"loose": false,
			})
	var ordered := _sorted(mods)
	ordered = _apply_player_order(ordered)
	for mod_v in ordered:
		var mod: Dictionary = mod_v
		mod["enabled"] = stored_enabled(str(mod["id"]), bool(mod["default_enabled"]))
	return ordered


static func _loose() -> Dictionary:
	return {
		"id": LOOSE_ID,
		"name": LOOSE_ID,
		"version": "",
		"description": "",
		"dir": _UserDir.mods(),
		"rooms_dir": _UserDir.mods_rooms(),
		"after": [],
		"order": -1000000,
		"default_enabled": true,
		"enabled": true,
		"loose": true,
	}


static func _id_ok(id: String) -> bool:
	if id == "" or id == LOOSE_ID:
		return false
	for i in id.length():
		var c := id.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95 or c == 45
		if not ok:
			return false
	return true


static func _sorted(mods: Array) -> Array:
	var by := {}
	for mod_v in mods:
		by[str((mod_v as Dictionary).get("id", ""))] = mod_v
	var deps := {}
	var indeg := {}
	for mod_v in mods:
		var id := str((mod_v as Dictionary).get("id", ""))
		var need: Array = []
		for a in (mod_v as Dictionary).get("after", []):
			var s := str(a)
			if s != id and by.has(s) and not need.has(s):
				need.append(s)
		deps[id] = need
		indeg[id] = need.size()
	var rest: Array = mods.duplicate()
	var out: Array = []
	var guard := mods.size() * mods.size() + 4
	while out.size() < mods.size() and guard > 0:
		guard -= 1
		var ready: Array = []
		for mod_v in rest:
			if int(indeg.get(str((mod_v as Dictionary).get("id", "")), 0)) == 0:
				ready.append(mod_v)
		if ready.is_empty():
			print("ModLoader: load-order cycle, appending the rest by id")
			rest.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
			out.append_array(rest)
			break
		ready.sort_custom(func(a, b):
			if int(a.get("order", 0)) != int(b.get("order", 0)):
				return int(a.get("order", 0)) < int(b.get("order", 0))
			return str(a.get("id", "")) < str(b.get("id", "")))
		var pick: Dictionary = ready[0]
		out.append(pick)
		var idx := -1
		for i in rest.size():
			if str((rest[i] as Dictionary).get("id", "")) == str(pick.get("id", "")):
				idx = i
				break
		if idx >= 0:
			rest.remove_at(idx)
		var pid := str(pick.get("id", ""))
		for mod_v in rest:
			var id := str((mod_v as Dictionary).get("id", ""))
			var need: Array = deps[id]
			if need.has(pid):
				need.erase(pid)
				indeg[id] = need.size()
	return out


static func _apply_player_order(mods: Array) -> Array:
	var raw := str(_cfg().get_value("order", "ids", "")).strip_edges()
	if raw == "":
		return mods
	var by := {}
	for mod_v in mods:
		by[str((mod_v as Dictionary).get("id", ""))] = mod_v
	var out: Array = []
	var seen := {}
	for part in raw.split(","):
		var id := part.strip_edges()
		if id != "" and by.has(id) and not seen.has(id):
			out.append(by[id])
			seen[id] = true
	for mod_v in mods:
		var id := str((mod_v as Dictionary).get("id", ""))
		if not seen.has(id):
			out.append(mod_v)
	return out


static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(_UserDir.settings("mods.cfg"))
	return cfg


static func _scan_skip(folder: String, message: String) -> void:
	var token := folder + "|" + message
	if _scan_notes.has(token):
		return
	_scan_notes[token] = true
	print("ModLoader: skip %s: %s" % [folder, message])


static func _slot_active(slot: int) -> Variant:
	var slots = load("res://scripts/save_slots.gd")
	if slots == null:
		return null
	var path := str(slots.dir_of(slot)) + "run.json"
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		return null
	var providers: Variant = (parsed as Dictionary).get("providers", {})
	if providers is not Dictionary or not (providers as Dictionary).has("mods"):
		return null
	var blob: Variant = (providers as Dictionary).get("mods", {})
	if blob is not Dictionary:
		return []
	var active: Variant = (blob as Dictionary).get("active", [])
	return active if active is Array else []


static func _same_active(saved: Array, current: Array) -> bool:
	if saved.size() != current.size():
		return false
	for i in saved.size():
		if saved[i] is not Dictionary or current[i] is not Dictionary:
			return false
		if str((saved[i] as Dictionary).get("id", "")) != str((current[i] as Dictionary).get("id", "")):
			return false
		if str((saved[i] as Dictionary).get("version", "")) != str((current[i] as Dictionary).get("version", "")):
			return false
	return true


static func _apply_art(mods: Array) -> void:
	if _assets != null:
		_assets.clear_overrides()
	var taken := {}
	for mod_v in mods:
		var mod: Dictionary = mod_v
		if bool(mod.get("loose", false)):
			continue
		var root := str(mod.get("dir", "")).path_join("assets")
		var rels: Array = []
		_walk(root, "", rels, false)
		for rel_v in rels:
			var rel := str(rel_v)
			var ext := rel.get_extension().to_lower()
			if not IMAGE_EXT.has(ext) and not AUDIO_EXT.has(ext):
				continue
			var res_path := "res://assets/" + rel
			var resource := _load_asset(root.path_join(rel), ext)
			if resource == null:
				print("ModLoader: art skip %s %s" % [str(mod.get("id", "")), res_path])
				continue
			if taken.has(res_path):
				print("ModLoader: art %s replaced by %s" % [res_path, str(mod.get("id", ""))])
			else:
				print("ModLoader: art %s from %s" % [res_path, str(mod.get("id", ""))])
			taken[res_path] = true
			_own(res_path, resource)


static func _load_asset(path: String, ext: String) -> Resource:
	if IMAGE_EXT.has(ext):
		var image := Image.load_from_file(path)
		if image == null or image.is_empty():
			return null
		return ImageTexture.create_from_image(image)
	if ext == "ogg":
		return AudioStreamOggVorbis.load_from_file(path)
	if ext == "mp3":
		return AudioStreamMP3.load_from_file(path)
	if ext == "wav":
		return AudioStreamWAV.load_from_file(path)
	return null


## Register the runtime resource with the loader and the resource cache.
## load() of an imported file remaps to the .ctex (and may key the cache by
## uid). take_over_path holds one path per resource, so each key gets a copy.
## Only res:// keys are taken over; uid:// is loader-only.
static func _own(res_path: String, resource: Resource) -> void:
	var loader = _asset_loader()
	var keys: PackedStringArray = [res_path]
	var imp := _import_text(res_path)
	var dest := _import_field(imp, _import_rx, "path=\"(res://[^\"]+)\"")
	var uid := _import_field(imp, _uid_rx, "uid=\"(uid://[^\"]+)\"")
	if dest != "" and dest != res_path:
		keys.append(dest)
	if uid != "":
		keys.append(uid)
	# Duplicate while the source still has an empty path, so the copies do not
	# inherit a cache key and then fight take_over_path.
	var holders: Array[Resource] = []
	for i in keys.size():
		if i == 0:
			holders.append(resource)
			continue
		var copy: Variant = resource.duplicate()
		if copy is Resource:
			holders.append(copy)
		else:
			holders.append(resource)
	for i in holders.size():
		var held: Resource = holders[i]
		if loader != null:
			loader.override_path(keys[i], held)
		if keys[i].begins_with("res://"):
			held.take_over_path(keys[i])


static func _asset_loader():
	if _assets == null:
		var script = load("res://scripts/mod_asset_loader.gd")
		if script == null:
			return null
		_assets = script.new()
		ResourceLoader.add_resource_format_loader(_assets, true)
	return _assets


static func _import_text(res_path: String) -> String:
	var imp := res_path + ".import"
	if not FileAccess.file_exists(imp):
		return ""
	return FileAccess.get_file_as_string(imp)


static func _import_field(text: String, rx, pattern: String) -> String:
	if text == "":
		return ""
	if rx == null:
		rx = RegEx.new()
		if rx.compile(pattern) != OK:
			return ""
		if pattern.begins_with("path="):
			_import_rx = rx
		else:
			_uid_rx = rx
	var found: RegExMatch = rx.search(text)
	if found == null:
		return ""
	return found.get_string(1)


## A depth cap, since a folder link inside a mod could loop.
const _WALK_DEPTH := 16


static func _walk(dir: String, prefix: String, out: Array, json_only: bool, depth := 0) -> void:
	if not _dir_exists(dir) or depth > _WALK_DEPTH:
		return
	for file_v in DirAccess.get_files_at(dir):
		var name := str(file_v)
		if name.begins_with(".") or name.ends_with(".import"):
			continue
		if json_only and not name.ends_with(".json"):
			continue
		out.append(prefix + name)
	for sub_v in DirAccess.get_directories_at(dir):
		var sub := str(sub_v)
		if sub.begins_with(".") or sub == ".godot":
			continue
		_walk(dir.path_join(sub), prefix + sub + "/", out, json_only, depth + 1)


static func _dir_exists(dir: String) -> bool:
	return dir != "" and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir))
