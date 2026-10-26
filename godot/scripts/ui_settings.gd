class_name UiSettings
extends RefCounted

## PipPageOpt Настройки that the port can honour: opt1_1 sound volume,
## opt1_2 music volume, language, the new-game difficulty (dif0..dif4) and
## the port's gamepad options.
## Saved at user://settings.cfg. Music and sound get their own buses so the
## two sliders stay independent.

const _UserDir := preload("res://scripts/user_dir.gd")
static var PATH := _UserDir.settings("settings.cfg")
const MUSIC_BUS := "Music"
const SOUND_BUS := "Sound"
const FLAGS := {"zoom100": false, "hint_tele": true, "sys_cur": false, "show_favs": true, "err_show": true}

static var _cfg: ConfigFile


static func value(section: String, key: String, fallback: Variant) -> Variant:
	_ensure()
	return _cfg.get_value(section, key, fallback)


static func set_value(section: String, key: String, v: Variant) -> void:
	_ensure()
	_cfg.set_value(section, key, v)
	_cfg.save(PATH)


static func sound_volume() -> float:
	return float(value("audio", "sound", 1.0))


static func music_volume() -> float:
	return float(value("audio", "music", 1.0))


static func set_sound_volume(v: float) -> void:
	set_value("audio", "sound", clampf(v, 0.0, 1.0))
	apply_audio()


static func set_music_volume(v: float) -> void:
	set_value("audio", "music", clampf(v, 0.0, 1.0))
	apply_audio()


static func difficulty() -> int:
	return int(value("game", "difficulty", 2))


static func set_difficulty(n: int) -> void:
	set_value("game", "difficulty", clampi(n, 0, 4))


static func language() -> String:
	return OriginalLines.language()


static func languages() -> PackedStringArray:
	var out: PackedStringArray = []
	for lang in ["ru", "en"]:
		if FileAccess.file_exists(OriginalLines.PATH % lang):
			out.append(lang)
	return out


## Goes through Locale so every open screen relabels.
static func set_language(lang: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var locale: Node = tree.root.get_node_or_null("Locale") if tree != null else null
	if locale != null:
		locale.call("set_language", lang)
		return
	set_value("ui", "language", lang)
	OriginalLines.set_language(lang)


## Port extras for gamepads: stick dead zone, right-stick cursor speed and
## the gentle aim assist.
## Left stick (movement). The right-stick cursor uses 0.1 less, so the
## defaults keep the old 0.35 / 0.25 pair.
static func stick_deadzone() -> float:
	return clampf(float(value("input", "deadzone", 0.35)), 0.05, 0.9)


static func set_stick_deadzone(v: float) -> void:
	set_value("input", "deadzone", clampf(snappedf(v, 0.05), 0.05, 0.9))


static func aim_sensitivity() -> float:
	return clampf(float(value("input", "aim_speed", 1.0)), 0.25, 3.0)


static func set_aim_sensitivity(v: float) -> void:
	set_value("input", "aim_speed", clampf(snappedf(v, 0.05), 0.25, 3.0))


static func aim_assist() -> bool:
	return bool(value("input", "aim_assist", true))


static func set_aim_assist(on: bool) -> void:
	set_value("input", "aim_assist", on)


## Aim assist pull toward a target, 1.0 = aim_cursor default.
static func assist_pull() -> float:
	return clampf(float(value("input", "assist_pull", 1.0)), 0.0, 2.0)


static func set_assist_pull(v: float) -> void:
	set_value("input", "assist_pull", clampf(snappedf(v, 0.05), 0.0, 2.0))


## Share of cursor speed lost over a target.
static func assist_slow() -> float:
	return clampf(float(value("input", "assist_slow", 0.25)), 0.0, 0.6)


static func set_assist_slow(v: float) -> void:
	set_value("input", "assist_slow", clampf(snappedf(v, 0.05), 0.0, 0.6))


## GameContainer.quakeCam: whether World.quake moves the view.
static func quake_cam() -> bool:
	return bool(value("game", "quake_cam", true))


static func set_quake_cam(on: bool) -> void:
	set_value("game", "quake_cam", on)


## Sound.stepVol: footsteps on top of the sound volume.
static func step_volume() -> float:
	return clampf(float(value("audio", "step", 0.5)), 0.0, 1.0)


static func set_step_volume(v: float) -> void:
	set_value("audio", "step", clampf(v, 0.0, 1.0))


## GameContainer.showHit: 0 no damage numbers, 1 per hit, 2 summed into one.
static func show_hit() -> int:
	return clampi(int(value("game", "show_hit", 2)), 0, 2)


static func set_show_hit(n: int) -> void:
	set_value("game", "show_hit", clampi(n, 0, 2))


## GameContainer zoom100, hintTele, sysCur, showFavs, errorShowOpt.
static func flag(key: String) -> bool:
	return bool(value("game", key, FLAGS.get(key, true)))


static func set_flag(key: String, on: bool) -> void:
	set_value("game", key, on)


static func apply_audio() -> void:
	var music := _bus(MUSIC_BUS)
	var sound := _bus(SOUND_BUS)
	AudioServer.set_bus_volume_db(music, linear_to_db(maxf(music_volume(), 0.0001)))
	AudioServer.set_bus_mute(music, music_volume() <= 0.001)
	AudioServer.set_bus_volume_db(sound, linear_to_db(maxf(sound_volume(), 0.0001)))
	AudioServer.set_bus_mute(sound, sound_volume() <= 0.001)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var am := tree.root.get_node_or_null("AudioManager")
	if am != null:
		var player: Variant = am.get("_music")
		if player is AudioStreamPlayer:
			(player as AudioStreamPlayer).bus = MUSIC_BUS
	var sfx := tree.root.get_node_or_null("SfxBank")
	if sfx != null:
		for child in sfx.get_children():
			if child is AudioStreamPlayer:
				(child as AudioStreamPlayer).bus = SOUND_BUS


static func _bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
	return index


static func _ensure() -> void:
	if _cfg != null:
		return
	_cfg = ConfigFile.new()
	_cfg.load(PATH)
