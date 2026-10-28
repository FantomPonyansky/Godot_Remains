extends Node

## Where settings, run files, save slots and logs live. An exported build
## keeps them next to the executable (settings/, saves/, logs/); the editor
## binary (unless --user-local), --user-appdata, or a read-only game folder
## keep user://.
## Autoloaded first so the log starts before the other autoloads.

const SETTINGS_FILES: PackedStringArray = [
	"settings.cfg", "controls.cfg", "camera.cfg", "autopick.cfg", "magic_binds.cfg", "appearance.cfg",
]
const RUN_FILES: PackedStringArray = [
	"inventory.cfg", "progression.cfg", "condition.cfg", "body_pools.cfg", "pets.cfg",
]
const MAX_LOGS := 30

static var _base: Variant = null
static var _why := ""
static var _sandbox := false


func _init() -> void:
	if base() != "user://" and not _sandbox:
		_migrate()
	if not OS.has_feature("editor") or _sandbox:
		_start_log()
		print("user dir: %s (exe %s) %s" % [ProjectSettings.globalize_path(base()), OS.get_executable_path(), _why])
	_load_patches()


## Exported build: patches/*.pck next to the executable, in name order, over
## the main pack. A patch cannot change project.godot, autoload lists or
## class_name scripts that were already loaded; those need a full build.
static func _load_patches() -> void:
	if OS.has_feature("editor"):
		return
	var dir := OS.get_executable_path().get_base_dir().replace("\\", "/") + "/patches/"
	if not DirAccess.dir_exists_absolute(dir):
		return
	var packs := Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.ends_with(".pck"))
	packs.sort()
	for pack in packs:
		var ok := ProjectSettings.load_resource_pack(dir + str(pack), true)
		print("patch %s: %s" % [pack, "loaded" if ok else "FAILED"])


static func base() -> String:
	if _base == null:
		_base = _pick_base()
	return _base


static func local() -> bool:
	return base() != "user://"


static func settings(file: String) -> String:
	return base() + "settings/" + file if local() else "user://" + file


static func run(file: String) -> String:
	return base() + "saves/" + file if local() else "user://" + file


static func saves() -> String:
	return base() + "saves/" if local() else "user://saves/"


## Player rooms from the shipped editor. RoomFile reads these over the built-in files.
static func mods() -> String:
	return base() + "mods/" if local() else "user://mods/"


static func mods_rooms() -> String:
	return mods() + "rooms/"


static func _pick_base() -> String:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--user-dir="):
			var own := _own_dir(arg.trim_prefix("--user-dir="))
			if own != "":
				_sandbox = true
				return own
	if args.has("--user-appdata") or (OS.has_feature("editor") and not args.has("--user-local")):
		return "user://"
	var dir := OS.get_executable_path().get_base_dir().replace("\\", "/") + "/"
	for sub in ["settings", "saves", "logs"]:
		var err := DirAccess.make_dir_recursive_absolute(dir + sub)
		if err != OK:
			_why = "mkdir %s: %s" % [sub, error_string(err)]
			return "user://"
	var probe := FileAccess.open(dir + "settings/.write_test", FileAccess.WRITE)
	if probe == null:
		_why = "write test: %s" % error_string(FileAccess.get_open_error())
		return "user://"
	probe.close()
	DirAccess.remove_absolute(dir + "settings/.write_test")
	return dir


## --user-dir=<path> (verify/ kit): settings, saves and logs in that folder,
## with nothing copied in from AppData.
static func _own_dir(path: String) -> String:
	var dir := path.strip_edges().replace("\\", "/").trim_suffix("/") + "/"
	for sub in ["settings", "saves", "logs"]:
		if DirAccess.make_dir_recursive_absolute(dir + sub) != OK:
			_why = "user-dir %s not writable" % dir
			return ""
	return dir


## One-time copy of an older AppData install into the game folder.
static func _migrate() -> void:
	if FileAccess.file_exists(settings("settings.cfg")) or not FileAccess.file_exists("user://settings.cfg"):
		return
	for file in SETTINGS_FILES:
		if FileAccess.file_exists("user://" + file):
			DirAccess.copy_absolute("user://" + file, settings(file))
	for file in RUN_FILES:
		if FileAccess.file_exists("user://" + file):
			DirAccess.copy_absolute("user://" + file, run(file))
	for slot in DirAccess.get_directories_at("user://saves"):
		var src := "user://saves/%s/" % slot
		var dst := saves() + slot + "/"
		DirAccess.make_dir_recursive_absolute(dst)
		for file in DirAccess.get_files_at(src):
			DirAccess.copy_absolute(src + file, dst + file)


static func _start_log() -> void:
	var dir := base() + "logs/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var old := Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.ends_with(".log"))
	old.sort()
	while old.size() >= MAX_LOGS:
		DirAccess.remove_absolute(dir + str(old.pop_front()))
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", ".").replace("T", "_")
	var file := FileAccess.open(dir + "godot_%s.log" % stamp, FileAccess.WRITE)
	if file == null:
		return
	file.store_line("%s %s" % [ProjectSettings.get_setting("application/config/name"), OS.get_name()])
	file.flush()
	OS.add_logger(_FileLog.new(file))


class _FileLog extends Logger:
	var _file: FileAccess
	var _lock := Mutex.new()

	func _init(file: FileAccess) -> void:
		_file = file

	func _log_message(message: String, _error: bool) -> void:
		_write(message.trim_suffix("\n"))

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var kind: String = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][clampi(error_type, 0, 3)]
		var text := "%s: %s\n   at: %s (%s:%d)" % [kind, rationale if rationale != "" else code, function, file, line]
		for bt in script_backtraces:
			text += "\n" + bt.format(3, 3)
		_write(text)

	func _write(text: String) -> void:
		_lock.lock()
		_file.store_line(text)
		_file.flush()
		_lock.unlock()
