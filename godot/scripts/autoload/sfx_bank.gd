extends Node

## One-shot effects in res://assets/sfx/. Call SfxBank.play("footstep1") — a Sounds.xml id
## (file stem, no extension); an id with variants picks one at random.
##
## Wired from gameplay (Sound.ps call sites of the original):
##   footsteps — footstep / metalstep 1-4 (+a) by floor, lazstep on ladders
##   gunfire   — each weapon snd_shoot at Sound.ps volume 1, plus gun_empty
##   impact    — Bullet.sound by material; udarUnit by damage type; explVis by blast type
##   world     — objs.xml open / close / die / fall, sndAct, loot fall, artfire
##   pers      — levelup, skill, lowhp, nomagic, pot_use, bonus1 / bonus2
##   ui        — PipBuck pip1-3, ui_click on main menu and pause buttons

const _DIR := "res://assets/sfx/"
const _VOICES := 8
## Sounds.xml rows with several <s> children: Sound.ps picks one at random.
const VARIANTS := {
	"artfire": 2, "fang_hit": 3, "geiger": 3, "vortex_cut": 3, "rm": 6, "rw": 6,
	"ali": 3, "sr": 3, "zm": 3, "zw": 3, "bat": 2, "bloat": 4,
}

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	# Pause menu clicks happen while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _i in _VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)


func play(name: String, volume: float = 1.0) -> void:
	if volume <= 0.0:
		return
	if VARIANTS.has(name):
		name = "%s%d" % [name, randi_range(1, int(VARIANTS[name]))]
	var stream := _stream(name)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	# Linear gain, same scale as Sound.ps. 1 is a full effect. Footsteps pass 0.1.
	player.volume_db = linear_to_db(minf(volume, 1.0))
	player.play()


func _stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var wav := _DIR + name + ".wav"
	if ResourceLoader.exists(wav):
		var imported := load(wav) as AudioStream
		if imported != null:
			_cache[name] = imported
			return imported
	var mp3 := _DIR + name + ".mp3"
	if ResourceLoader.exists(mp3):
		var clip := load(mp3) as AudioStream
		if clip == null:
			push_warning("SfxBank: empty sfx '%s'" % name)
			return null
		_cache[name] = clip
		return clip
	push_warning("SfxBank: missing sfx '%s'" % name)
	return null
