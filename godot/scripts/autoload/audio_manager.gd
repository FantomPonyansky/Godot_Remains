extends Node

## Snd.as music. One channel plays the current track; the one it replaced
## fades out on a second channel. A room plays its options music, else its
## land's (Lands.xml options music), else music_0, which has no file and so
## is silence (World.ativateLoc -> Snd.playMusic(loc.sndMusic)). A unit with
## <snd music> that is after the player calls combat() each tick
## (Unit.setCel); combat music holds 150 ticks after the last call, 10000 for
## a boss, then the room music comes back. A land with options postmusic
## keeps its music through fights. Script music / music_rep and dialog music
## replace the track until the next room change.
## Volume: the Music bus is the settings slider; BASE_DB is the port's mix.

const BASE_DB := -8.0
const MENU_DB := -10.0
const LOOP := 10000
const SILENT := "music_0"
const FADE_TICKS := 100
const COMBAT_TICKS := 150
const BOSS_TICKS := 10000
const BOSS_DEATH_TICKS := 90
const DATA := "res://assets/data/music.json"
const RoomFile := preload("res://scripts/map/room_file.gd")
const Registry := preload("res://scripts/map/land_registry.gd")
## Unit classes that set boss = true and carry <snd music>.
const BOSSES := ["bossultra", "bossraider", "bossnecr", "bossdron", "bossalicorn"]

## World.currentMusic: the room's track that combat and script music give back to.
var current_music := ""
var _music: AudioStreamPlayer
var _prev: AudioStreamPlayer
var _name := ""
var _has_ch := false
var _rep_left := 0
var _prior := 0
var _t_music := 0
var _prev_db := BASE_DB
var _t_combat := 0
var _land_ref := 0
var _room_key := ""
var _post_music := false
var _art_t := 0
var _units: Dictionary = {}
## Bosses that called combat(): instance id -> [track, prior].
var _bosses: Dictionary = {}
## Travel registers these. No listener: not hard-dead, and art does not check a trigger.
var _hard_dead: Callable = Callable()
var _land_trigger: Callable = Callable()


func bind_travel(hard_dead: Callable, land_trigger: Callable) -> void:
	_hard_dead = hard_dead
	_land_trigger = land_trigger


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sim.register(Sim.Phase.PRESENTATION, _tick)
	_music = _player("MusicPlayer")
	_music.finished.connect(_on_finished)
	_prev = _player("MusicFade")
	if FileAccess.file_exists(DATA):
		var parsed: Variant = DataLib.load(DATA)
		if parsed is Dictionary:
			_units = (parsed as Dictionary).get("units", {})


func _exit_tree() -> void:
	Sim.unregister(_tick)


func _player(node_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.bus = UiSettings.MUSIC_BUS
	add_child(p)
	return p


## Snd.playMusic: switch to track id (rep plays, <= 0 loops). The same track
## already on its channel is left alone.
func play(id: String, rep: int = 0) -> void:
	if id == _name and _has_ch:
		return
	_name = id
	if _has_ch:
		if _prev.playing or _t_music > 0:
			_prev.stop()
		_swap_channels()
		_t_music = FADE_TICKS
	_prior = 0
	_has_ch = false
	var path := "res://assets/music/%s.mp3" % id
	if id == "" or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var times := rep if rep > 0 else LOOP
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = times >= LOOP
	_rep_left = times
	_music.stream = stream
	_music.volume_db = MENU_DB if id == "mainmenu" else BASE_DB
	_music.play()
	_has_ch = true


## Snd.combatMusic: hold combat music for ticks; a higher prior takes the channel.
func combat(id: String, prior: int = 0, ticks: int = COMBAT_TICKS) -> void:
	_t_combat = ticks
	if prior > _prior:
		_prior = prior
		play(id)


## The track a unit id plays in combat, or "".
func unit_music(unit_id: String) -> String:
	var row: Variant = _units.get(unit_id)
	return str((row as Array)[0]) if row is Array else ""


func stop_music() -> void:
	_music.stop()
	_prev.stop()
	_t_music = 0


func play_menu() -> void:
	play("mainmenu")


func play_begin() -> void:
	play("music_begin")


func play_game() -> void:
	combat("combat_1", 1)


## Script music / music_rep / dialog music: times > 0 plays it that many times.
func play_story(id: String, times: int = 0) -> void:
	play(id, times)


## A new land: its first room plays its music on the next tick.
func clear_story() -> void:
	_room_key = ""


func _swap_channels() -> void:
	var old := _music
	_music.finished.disconnect(_on_finished)
	_music = _prev
	_prev = old
	_prev_db = _prev.volume_db
	_music.bus = _prev.bus
	_music.finished.connect(_on_finished)


func _on_finished() -> void:
	if not _has_ch:
		return
	_rep_left -= 1
	if _rep_left > 0:
		_music.play()


## Snd.step plus the per-tick World/Unit calls the port has no other home for.
func _tick() -> void:
	var in_game := _active_land() != null and _player_node() != null
	var hard_dead := _hard_dead.is_valid() and bool(_hard_dead.call())
	if not in_game:
		_t_combat = 0
		_bosses.clear()
		_room_key = ""
	elif not hard_dead:
		_watch_room()
		_watch_units()
		if not _paused():
			_art_step()
	if _t_music > 0 and _prev.playing:
		if _t_music % 10 == 1:
			_prev.volume_db = _prev_db + linear_to_db(float(_t_music) / FADE_TICKS)
		if _t_music <= 5:
			_prev.stop()
			_t_music = 0
		_t_music -= 5 if _t_combat > 0 else 1
	if _t_combat > 0:
		if _t_combat == 1:
			_prior = 0
			play(current_music)
		if not _paused():
			_t_combat -= 1


func _watch_room() -> void:
	var land := _active_land()
	var at := _player_node().global_position
	var room := Vector2i(floori(at.x / 1920.0), floori(at.y / 1000.0))
	var key := "%d|%d|%d" % [land.get_instance_id(), room.x, room.y]
	if key == _room_key:
		return
	_room_key = key
	if land.get_instance_id() != _land_ref:
		_land_ref = land.get_instance_id()
		_bosses.clear()
	var land_id := _land_id(land)
	var land_opts: Dictionary = Registry.land(land_id).get("options", {})
	_post_music = land_opts.has("postmusic")
	var music := str(land_opts.get("music", SILENT))
	var room_opts := _room_options(land, land_id, room, at)
	if room_opts.has("music"):
		music = str(room_opts.music)
	current_music = music
	play(current_music)


## Land.artStep: a land with options art shells the area every 20..1019 ticks
## until that trigger is 1 (artBabah: Sound.ps artfire, World.quake(10, 3)).
func _art_step() -> void:
	_art_t -= 1
	if _art_t > 0:
		return
	_art_t = int(Rng.randf(&"fx") * 1000.0 + 20.0)
	var art := str(Registry.land(_land_id(_active_land())).get("options", {}).get("art", ""))
	if art == "" or not _land_trigger.is_valid():
		return
	if str(_land_trigger.call(art)) == "1":
		return
	Fx.sound("artfire", Vector2.ZERO)
	if CamShake != null:
		Fx.shake(10.0, Vector2.ZERO, {"x": 10.0, "y": 3.0})


func _watch_units() -> void:
	var dead: Array = []
	for id in _bosses:
		var boss: Variant = instance_from_id(id)
		if not is_instance_valid(boss) or bool((boss as Node).get("_dead")):
			dead.append(id)
	for id in dead:
		var row: Array = _bosses[id]
		_bosses.erase(id)
		combat(str(row[0]), int(row[1]), BOSS_DEATH_TICKS)
	if _post_music:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.has_method("is_alert") or bool(enemy.get("_dead")) or not enemy.is_alert():
			continue
		var uid := _unit_id(enemy)
		var row: Variant = _units.get(uid)
		if not row is Array:
			continue
		var boss := _is_boss(uid)
		if boss:
			_bosses[enemy.get_instance_id()] = row
		combat(str(row[0]), int(row[1]), BOSS_TICKS if boss else COMBAT_TICKS)


func _room_options(land: Node, land_id: String, room: Vector2i, at: Vector2) -> Dictionary:
	if land_id == "begin":
		for room_v in RoomFile.load_doc("rooms_begin").get("rooms", []):
			var r: Dictionary = room_v
			if int(r.get("x", -999)) == room.x and int(r.get("y", -999)) == room.y and int(r.get("z", 0)) == 0:
				return r.get("options", {})
		return {}
	var props := land.get_node_or_null("Actors")
	if props != null and props.has_method("room_options_at"):
		return props.call("room_options_at", at)
	return {}


func _unit_id(enemy: Node) -> String:
	var species: Variant = enemy.get("_species_id")
	if species != null and str(species) != "":
		return str(species)
	return str(enemy.get_meta("unit_id", ""))


func _is_boss(uid: String) -> bool:
	for prefix in BOSSES:
		if uid.begins_with(prefix):
			return true
	return false


func _land_id(land: Node) -> String:
	var value: Variant = land.get("land_id")
	return str(value) if value != null and str(value) != "" else "begin"


func _active_land() -> Node:
	return Run.land() if is_inside_tree() else null


func _player_node() -> Node2D:
	return Run.local_player() as Node2D


func _paused() -> bool:
	return Sim.paused()
