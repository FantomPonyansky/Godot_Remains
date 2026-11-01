extends Node

## Loads every .gd under res://scripts and res://tests so scripts that the game
## loads lazily get compiled too (a headless boot only compiles what it uses).
## A scene, not -s, so autoload names resolve.
## Prints `CHECK compile_all: ok N fail M`; quits 1 when any script fails.

const ROOTS: PackedStringArray = ["res://scripts", "res://tests"]


func _ready() -> void:
	var files: Array[String] = []
	for root in ROOTS:
		_walk(root, files)
	var ok := 0
	var bad: Array[String] = []
	for path in files:
		var s := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as GDScript
		if s != null and s.can_instantiate():
			ok += 1
		else:
			bad.append(path)
	for path in bad:
		print("FAIL ", path)
	print("CHECK compile_all: ok %d fail %d" % [ok, bad.size()])
	get_tree().quit(1 if not bad.is_empty() else 0)


func _walk(dir_path: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir_path):
		_walk(dir_path.path_join(sub), out)
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
