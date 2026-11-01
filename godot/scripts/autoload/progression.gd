extends Node

## XP, skills, and perks. Numbers are from Remains-Source2 Pers.as,
## PipPageStat.as, and Modules/core/AllData/skills.xml + perks.xml.
##
## Level curve (Pers.xpProgress, xpDelta 5000, version-1 formula):
##   mn = 1, or (level-10)/30+1 when level > 10
##   threshold(level) = round(xpDelta * level * (level+1) / 2 * mn * mn / 1000) * 1000
## Cumulative. Level 1->2 is 5000 XP, level 2->3 is 15000 total. No level cap.
## Pers.expa levels at most once per grant (upLevel runs once). Each level gives
## levelSkAdd (5) skill points and one perk point.
##
## Skills: normal skills cap at maxSkLvl (20) points. Attack, Defense, and
## Knowledge cap at maxPostSkLvl (100) and can only take points from character
## level postPersLevel (20). Each Knowledge level (postSkTab) gives a perk point.
## Perks with tip 0 (chart false) are never chosen with perk points.
##
## skills.xml values marked dop='1' scale with raw points. The rest scale with
## the skill level (getSkLevel: 2/5/9/14/20 points for levels 1-5).
##
## Public API for the PipBuck and the level-up screen:
##   spend_skill(id, n = 1) -> bool       one or more skill points into a skill
##   can_raise_skill(id) -> bool           a point would be accepted now
##   skill_cap(id) -> int                  20, or 100 for post skills
##   skill_visible(id) -> bool             post skills hide below level 20
##   take_perk(id) -> bool                 spend a perk point (alias spend_perk)
##   perk_status(id) -> int                Pers.perkPoss: -1 maxed, 0 locked, 1 ready
##   choosable_perks() -> Array            tip 1 perks for the perk page
##   upskill_from_book(id) -> bool         Pers.upSkill (skill books)
##   add_xp(n), add_kill_xp(unit_xp), add_container_xp(xp, all_dif)
## Signals: changed, leveled_up(level), points_changed(skill, perk),
##   skill_raised(id, points), perk_taken(id, rank), xp_gained(amount, total)

signal changed
signal leveled_up(new_level: int)
signal points_changed(skill_points: int, perk_points: int)
signal skill_raised(id: String, points: int)
signal perk_taken(id: String, rank: int)
signal xp_gained(amount: int, total: int)
## GameState keeps the health ratio across the new max before changed.
signal rescale_health
## Condition fills these. Progression does not name Condition.
signal armor_row_query(id: String, reply: Dictionary)
signal armor_level_query(id: String, reply: Dictionary)

const Difficulty := preload("res://scripts/difficulty.gd")
const MAX_RANK := 20
const MAX_POST_RANK := 100
const POST_PERS_LEVEL := 20
const _BALANCE := "res://assets/data/balance/progression.json"
static var _balance_loaded := false
static var XP_DELTA := 5000
static var XP_DELTA_FAST := 3000
static var XP_BEND_LEVEL := 10
static var XP_BEND_SPAN := 30
static var XP_ROUND := 1000
static var LEVEL_SK_ADD := 5
static var LEVEL_SK_ADD_HARD := 3
## GameContainer.unitXPMult. Unit.xp = units.xml xp * 2.
static var UNIT_XP_MULT := 2.0
const POST_SK_TAB: Array = [5, 11, 18, 26, 35, 45, 56, 68, 82, 100]
const POST_SKILLS: PackedStringArray = ["attack", "defense", "knowl"]
const _UserDir := preload("res://scripts/user_dir.gd")
static var SAVE_PATH := _UserDir.run("progression.cfg")
const SKILLS_PATH := "res://assets/data/skills.json"
const PERKS_PATH := "res://assets/data/perks.json"

## skills.xml tele, indexed by skill level 0-5.
static var MAX_TELE_MASSA: Array = [0.6, 1.6, 3.0, 6.0, 12.0, 25.0]
static var TELE_POROG: Array = [0.1, 0.2, 0.3, 0.5, 0.8, 1.2]
static var TELE_ACCEL: Array = [1.0, 1.1, 1.2, 1.35, 1.6, 2.0]
static var UNIT_LEVIT_MULT: Array = [0.5, 1.0, 1.3, 1.6, 2.0, 2.5]
## Pers.inMaxMana. perks.xml spirit adds 20 per rank.
const IN_MAX_MANA := 400.0

const _ProgressionState := preload("res://scripts/character/progression_state.gd")
var _progression_ref: _ProgressionState

## This autoload's fields live on Run.character().progression; the properties below forward there.
func _progression() -> _ProgressionState:
	if _progression_ref == null:
		_progression_ref = Run.character().progression
	return _progression_ref

var level: int:
	get: return _progression().level
	set(value): _progression().level = value
var xp: int:
	get: return _progression().xp
	set(value): _progression().xp = value
var xp_next: int:
	get: return _progression().xp_next
	set(value): _progression().xp_next = value
var skill_points: int:
	get: return _progression().skill_points
	set(value): _progression().skill_points = value
var perk_points: int:
	get: return _progression().perk_points
	set(value): _progression().perk_points = value
## New-game options kept with the run (Pers.xpDelta, levelSkAdd, rndpump):
## fastxp sets xpDelta 3000, hardskills levelSkAdd 3, rndpump spends points at random.
var xp_delta: int:
	get: return _progression().xp_delta
	set(value): _progression().xp_delta = value
var level_sk_add: int:
	get: return _progression().level_sk_add
	set(value): _progression().level_sk_add = value
var rndpump: bool:
	get: return _progression().rndpump
	set(value): _progression().rndpump = value

var _perk_extra: int:
	get: return _progression()._perk_extra
	set(value): _progression()._perk_extra = value
var _applied_max: int:
	get: return _progression()._applied_max
	set(value): _progression()._applied_max = value
var _ranks: Dictionary:
	get: return _progression()._ranks
	set(value): _progression()._ranks = value
var _perks: Dictionary:
	get: return _progression()._perks
	set(value): _progression()._perks = value
var _meta: Dictionary = {}
var _skill_list: Array = []
var _perk_list: Array = []
var _skills_by_id: Dictionary = {}
var _perks_by_id: Dictionary = {}


const STATE_VERSION := 1


func _ready() -> void:
	_listen_below()
	_load_catalog()
	_load()
	(func() -> void: _applied_max = max_health()).call_deferred()
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	call_deferred("_register_run")


func _register_run() -> void:
	var world := WorldState
	if world != null and world.has_method("register_run"):
		world.call("register_run", "progression", get_state, set_state)


func _listen_below() -> void:
	if not Effects.max_health_query.is_connected(_on_max_health_query):
		Effects.max_health_query.connect(_on_max_health_query)
	if not Effects.perk_rank_query.is_connected(_on_perk_rank_query):
		Effects.perk_rank_query.connect(_on_perk_rank_query)
	if not Effects.grant_perk_asked.is_connected(grant_perk):
		Effects.grant_perk_asked.connect(grant_perk)
	if not Inventory.perk_rank_query.is_connected(_on_perk_rank_query):
		Inventory.perk_rank_query.connect(_on_perk_rank_query)


func _on_max_health_query(reply: Dictionary) -> void:
	reply.v = max_health()


func _on_perk_rank_query(id: String, reply: Dictionary) -> void:
	reply.v = perk_rank(id)


func _armor_row(id: String) -> Dictionary:
	var reply := {"row": {}}
	armor_row_query.emit(id, reply)
	var row: Variant = reply.row
	return (row as Dictionary) if row is Dictionary else {}


func _armor_level(id: String) -> int:
	var reply := {"v": 0}
	armor_level_query.emit(id, reply)
	return int(reply.v)


static func _ensure_balance() -> void:
	if _balance_loaded:
		return
	_balance_loaded = true
	var raw: Variant = DataLib.load(_BALANCE)
	if raw is not Dictionary:
		return
	var d := raw as Dictionary
	XP_DELTA = int(d.get("xp_delta", XP_DELTA))
	XP_DELTA_FAST = int(d.get("xp_delta_fast", XP_DELTA_FAST))
	XP_BEND_LEVEL = int(d.get("xp_bend_level", XP_BEND_LEVEL))
	XP_BEND_SPAN = int(d.get("xp_bend_span", XP_BEND_SPAN))
	XP_ROUND = int(d.get("xp_round", XP_ROUND))
	LEVEL_SK_ADD = int(d.get("level_sk_add", LEVEL_SK_ADD))
	LEVEL_SK_ADD_HARD = int(d.get("level_sk_add_hard", LEVEL_SK_ADD_HARD))
	UNIT_XP_MULT = float(d.get("unit_xp_mult", UNIT_XP_MULT))
	var massa: Variant = d.get("max_tele_massa", null)
	if massa is Array:
		MAX_TELE_MASSA = massa
	var porog: Variant = d.get("tele_porog", null)
	if porog is Array:
		TELE_POROG = porog
	var accel: Variant = d.get("tele_accel", null)
	if accel is Array:
		TELE_ACCEL = accel
	var levit: Variant = d.get("unit_levit_mult", null)
	if levit is Array:
		UNIT_LEVIT_MULT = levit


func reset_run() -> void:
	_ensure_balance()
	level = 1
	xp = 0
	skill_points = 0
	perk_points = 0
	_perk_extra = 0
	_applied_max = 0
	_ranks.clear()
	_perks.clear()
	xp_delta = XP_DELTA_FAST if bool(UiSettings.value("game", "fastxp", false)) else XP_DELTA
	level_sk_add = LEVEL_SK_ADD_HARD if bool(UiSettings.value("game", "hardskills", false)) else LEVEL_SK_ADD
	rndpump = bool(UiSettings.value("game", "rndpump", false))
	if bool(UiSettings.value("game", "propusk", false)):
		_perks["levitation"] = 1
	xp_next = xp_progress(level)
	_applied_max = max_health()
	_save()
	points_changed.emit(skill_points, perk_points)
	changed.emit()


func get_skill_rank(skill_name: String) -> int:
	var key := skill_name.strip_edges().to_lower()
	if key in ["levitation", "tele", "telekinesis"]:
		return rank("tele")
	return rank(_alias(key))


func rank(id: String) -> int:
	return int(_ranks.get(id, 0))


func perk_rank(id: String) -> int:
	return int(_perks.get(id, 0))


func skills() -> Array:
	return _skill_list


func perks() -> Array:
	return _perk_list


func choosable_perks() -> Array:
	var out: Array = []
	for entry_v in _perk_list:
		if typeof(entry_v) == TYPE_DICTIONARY and bool((entry_v as Dictionary).get("chart", true)):
			out.append(entry_v)
	return out


func is_post(id: String) -> bool:
	return id in POST_SKILLS


func skill_level_of(id: String) -> int:
	return skill_level(rank(id), is_post(id))


func skill_level(points: int, post: bool) -> int:
	# Pers.getSkLevel / getPostSkLevel (postSkTab).
	if post:
		var res := 0
		for i in POST_SK_TAB.size():
			if points >= int(POST_SK_TAB[i]):
				res = i + 1
		return res
	if points >= 20:
		return 5
	if points >= 14:
		return 4
	if points >= 9:
		return 3
	if points >= 5:
		return 2
	if points >= 2:
		return 1
	return 0


func xp_progress(lvl: int) -> int:
	_ensure_balance()
	if lvl <= 0:
		return 0
	var delta := float(xp_delta)
	var mn := 1.0
	if lvl > XP_BEND_LEVEL:
		mn = float(lvl - XP_BEND_LEVEL) / float(XP_BEND_SPAN) + 1.0
	var raw := delta * float(lvl) * float(lvl + 1) / 2.0 * mn * mn / float(XP_ROUND)
	return int(round(raw)) * XP_ROUND


func add_xp(amount: int) -> void:
	# Pers.expa: one upLevel per grant, even when the XP passes two thresholds.
	if amount <= 0:
		return
	xp += amount
	xp_gained.emit(amount, xp)
	var leveled := false
	if xp >= xp_next:
		level += 1
		xp_next = xp_progress(level)
		skill_points += level_sk_add
		perk_points += 1
		leveled = true
		if rndpump:
			_auto_pump()
	_commit()
	if leveled:
		points_changed.emit(skill_points, perk_points)
		leveled_up.emit(level)
		# Pers.upLevel: infoText perkPoint, Sound.ps levelup, gg.newPart gold_spark 25.
		_info("perkPoint")
		var p := Run.local_player() as Node2D
		Fx.sound("levelup", p.global_position if p != null else Vector2.ZERO, {"source": p})
		if p != null:
			Fx.particles("gold_spark", p.global_position + Vector2(0, -39), {"kol": 25, "source": p})


func add_kill_xp(unit_xp: int) -> void:
	_ensure_balance()
	# Unit.xp = units.xml xp * unitXPMult, granted through Location.takeXP on death.
	add_xp(int(round(float(unit_xp) * UNIT_XP_MULT)))


func add_container_xp(base_xp: int, all_dif: float) -> void:
	# Interact.loot: an unbroken container with allDif > 0 gives round(xp * (allDif + 1)).
	if base_xp <= 0 or all_dif <= 0.0:
		return
	add_xp(int(round(float(base_xp) * (all_dif + 1.0))))


func skill_cap(id: String) -> int:
	return MAX_POST_RANK if is_post(id) else MAX_RANK


func skill_visible(id: String) -> bool:
	# PipPageStat hides post skills until postPersLevel.
	return not is_post(id) or level >= POST_PERS_LEVEL


func can_raise_skill(id: String) -> bool:
	if skill_points <= 0 or _skill_def(id).is_empty() or not skill_visible(id):
		return false
	return rank(id) < skill_cap(id)


func spend_skill(id: String, n: int = 1) -> bool:
	if n <= 0 or not can_raise_skill(id):
		return false
	var add := mini(n, mini(skill_points, skill_cap(id) - rank(id)))
	if add <= 0:
		return false
	_ranks[id] = rank(id) + add
	skill_points -= add
	_sync_knowledge()
	_commit()
	points_changed.emit(skill_points, perk_points)
	skill_raised.emit(id, rank(id))
	return true


func upskill_from_book(id: String) -> bool:
	# Pers.upSkill: +1 to the book's skill, or a random post skill once it is at 20.
	if _skill_def(id).is_empty():
		return false
	var target := id
	if rank(id) >= MAX_RANK:
		target = POST_SKILLS[Rng.randi(&"loot") % POST_SKILLS.size()]
		if rank(target) >= MAX_POST_RANK:
			return false
	_ranks[target] = rank(target) + 1
	_info("skillUp", OriginalLines.eff(target))
	Fx.sound("skill", Vector2.ZERO)
	_sync_knowledge()
	_commit()
	skill_raised.emit(target, rank(target))
	return true


## Pers.addSkillPoint (the memory orb: numb 1, snd).
func add_skill_point(n: int = 1) -> void:
	skill_points += n
	if n == 1:
		_info("skillPoint")
	else:
		_info("skillPoints", str(n))
	Fx.sound("skill", Vector2.ZERO)
	_commit()


func grant_perk(id: String) -> void:
	# Pers.addPerk without a perk point (scripts, potions, training).
	var def := _perk_def(id)
	if id == "" or def.is_empty():
		return
	if perk_rank(id) >= int(def.get("max_rank", 1)):
		_info("noPerk")
		return
	_perks[id] = perk_rank(id) + 1
	_perk_info(id)
	_commit()
	perk_taken.emit(id, perk_rank(id))


func raise_level(target: int) -> void:
	# Pers.setForcLevel. Does not emit leveled_up, so the character screen stays closed.
	var goal := maxi(target, 1)
	if level >= goal:
		return
	level = goal
	xp = xp_progress(level - 1)
	xp_next = xp_progress(level)
	_commit()


func raise_skill(id: String, points: int) -> void:
	if _skill_def(id).is_empty():
		return
	var goal := clampi(points, 0, skill_cap(id))
	if rank(id) >= goal:
		return
	_ranks[id] = goal
	_sync_knowledge()
	_commit()


func take_perk(id: String) -> bool:
	return spend_perk(id)


func spend_perk(id: String) -> bool:
	if perk_points <= 0:
		return false
	if perk_status(id) != 1:
		return false
	_perks[id] = perk_rank(id) + 1
	perk_points -= 1
	_perk_info(id)
	_commit()
	points_changed.emit(skill_points, perk_points)
	perk_taken.emit(id, perk_rank(id))
	return true


func perk_status(id: String) -> int:
	var def := _perk_def(id)
	if def.is_empty() or not bool(def.get("chart", true)):
		return -1
	if perk_rank(id) >= int(def.get("max_rank", 1)):
		return -1
	return 1 if _reqs_met(def) else 0


func perk_available(def: Dictionary) -> bool:
	return perk_status(str(def.get("id", ""))) == 1


func _reqs_met(def: Dictionary) -> bool:
	var current := perk_rank(str(def.get("id", "")))
	for req_v in def.get("reqs", []):
		if typeof(req_v) != TYPE_DICTIONARY:
			continue
		var req: Dictionary = req_v
		var need := int(req.get("level", 1))
		var dlvl := int(req.get("dlvl", 0))
		if current > 0 and dlvl > 0:
			need += current * dlvl
		var rid := str(req.get("id", ""))
		if rid == "level":
			if level < need:
				return false
		elif rid == "guns":
			# perkPoss compares getSkLevel, also for the post-skill ids.
			if skill_level(rank("smallguns"), false) < need and skill_level(rank("energy"), false) < need:
				return false
		elif skill_level(rank(rid), false) < need:
			return false
	return true


func requirement_text(def: Dictionary) -> String:
	var current := perk_rank(str(def.get("id", "")))
	var parts: PackedStringArray = []
	for req_v in def.get("reqs", []):
		if typeof(req_v) != TYPE_DICTIONARY:
			continue
		var req: Dictionary = req_v
		var need := int(req.get("level", 1))
		var dlvl := int(req.get("dlvl", 0))
		if current > 0 and dlvl > 0:
			need += current * dlvl
		var rid := str(req.get("id", ""))
		# PipPage: one "name: level" line per requirement, in the text pack's language.
		if rid == "level":
			parts.append("%s: %d" % [OriginalLines.pip("level"), need])
		elif rid == "guns":
			parts.append("%s %s %s: %d" % [OriginalLines.eff("smallguns"), OriginalLines.pip("or"), OriginalLines.eff("energy"), need])
		else:
			parts.append("%s: %d" % [OriginalLines.eff(rid), need])
	return "\n".join(parts)


# --- Magic and telekinesis (skills.xml magic / tele, perks.xml) ---

func spell_power() -> float:
	# magic spellPower dop: 1 + 0.1 per point.
	return Effects.stat("spellPower", 1.0 + 0.1 * float(rank("magic")))


func tele_power() -> float:
	# tele telePower dop: 1 + 0.1 per point. Kinetic blast and dash use it.
	return 1.0 + 0.1 * float(rank("tele"))


func spell_down() -> float:
	# magic spellDown v0=1 vd=-0.1 per skill level. Spell cooldown multiplier.
	return Effects.stat("spellDown", 1.0 - 0.1 * float(skill_level_of("magic")))


func rec_mana_min() -> float:
	# magic recManaMin ref add vd 0.75 per skill level, per tick.
	return 0.75 * float(skill_level_of("magic"))


func warlock_mult() -> float:
	# perks.xml warlock warlockDManaMult.
	return Effects.stat("warlockDManaMult", float([1.0, 0.8, 0.65, 0.5][clampi(perk_rank("warlock"), 0, 3)]))


func max_mana() -> float:
	return IN_MAX_MANA + 20.0 * float(perk_rank("spirit"))


func max_tele_mass() -> float:
	_ensure_balance()
	return float(MAX_TELE_MASSA[clampi(skill_level_of("tele"), 0, 5)])


func tele_porog() -> float:
	_ensure_balance()
	return float(TELE_POROG[clampi(skill_level_of("tele"), 0, 5)])


func tele_mult() -> float:
	# tele teleMult dop: 2.2 - 0.1 per point. Magic per tick is sqrt(massa) * teleMult.
	return 2.2 - 0.1 * float(rank("tele"))


func tele_speed() -> float:
	# tele teleSpeed v0=8 vd=1.5 per level, px/tick.
	return 8.0 + 1.5 * float(skill_level_of("tele"))


func tele_accel() -> float:
	_ensure_balance()
	return float(TELE_ACCEL[clampi(skill_level_of("tele"), 0, 5)])


func unit_levit_mult() -> float:
	_ensure_balance()
	return float(UNIT_LEVIT_MULT[clampi(skill_level_of("tele"), 0, 5)])


func tele_dist() -> float:
	# Pers.teleDist 600*600, telemaster 640000 (800 px).
	return 800.0 if perk_rank("telemaster") > 0 else 600.0


func throw_force() -> float:
	# telethrow sets throwForce to 0 / 25 / 35 (no ref). Effects multiply next
	# (weak 0.8, f_spsalad 1.25). Pers.armorParameters then multiplies each worn
	# piece (suit, then amulet) by magicMult. Alicorn skips armour.
	var base := float([0.0, 25.0, 35.0][clampi(perk_rank("telethrow"), 0, 2)])
	var force := Effects.stat("throwForce", base)
	if Run.alicorn or Inventory == null:
		return force
	for worn_id in Inventory.worn_ids():
		var row := _armor_row(worn_id)
		force *= float(row.get("magic", 1.0))
	return force


func throw_dmagic() -> float:
	return float([300.0, 200.0, 150.0][clampi(perk_rank("telethrow"), 0, 2)])


func levit_dmana() -> float:
	# selflevit levitDMana v1=5 v2=1 per tick, levitDManaUp v1=20 v2=4 when rising.
	return 1.0 if perk_rank("selflevit") >= 2 else 5.0


func levit_dmana_up() -> float:
	return 4.0 if perk_rank("selflevit") >= 2 else 20.0


func djump_dy() -> float:
	# tele djumpdy v0=6 vd=1 per skill level, px/tick.
	return 6.0 + float(skill_level_of("tele"))


# --- Perk sk rows (perks.json "sk", copied from perks.xml) ---

## A Pers field after every owned perk's sk rows for it (Pers.setSkillParam):
## ref add adds, ref mult multiplies, no ref sets. Ranks 0 change nothing.
func pers(sk_id: String, base: float) -> float:
	var v := base
	for perk_id in _perks:
		var lvl := perk_rank(str(perk_id))
		# GameState applies the trauma_* rows from the organ stages.
		if lvl <= 0 or str(perk_id).begins_with("trauma_"):
			continue
		for row_v in _perk_def(str(perk_id)).get("sk", []):
			var row: Dictionary = row_v
			if str(row.get("id", "")) != sk_id or row.has("tip"):
				continue
			var val := _sk_value(row, lvl)
			match str(row.get("ref", "")):
				"add":
					v += val
				"mult":
					v *= val
				_:
					v = val
	return v


func _sk_value(row: Dictionary, lvl: int) -> float:
	var ref := str(row.get("ref", ""))
	var val0 := float(row.get("v0", 1.0 if ref == "mult" else 0.0))
	if lvl <= 0:
		return val0
	if row.has("vd"):
		return val0 + float(lvl) * float(row.vd)
	var ranks: Array = row.get("v", [])
	if ranks.is_empty():
		return val0
	return float(ranks[mini(lvl, ranks.size()) - 1]) if lvl <= ranks.size() else float(ranks[0])


## Weapon.setPers weaponPerks: the perk a weapon is tied to (weapons.json perk)
## reads pers[perk + what], e.g. pistolPrec, shotKnock, commandoDet.
func weapon_perk(weapon: Dictionary, what: String, base: float) -> float:
	var perk_id := str(weapon.get("perk", ""))
	if perk_id == "":
		return base
	return pers(perk_id + what, base)


## perks.xml sk tip='res': the id is an index into the damage types. The perk
## lowers the player's vulnerability to that type by its value.
const _RES_INDEX: PackedStringArray = [
	"DAM_PIERCE", "DAM_CUT", "DAM_BLUNT", "DAM_BURN", "DAM_EXPLOSION", "DAM_LASER",
	"DAM_PLASMA", "DAM_VENOM", "DAM_EMP", "DAM_ELECTRIC", "DAM_ACID", "DAM_COLD",
	"DAM_POISON", "DAM_BLEED", "DAM_BITE",
]


func perk_vulner(damage_type: String) -> float:
	var idx := _RES_INDEX.find(damage_type)
	if idx < 0:
		return 1.0
	var v := 1.0
	for perk_id in _perks:
		var lvl := perk_rank(str(perk_id))
		if lvl <= 0:
			continue
		for row_v in _perk_def(str(perk_id)).get("sk", []):
			var row: Dictionary = row_v
			if str(row.get("tip", "")) == "res" and str(row.get("id", "")) == str(idx):
				v -= _sk_value(row, lvl)
	return maxf(v, 0.0)


## units.xml param flags the target-type perks read (Unit.damage: damPony, damRobot ...).
const _UNIT_KIND := {
	"damPony": ["raider", "bossraider", "slaver", "zebra", "ranger", "bossencl"],
	"damZombie": ["zombie"],
	"damRobot": ["robobrain", "protect", "gutsy", "eqd", "protect1", "gutsy1", "sentinel",
		"bossultra", "bossdron", "spritebot", "vortex", "roller", "msp", "roller2", "dron1",
		"dron2", "dron3", "owl", "turret0", "turret1", "turret2", "turret3", "turret4",
		"turret5", "triglaser", "transmitter", "dront", "ttur"],
	"damInsect": ["bloat", "tarakan", "scorp1", "scorp2", "scorp3", "ant"],
	"damMonster": ["bloodwing", "bloodwing2", "fish1", "fish2", "fish3", "molerat"],
	"damAlicorn": ["alicorn", "bossalicorn"],
}


## Damage from the player to this unit, by its kind (anatomy, robot, entomolog, purifier, dam_*).
func target_mult(unit: Node) -> float:
	if unit == null or not unit.has_meta("unit_id"):
		return 1.0
	var id := str(unit.get_meta("unit_id")).strip_edges().to_lower()
	var bare := id.rstrip("0123456789")
	var mult := 1.0
	for key in _UNIT_KIND:
		var ids: Array = _UNIT_KIND[key]
		if id in ids or bare in ids:
			mult *= pers(str(key), 1.0)
	return mult


# --- Combat stats ---

func get_damage_multiplier(damage_type: String = "") -> float:
	var skill_id := "smallguns"
	if damage_type in ["DAM_LASER", "DAM_BURN", "DAM_PLASMA"]:
		skill_id = "energy"
	elif damage_type == "DAM_EXPLOSION":
		skill_id = "explosives"
	var per_point := float(_skill_def(skill_id).get("damage_per_point", 0.05 if skill_id == "smallguns" else 0.0))
	var guns := 1.0 + float(rank(skill_id)) * per_point
	var per_level := float(_skill_def("attack").get("all_damage_per_level", 0.05))
	var attack := 1.0 + float(skill_level_of("attack")) * per_level
	return guns * attack


func get_crit_chance() -> float:
	# Soldier's luck, plus Critical luck if that potion perk is ranked.
	# UnitPlayer also has a flat 0.05 crit chance; that base is not rolled here.
	var chance := float(perk_rank("critch")) * float(_perk_def("critch").get("crit_per_rank", 0.05))
	chance += float(perk_rank("potion_crit")) * float(_perk_def("potion_crit").get("crit_per_rank", 0.02))
	return Effects.stat("critCh", chance)


func get_crit_damage_multiplier() -> float:
	# Pers default critDamMult is 2. Deadly criticals adds 0.4.
	var extra := float(perk_rank("critdam")) * float(_perk_def("critdam").get("crit_damage_add", 0.4))
	return Effects.stat("critDamMult", 2.0 + extra)


func aim_skill_rank(weapon: Dictionary) -> int:
	# Firearms for bullet guns. Energy weapons for laser, flame, and plasma.
	var dtype := str(weapon.get("damage_type", ""))
	var id := "smallguns"
	if dtype in ["DAM_LASER", "DAM_BURN", "DAM_PLASMA"]:
		id = "energy"
	elif dtype == "DAM_EXPLOSION":
		id = "explosives"
	elif str(weapon.get("kind", "")) == "spell":
		id = "magic"
	return rank(id)


func heavy_gun_weight(weapon: Dictionary) -> float:
	var w := float(weapon.get("weight", weapon.get("mass", 2.5)))
	if w <= 0.0:
		w = 2.5
	# perks.xml bigGunsSlow goes from 1 to 0: Size matters removes the weight penalty.
	if perk_rank("bigsize") > 0 and bool(_perk_def("bigsize").get("clears_gun_weight", false)):
		return 1.0
	return w


func scaled_bullet_damage(base_damage: int, damage_type: String = "") -> int:
	var dmg := float(base_damage) * get_damage_multiplier(damage_type)
	var chance := get_crit_chance()
	if chance > 0.0 and Rng.randf(&"combat") < chance:
		dmg *= get_crit_damage_multiplier()
	return maxi(1, int(round(dmg)))


var _armor_dexter: Dictionary = {}


## Pers.setParameters gg.dexter: 1, the dexter perks, then the worn armor's
## upd dexter (dexterNoArmor 0.25 without a suit) or alicornDexter.
func player_dexter() -> float:
	var dex := 1.0
	dex += float(perk_rank("dexter")) * float(_perk_def("dexter").get("dodge_per_rank", 0.15))
	dex += float(perk_rank("potion_dexter")) * float(_perk_def("potion_dexter").get("dodge_per_rank", 0.05))
	if Run.alicorn:
		dex += 0.1 * float(skill_level_of("sneak"))
	else:
		dex += player_dodge_plus()
	return Effects.stat("dexter", dex)


## gg.dodgePlus: armor dexter, or dexterNoArmor without a suit. UnitPlayer
## dodge is this, or 1 + this while dashing; Unit.udarUnit rolls it on body
## and club hits.
func player_dodge_plus() -> float:
	if Run.alicorn:
		return 0.0
	if _armor_dexter.is_empty():
		var path := "res://assets/data/armor_dexter.json"
		var parsed: Variant = DataLib.load(path) if FileAccess.file_exists(path) else null
		_armor_dexter = parsed if parsed is Dictionary else {"": []}
	var worn := str(Inventory.worn) if Inventory != null else ""
	var plus := 0.0 if Inventory != null and Inventory.body_armor_id(worn) != "" else 0.25
	for id in (Inventory.worn_ids() if Inventory != null else []):
		var levels: Array = _armor_dexter.get(id, [])
		if not levels.is_empty():
			var lvl := clampi(_armor_level(id), 0, levels.size() - 1)
			plus += float(levels[lvl])
	return Effects.stat("dodgePlus", plus)


var _armor_sneak: Dictionary = {}


## Armor upd sneak at the piece's level (armorParameters: visiMult *= 1 - sneak).
func armor_sneak(id: String) -> float:
	if _armor_sneak.is_empty():
		var path := "res://assets/data/armor_sneak.json"
		var parsed: Variant = DataLib.load(path) if FileAccess.file_exists(path) else null
		_armor_sneak = parsed if parsed is Dictionary else {"": []}
	var levels: Array = _armor_sneak.get(id, [])
	if levels.is_empty():
		return 0.0
	return float(levels[clampi(_armor_level(id), 0, levels.size() - 1)])


## armors.xml h2o (Armor.h2oMult); the only suits that set it.
const ARMOR_H2O := {"antirad": 0.25, "antihim": 0.25}


## Pers.armorParameters: h2oPlav *= the worn suit's h2oMult, not as a rat or the alicorn.
func armor_h2o_mult() -> float:
	if Run.alicorn or Inventory == null:
		return 1.0
	var player := Run.local_player()
	if player != null and bool(player.get("rat")):
		return 1.0
	return float(ARMOR_H2O.get(Inventory.body_armor_id(str(Inventory.worn)), 1.0))


func mitigate_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var vulner := 1.0
	vulner *= 1.0 + float(rank("survival")) * float(_skill_def("survival").get("vulner_per_point", -0.01))
	vulner *= 1.0 + float(skill_level_of("defense")) * float(_skill_def("defense").get("vulner_per_level", -0.03))
	return maxi(0, int(round(float(amount) * maxf(vulner, 0.05))))


func scale_heal(amount: int) -> int:
	# skills.xml healMult is 0.4 + 0.03*points for potions. Slice pickups are a
	# flat amount, so only the +3% per point is applied (rank 0 is unchanged).
	var per := float(_skill_def("medic").get("heal_per_point", 0.03))
	var extra := float(perk_rank("metabol")) * float(_perk_def("metabol").get("heal_add", 0.1))
	return maxi(0, int(round(float(amount) * (1.0 + float(rank("medic")) * per + extra))))


func max_health() -> int:
	# Pers.setGlobalDif: begHP, +lvlHP per level after 1 (100 and 20 on dif2).
	var base := int(Difficulty.value("beg_hp"))
	var per_level := int(Difficulty.value("lvl_hp"))
	var table: Array = _skill_def("medic").get("max_hp_by_level", [0, 20, 50, 90, 140, 200])
	var idx := clampi(skill_level_of("medic"), 0, table.size() - 1)
	var life := perk_rank("life") * int(_perk_def("life").get("max_hp_per_rank", 5))
	var base_max := base + (level - 1) * per_level + int(table[idx]) + life
	# trauma_tors multiplies maxhp: 0.9 / 0.8 / 0.6 at stages 1 / 2 / 3.
	var value := float(base_max) * Run.torso_hp_mult
	if Effects.is_node_ready():
		value = Effects.stat("maxhp", value)
	return maxi(1, int(round(value)))


func applied_max() -> int:
	return _applied_max


func note_applied_max(value: int) -> void:
	_applied_max = maxi(1, value)


## Pers.addPerk: infoText perk (name, or name-rank past the first) and Sound.ps skill.
func _perk_info(id: String) -> void:
	var r := perk_rank(id)
	_info("perk", OriginalLines.eff(id) + ("-%d" % r if r > 1 else ""))
	Fx.sound("skill", Vector2.ZERO)


func _info(id: String, a1: String = "") -> void:
	Fx.notice(OriginalLines.info(id, a1), {"source": Run.local_player()})


func _commit() -> void:
	rescale_health.emit()
	_save()
	changed.emit()


func _sync_knowledge() -> void:
	# Pers.addSkill: each Knowledge level past perkPointExtra is a perk point.
	var lv := skill_level_of("knowl")
	if lv > _perk_extra:
		perk_points += lv - _perk_extra
		_perk_extra = lv
		points_changed.emit(skill_points, perk_points)


## Pers.autoPump: every skill point, then every perk point, goes somewhere at random.
func _auto_pump() -> void:
	var n := 1000
	while skill_points > 0 and n > 0:
		var dost: Array[String] = []
		for id in _skill_ids():
			if rank(id) < MAX_RANK and not is_post(id):
				dost.append(id)
		if dost.is_empty() or (level >= POST_PERS_LEVEL and Rng.randf(&"loot") < 0.20):
			for id in _skill_ids():
				if is_post(id) and rank(id) < MAX_POST_RANK:
					dost.append(id)
			if dost.is_empty():
				break
		var sk := dost[Rng.randi(&"loot") % dost.size()]
		var kol := 2 if Rng.randf(&"loot") < 0.5 else 1
		if Rng.randf(&"loot") < 0.15:
			kol = 3
		kol = mini(skill_points, mini(kol, skill_cap(sk) - rank(sk)))
		_ranks[sk] = rank(sk) + kol
		skill_points -= kol
		_sync_knowledge()
		skill_raised.emit(sk, rank(sk))
		n -= 1
	n = 100
	while perk_points > 0 and n > 0:
		var ready: Array[String] = []
		for entry_v in _perk_list:
			if typeof(entry_v) != TYPE_DICTIONARY:
				continue
			var pid := str((entry_v as Dictionary).get("id", ""))
			if perk_status(pid) == 1:
				ready.append(pid)
		if ready.is_empty():
			break
		var pick := ready[Rng.randi(&"loot") % ready.size()]
		_perks[pick] = perk_rank(pick) + 1
		perk_points -= 1
		perk_taken.emit(pick, perk_rank(pick))
		n -= 1


func _skill_ids() -> Array[String]:
	var out: Array[String] = []
	for entry_v in _skill_list:
		if typeof(entry_v) == TYPE_DICTIONARY:
			var id := str((entry_v as Dictionary).get("id", ""))
			if id != "":
				out.append(id)
	return out


func _on_node_added(node: Node) -> void:
	if node is Area2D:
		node.ready.connect(_scale_bullet.bind(node), CONNECT_ONE_SHOT)


func _scale_bullet(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if not node.is_in_group("player_bullets"):
		return
	if node.has_meta("prog_scaled") or node.get("damage") == null:
		return
	var base := int(node.damage)
	node.set_meta("prog_base_damage", base)
	var dtype := str(node.get("damage_type")) if node.get("damage_type") != null else ""
	node.damage = scaled_bullet_damage(base, dtype)
	node.set_meta("prog_scaled", true)


func _load_catalog() -> void:
	_ensure_balance()
	_meta = {
		"xp_delta": XP_DELTA,
		"base_hp": 100,
		"hp_per_level": 20,
	}
	var skills_data = _read_json(SKILLS_PATH)
	if typeof(skills_data) == TYPE_DICTIONARY:
		var pack: Dictionary = skills_data
		if typeof(pack.get("meta")) == TYPE_DICTIONARY:
			_meta.merge(pack.get("meta"), true)
		_skill_list = pack.get("skills", [])
	var perks_data = _read_json(PERKS_PATH)
	if typeof(perks_data) == TYPE_DICTIONARY:
		_perk_list = perks_data.get("perks", [])
	_skills_by_id.clear()
	for entry_v in _skill_list:
		if typeof(entry_v) == TYPE_DICTIONARY:
			_skills_by_id[str(entry_v.get("id", ""))] = entry_v
	_perks_by_id.clear()
	for entry_v in _perk_list:
		if typeof(entry_v) == TYPE_DICTIONARY:
			_perks_by_id[str(entry_v.get("id", ""))] = entry_v
	xp_delta = XP_DELTA
	level_sk_add = LEVEL_SK_ADD
	xp_next = xp_progress(level)


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Progression missing %s" % path)
		return null
	var parsed: Variant = DataLib.load(path)
	if parsed == null:
		push_error("Progression could not parse %s" % path)
	return parsed


func _skill_def(id: String) -> Dictionary:
	var found: Variant = _skills_by_id.get(id, {})
	if typeof(found) == TYPE_DICTIONARY:
		return found
	return {}


func _perk_def(id: String) -> Dictionary:
	var found: Variant = _perks_by_id.get(id, {})
	if typeof(found) == TYPE_DICTIONARY:
		return found
	return {}


func _alias(key: String) -> String:
	match key:
		"firearms", "guns", "small guns":
			return "smallguns"
		"medicine":
			return "medic"
		"melee weapons":
			return "melee"
		"energy weapons":
			return "energy"
		"lockpicking":
			return "lockpick"
		"knowledge":
			return "knowl"
		_:
			return key


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "level", level)
	cfg.set_value("run", "xp", xp)
	cfg.set_value("run", "skill_points", skill_points)
	cfg.set_value("run", "perk_points", perk_points)
	cfg.set_value("run", "perk_extra", _perk_extra)
	cfg.set_value("run", "xp_delta", xp_delta)
	cfg.set_value("run", "level_sk_add", level_sk_add)
	cfg.set_value("run", "rndpump", rndpump)
	for id in _ranks.keys():
		cfg.set_value("ranks", str(id), int(_ranks[id]))
	for id in _perks.keys():
		cfg.set_value("perks", str(id), int(_perks[id]))
	cfg.save(SAVE_PATH)


func get_state() -> Dictionary:
	return {
		"version": STATE_VERSION,
		"level": level,
		"xp": xp,
		"skill_points": skill_points,
		"perk_points": perk_points,
		"perk_extra": _perk_extra,
		"xp_delta": xp_delta,
		"level_sk_add": level_sk_add,
		"rndpump": rndpump,
		"ranks": _ranks.duplicate(),
		"perks": _perks.duplicate(),
	}


## version 0 has the same fields and simply no version key.
func set_state(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	_apply_state(data)
	_save()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		xp_next = xp_progress(level)
		_applied_max = max_health()
		return
	var ranks := {}
	if cfg.has_section("ranks"):
		for key in cfg.get_section_keys("ranks"):
			ranks[str(key)] = int(cfg.get_value("ranks", key))
	var perks := {}
	if cfg.has_section("perks"):
		for key in cfg.get_section_keys("perks"):
			perks[str(key)] = int(cfg.get_value("perks", key))
	_apply_state({
		"level": int(cfg.get_value("run", "level", 1)),
		"xp": int(cfg.get_value("run", "xp", 0)),
		"skill_points": int(cfg.get_value("run", "skill_points", 0)),
		"perk_points": int(cfg.get_value("run", "perk_points", 0)),
		"perk_extra": int(cfg.get_value("run", "perk_extra", 0)),
		"xp_delta": int(cfg.get_value("run", "xp_delta", XP_DELTA)),
		"level_sk_add": int(cfg.get_value("run", "level_sk_add", LEVEL_SK_ADD)),
		"rndpump": bool(cfg.get_value("run", "rndpump", false)),
		"ranks": ranks,
		"perks": perks,
	})


func _apply_state(data: Dictionary) -> void:
	level = maxi(1, int(data.get("level", 1)))
	xp = int(data.get("xp", 0))
	skill_points = int(data.get("skill_points", 0))
	perk_points = int(data.get("perk_points", 0))
	_perk_extra = int(data.get("perk_extra", 0))
	_ensure_balance()
	xp_delta = int(data.get("xp_delta", XP_DELTA))
	level_sk_add = int(data.get("level_sk_add", LEVEL_SK_ADD))
	rndpump = bool(data.get("rndpump", false))
	_ranks.clear()
	var ranks: Dictionary = data.get("ranks", {})
	for id in ranks:
		_ranks[str(id)] = int(ranks[id])
	_perks.clear()
	var perks: Dictionary = data.get("perks", {})
	for id in perks:
		_perks[str(id)] = int(perks[id])
	xp_next = xp_progress(level)
	_applied_max = max_health()
