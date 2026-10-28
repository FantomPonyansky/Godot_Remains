extends Node

signal health_changed(current: int, maximum: int)
signal ammo_changed(current: int, maximum: int)
signal magic_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal weapon_changed(weapon_name: String)
signal score_changed(value: int)
signal slice_completed
signal pools_changed

const MAX_HEALTH := 100
const MAX_AMMO := 60
# Two pools, as in the original. magic is UnitPlayer.mana (Unit.maxmana 1000):
# spells pay their magic='' cost from it and it refills on its own. mana_hp is
# Pers.manaHP (inMaxMana 400, +20 per spirit rank): spells pay mana='' from it,
# it does not refill by itself (potions with hmana do), and its quarter stages
# are trauma_mana.
const MAX_MAGIC := 1000
# Pers.recMana: added to the regen rate (dmana) every tick, so regen speeds up
# after each cast. recManaMin (0.75 per Magic level) is the floor of that rate.
const REC_MANA := 0.025
# Pers.teleManaMult 0.04 times the difficulty teleMana: telekinesis and
# self-levitation also wear mana_hp.
const TELE_MANA_MULT := 0.04
# Pers.inMaxHP / lvlOrganHp.
const ORGAN_BASE := 200.0
const ORGAN_PER_LEVEL := 40.0
# Pers.setGlobalDif for dif0..dif4. neujaz is Pers.neujazMax in ticks; below
# dif3 setGlobalDif leaves the Pers default of 30. him_bad_dif scales chem
# addiction, bonus_heal_mult the bonus heal pickups, price_* the doctors
# (PipPageMed, per point healed; price_hp 0.5 and price_mana 1 on every level).
# pet_res is Pers.petRes, the phoenix's rebirth wait in seconds.
const DIFFICULTY: Array[Dictionary] = [
	{"beg_hp": 200, "lvl_hp": 25, "pet_res": 20, "organ_mult": 0.2, "tele_mana": 0.0, "caps_mult": 1.0, "neujaz": 30, "die_damage": 0.0,
		"him_bad_dif": 1.0, "bonus_heal_mult": 1.0, "price_blood": 0.5, "price_organ": 0.5, "price_rad": 1.0, "price_poison": 4.0, "price_cut": 4.0},
	{"beg_hp": 150, "lvl_hp": 25, "pet_res": 20, "organ_mult": 0.5, "tele_mana": 0.0, "caps_mult": 1.0, "neujaz": 30, "die_damage": 0.0,
		"him_bad_dif": 1.0, "bonus_heal_mult": 1.0, "price_blood": 0.5, "price_organ": 0.5, "price_rad": 1.0, "price_poison": 4.0, "price_cut": 4.0},
	{"beg_hp": 100, "lvl_hp": 20, "pet_res": 30, "organ_mult": 1.0, "tele_mana": 0.5, "caps_mult": 1.0, "neujaz": 30, "die_damage": 0.15,
		"him_bad_dif": 1.3, "bonus_heal_mult": 1.0, "price_blood": 0.5, "price_organ": 0.5, "price_rad": 1.0, "price_poison": 4.0, "price_cut": 4.0},
	{"beg_hp": 70, "lvl_hp": 15, "pet_res": 60, "organ_mult": 1.0, "tele_mana": 1.0, "caps_mult": 1.0, "neujaz": 20, "die_damage": 0.25,
		"him_bad_dif": 2.0, "bonus_heal_mult": 0.75, "price_blood": 1.0, "price_organ": 1.0, "price_rad": 1.5, "price_poison": 6.0, "price_cut": 6.0},
	{"beg_hp": 40, "lvl_hp": 10, "pet_res": 90, "organ_mult": 1.0, "tele_mana": 1.0, "caps_mult": 0.5, "neujaz": 15, "die_damage": 0.35,
		"him_bad_dif": 2.5, "bonus_heal_mult": 0.5, "price_blood": 1.0, "price_organ": 1.0, "price_rad": 1.5, "price_poison": 6.0, "price_cut": 6.0},
]
const PRICE_HP := 0.5
const PRICE_MANA := 1.0
## PipPageMed: organs heal in chunks of raz, mana in razMana.
const DOCTOR_RAZ := 200.0
const DOCTOR_RAZ_MANA := 100.0
## UnitPlayer drad2 decay per tick.
const RAD_DRAD2_DECAY := 0.1
## Unit.damage: skin is taken off these when the hit is not periodic.
const SKIN_TIPS: PackedStringArray = [
	"DAM_PIERCE", "DAM_CUT", "DAM_EXPLOSION", "DAM_BLUNT", "DAM_BITE", "DAM_ACID",
	"DAM_BURN", "DAM_LASER", "DAM_PLASMA", "DAM_ELECTRIC", "DAM_COLD", "DAM_ASTRO",
]
# UnitPlayer.stam / h2o. actions() runs at 30 Hz.
const STAM_MAX := 1000.0
const STAM_REGEN := 2.0
const STAM_RUN := 5.0
const STAM_JUMP := 100.0
const BREATH_MAX := 1000.0
const BREATH_REGEN := 10.0
const BREATH_DRAIN := 1.0
const _UserDir := preload("res://scripts/user_dir.gd")
static var POOL_PATH := _UserDir.run("body_pools.cfg")
const CONSUMABLES_PATH := "res://assets/data/content/consumables.json"

var health: int = MAX_HEALTH
var ammo: int = MAX_AMMO
var magic: float = MAX_MAGIC
var mana_hp: float = 400.0
var weapon_name: String = ""
var score: int = 0
var paused: bool = false
## Actions a UI press used (dialogue advance). Gameplay ignores them until released.
var _ui_held: PackedStringArray = PackedStringArray()


func hold_until_released(event: InputEvent) -> void:
	for action in InputMap.get_actions():
		if not str(action).begins_with("ui_") and event.is_action_pressed(action) and not _ui_held.has(str(action)):
			_ui_held.append(str(action))


func ui_hold() -> bool:
	if _ui_held.is_empty():
		return false
	var still := PackedStringArray()
	for action in _ui_held:
		if Input.is_action_pressed(action):
			still.append(action)
	_ui_held = still
	return not _ui_held.is_empty()
const BATTLE_NO_OUT := 120.0
## GameContainer.t_battle, in 30 Hz ticks.
var t_battle := 0.0
## Debug console `quiet`. While false, enemies stay put and do not think.
var enemies_think: bool = true
var enemies_remaining: int = 0
## Crystal shield is up: dmana is 0, no regen.
var magic_locked: bool = false
var _magic_debt: float = 0.0
var _dmana: float = 0.0
var _channel_magic: float = 0.0
var _channel_levit: bool = false
var _channel_until: int = 0
var _mana_stage: int = 0
var _shown_magic: int = MAX_MAGIC

## Debug (console 'god', 'arena'): no damage or radiation, magic and mana
## stay full, spells do not spend either pool.
var god := false
## Console trial / boss: play_land adds this rooms_prob id if the land omitted it.
var debug_prob := ""

var head_hp: float = ORGAN_BASE
var torso_hp: float = ORGAN_BASE
var legs_hp: float = ORGAN_BASE
## Invent.usePotion norgan: "head", "torso" or "legs" for the next horgan item
## (PipPageStat health rows); "" heals the worst part.
var organ_target := ""
var blood_hp: float = ORGAN_BASE
var rad: float = 0.0
var stam: float = STAM_MAX
var breath: float = BREATH_MAX

var _head_stage: int = 0
var _torso_stage: int = 0
var _legs_stage: int = 0
var _blood_stage: int = 0
var _seen_level: int = -1
var _dead: bool = false
var _running: bool = false
var _swimming: bool = false
var _can_run: bool = true
var _tick_debt: float = 0.0
var _dirty: bool = false
var _save_wait: float = 0.0
var _shown: String = ""
var _consumables: Dictionary = {}
## UnitPlayer.healhp: potion heal still to come, released healMult / 5 * metaMult a tick.
var _healhp: float = 0.0
## UnitPlayer.drad (this tick's radiation) and drad2 (chem radiation, fading 0.1 a tick).
var drad: float = 0.0
var _drad2: float = 0.0
var _hp_carry: float = 0.0
var _dam_carry: float = 0.0


func _ready() -> void:
	_load_consumables()
	_load_pools()
	_recompute_stages()
	call_deferred("_bind_progression")


func _process(delta: float) -> void:
	if paused:
		return
	_tick_battle(delta)
	_tick_magic(delta)
	_tick_body(delta)
	if not _dirty:
		return
	_save_wait -= delta
	if _save_wait > 0.0:
		return
	_save_wait = 0.5
	_dirty = false
	_save_pools()


func _tick_magic(delta: float) -> void:
	if god:
		magic = float(MAX_MAGIC)
		if mana_hp < mana_max():
			mana_hp = mana_max()
			_mana_moved()
		_emit_magic()
		_magic_debt = 0.0
		return
	# UnitPlayer.actions mana block, 30 ticks a second.
	_magic_debt += delta * 30.0
	var ticks := mini(int(_magic_debt), 10)
	if ticks <= 0:
		return
	_magic_debt -= floorf(_magic_debt)
	var channeling := Time.get_ticks_msec() < _channel_until
	var before_mana := mana_hp
	for _i in ticks:
		if channeling:
			_dmana = -_channel_magic * mana_cost_mult()
			if _dmana < 0.0:
				var wear := -_dmana * dif_value("tele_mana") * TELE_MANA_MULT
				if not _channel_levit:
					wear /= 3.0
				mana_hp = maxf(0.0, mana_hp - wear)
		elif magic_locked:
			_dmana = 0.0
		else:
			var res := Inventory.overload_mana_mult()
			var floor_rate := _rec_mana_min() * res
			if _dmana < floor_rate:
				_dmana = floor_rate
			_dmana += REC_MANA * res
		magic = minf(magic + _dmana, float(MAX_MAGIC))
	if mana_hp != before_mana:
		_mana_moved()
	_emit_magic()


func _rec_mana_min() -> float:
	var prog := get_node_or_null("/root/Progression")
	if prog and prog.has_method("rec_mana_min"):
		return Effects.stat("recManaMin", float(prog.rec_mana_min()))
	return Effects.stat("recManaMin", 0.0)


func _emit_magic() -> void:
	var shown := int(round(magic))
	if shown == _shown_magic:
		return
	_shown_magic = shown
	magic_changed.emit(shown, MAX_MAGIC)


func mana_max() -> float:
	var prog := get_node_or_null("/root/Progression")
	if prog and prog.has_method("max_mana"):
		return float(prog.max_mana())
	return 400.0


## Telekinesis and self-levitation call this every physics frame while active.
## magic_per_tick is the base drain before allDManaMult. levit wears mana_hp at
## the full rate, a held object at a third (UnitPlayer.actions).
func channel(magic_per_tick: float, levit: bool) -> void:
	_channel_magic = maxf(0.0, magic_per_tick)
	_channel_levit = levit
	_channel_until = Time.get_ticks_msec() + 100


## Spell.cast / WMagic checks. Returns "" when payable, else the info id
## ("overMana" for magic, "noMana" for mana_hp). full_ok is WMagic's rule that
## a full magic bar (99%) may cast anything.
func spell_block(dmagic: float, dmana: float, full_ok: bool = false) -> String:
	if god:
		return ""
	if dmana > mana_hp:
		return "noMana"
	if dmagic > magic and not (full_ok and magic >= float(MAX_MAGIC) * 0.99):
		return "overMana"
	return ""


## UnitPlayer.manaSpell / WMagic.shoot: take both costs and restart regen from 0.
func pay_spell(dmagic: float, dmana: float) -> void:
	if god:
		magic = float(MAX_MAGIC)
		_emit_magic()
		return
	magic -= maxf(0.0, dmagic)
	_dmana = 0.0
	if dmana > 0.0:
		damage_mana(dmana)
	_emit_magic()


## Pers.manaDamage.
func damage_mana(amount: float) -> void:
	if amount <= 0.0 or god:
		return
	mana_hp = maxf(0.0, mana_hp - amount)
	_mana_moved()


## Pers.heal(hhp, 6): hmana potions.
func restore_mana(amount: float) -> void:
	if amount <= 0.0:
		return
	mana_hp = minf(mana_max(), mana_hp + amount)
	_mana_moved()


func _mana_moved() -> void:
	var prev := _mana_stage
	_mana_stage = _ratio_stage(mana_hp, mana_max())
	mana_changed.emit(int(round(mana_hp)), int(round(mana_max())))
	_dirty = true
	if _mana_stage > prev and _mana_stage > 1:
		_pool_notice(OriginalLines.info("tmana%d" % _mana_stage))


func _bind_progression() -> void:
	var prog := get_node_or_null("/root/Progression")
	if prog and prog.has_signal("changed") and not prog.changed.is_connected(_on_progression):
		prog.changed.connect(_on_progression)
	if prog and _seen_level < 0:
		_seen_level = int(prog.level)
	if mana_hp < 0.0:
		mana_hp = mana_max()
	mana_hp = minf(mana_hp, mana_max())
	_mana_stage = _ratio_stage(mana_hp, mana_max())
	mana_changed.emit(int(round(mana_hp)), int(round(mana_max())))
	_recompute_stages()
	_emit_pools()


func _on_progression() -> void:
	var prog := get_node_or_null("/root/Progression")
	var level := int(prog.level) if prog else 1
	if _seen_level < 0:
		_seen_level = level
		return
	if level != _seen_level:
		var old_max := ORGAN_BASE + float(_seen_level - 1) * ORGAN_PER_LEVEL
		var new_max := ORGAN_BASE + float(level - 1) * ORGAN_PER_LEVEL
		_seen_level = level
		if old_max > 0.0:
			head_hp = minf(new_max, head_hp / old_max * new_max)
			torso_hp = minf(new_max, torso_hp / old_max * new_max)
			legs_hp = minf(new_max, legs_hp / old_max * new_max)
			blood_hp = minf(new_max, blood_hp / old_max * new_max)
		_recompute_stages()
	health = mini(health, _hp_cap())
	health_changed.emit(health, _max_health())
	_emit_pools()
	_dirty = true


## Player effects live in Effects; these stay for older callers.
func effect_active(id: String) -> bool:
	return Effects.has(null, id)


## seconds <= 0 keeps the effs.xml duration.
func start_effect(id: String, seconds: float) -> void:
	if id == "":
		return
	Effects.add(null, id, int(round(seconds * 30.0)) if seconds > 0.0 else -1)


func reset_run() -> void:
	SaveSlots.reset_play_time()
	enemies_think = true
	Effects.reset_run()
	_healhp = 0.0
	drad = 0.0
	_drad2 = 0.0
	_seen_level = -1
	_head_stage = 0
	_torso_stage = 0
	_legs_stage = 0
	_blood_stage = 0
	_dead = false
	var prog := get_node_or_null("/root/Progression")
	if prog and prog.has_method("reset_run"):
		prog.reset_run()
	var cond := get_node_or_null("/root/Condition")
	if cond and cond.has_method("reset_run"):
		cond.reset_run()
	var bags := get_node_or_null("/root/Inventory")
	if bags and bags.has_method("reset_run"):
		bags.reset_run()
	var pets := get_node_or_null("/root/Pets")
	if pets and pets.has_method("reset_run"):
		pets.reset_run()
	Travel.reset_run()
	_fill_pools()
	_seen_level = int(prog.level) if prog else 1
	health = _hp_cap()
	ammo = MAX_AMMO
	magic = MAX_MAGIC
	_dmana = 0.0
	_magic_debt = 0.0
	mana_hp = mana_max()
	_mana_stage = 0
	score = 0
	paused = false
	magic_locked = false
	enemies_remaining = 0
	if prog and prog.has_method("note_applied_max"):
		prog.note_applied_max(_max_health())
	health_changed.emit(health, _max_health())
	ammo_changed.emit(ammo, MAX_AMMO)
	_shown_magic = MAX_MAGIC
	magic_changed.emit(MAX_MAGIC, MAX_MAGIC)
	mana_changed.emit(int(round(mana_hp)), int(round(mana_max())))
	score_changed.emit(score)
	_emit_pools()
	_save_pools()


func _fill_pools() -> void:
	var cap := organ_max()
	head_hp = cap
	torso_hp = cap
	legs_hp = cap
	blood_hp = cap
	rad = 0.0
	stam = STAM_MAX
	breath = BREATH_MAX
	_can_run = true
	_running = false
	_swimming = false
	_head_stage = 0
	_torso_stage = 0
	_legs_stage = 0
	_blood_stage = 0


func _max_health() -> int:
	var prog := get_node_or_null("/root/Progression")
	if prog and prog.has_method("max_health"):
		return int(prog.max_health())
	return maxi(1, int(round(float(MAX_HEALTH) * torso_hp_mult())))


func _hp_cap() -> int:
	return maxi(0, int(floor(float(_max_health()) - rad)))


func apply_damage(amount: int, tip: String = "", tt: bool = false) -> void:
	apply_damage_f(float(amount), tip, tt)


## Unit.damage on the player. tt is periodic damage (bleeding, poison,
## burning): no skin, no dodge, no contusion roll.
func apply_damage_f(amount: float, tip: String = "", tt: bool = false) -> void:
	# Unit.damage returns for invulner, which controlOff sets.
	if _dead or amount <= 0.0 or god or Travel.control_off():
		return
	var dam := amount
	if tip != "":
		# Perk resistances (perks.xml sk tip='res') and effect deltas add into one vulner.
		dam *= maxf(0.0, Effects.player_vulner(tip) + Progression.perk_vulner(tip) - 1.0)
	if dam <= 0.0:
		return
	var cond := get_node_or_null("/root/Condition")
	if cond and cond.has_method("adjust_hit"):
		var whole := int(round(dam))
		if whole > 0:
			dam = float(cond.adjust_hit(whole, tip)) * dam / float(whole)
	if not tt and tip in SKIN_TIPS:
		dam -= skin()
	if dam <= 0.0:
		return
	var prog := get_node_or_null("/root/Progression")
	if not tt and prog and prog.has_method("mitigate_damage"):
		var whole2 := int(round(dam))
		dam = float(prog.mitigate_damage(whole2)) * dam / maxf(1.0, float(whole2))
	if tip not in ["DAM_POISON", "DAM_BLEED", "DAM_INTERNAL"]:
		dam *= damage_taken_mult()
	dam += _dam_carry
	var hit := int(dam)
	_dam_carry = dam - float(hit) if tt else 0.0
	if hit <= 0:
		return
	health = maxi(0, health - hit)
	if tip not in ["DAM_INTERNAL", "DAM_BLEED"]:
		_organ_damage(float(hit), tip)
	_blood_from_hit(float(hit), tip)
	_clamp_rad()
	health_changed.emit(health, _max_health())
	Stash.hit(float(hit), tip, tt)
	Effects.player_damaged(float(hit), tip, tt)
	if health <= 0:
		_die()


## Unit.skin: Survival level plus effect skin (buck, food).
func skin() -> float:
	var base := 0.0
	var prog := get_node_or_null("/root/Progression")
	if prog and prog.has_method("skill_level_of"):
		base = float(prog.skill_level_of("survival"))
	if ScriptsEngine.alicorn:
		base += Progression.pers("alicornSkin", 5.0)
	return Effects.stat("skin", base)


func heal(amount: int) -> void:
	var prog := get_node_or_null("/root/Progression")
	if prog and prog.has_method("scale_heal"):
		amount = int(prog.scale_heal(amount))
	heal_raw(float(amount))


## UnitPlayer.heal tip 0: instant, up to maxhp - rad.
func heal_raw(amount: float) -> void:
	if amount <= 0.0:
		return
	_hp_carry += amount
	var whole := int(_hp_carry)
	_hp_carry -= float(whole)
	if whole <= 0:
		return
	health = mini(_hp_cap(), health + whole)
	health_changed.emit(health, _max_health())


## UnitPlayer.heal tip 1: into the potion buffer.
func heal_long(amount: float) -> void:
	if amount > 0.0:
		_healhp += amount


func healing_pending() -> float:
	return _healhp


## Pers.heal tip 4 (head, torso and legs) and tip 5 (blood).
func heal_organs(amount: float) -> void:
	_restore("head", amount)
	_restore("torso", amount)
	_restore("legs", amount)


func heal_blood(amount: float) -> void:
	_restore("blood", amount)


## Debug console `heal`: hit points, radiation, and all four organs to full.
func restore_body() -> void:
	var cap := organ_max()
	for part in ["head", "torso", "legs", "blood"]:
		_restore(part, cap)
	rad = 0.0
	_hp_carry = 0.0
	_healhp = 0.0
	health = _hp_cap()
	_emit_pools()
	_dirty = true
	health_changed.emit(health, _max_health())


## Pers.healMult: medic 0.4 + 0.03 per point, metabolism +0.1, then effects (curse, antil, alicorn, post_hydra, apple pie).
func heal_mult() -> float:
	var base := 0.4
	var prog := get_node_or_null("/root/Progression")
	if prog:
		base += 0.03 * float(prog.rank("medic"))
		base += 0.1 * float(prog.perk_rank("metabol"))
	return maxf(0.0, Effects.stat("healMult", base))


## Pers.metaMult: Metabolism 2.5, post_chance x10, apple pie +1.5.
func meta_mult() -> float:
	var base := 1.0
	var prog := get_node_or_null("/root/Progression")
	if prog and prog.perk_rank("metabol") > 0:
		base = 2.5
	return Effects.stat("metaMult", base)


func is_consumable(item_id: String) -> bool:
	return _consumables.has(item_id) or item_id == "stealth"


func apply_medicine(item_id: String) -> void:
	apply_consumable(item_id)


## ItemInteraction.useItem / usePotion refusals, "" when the item can be used now.
func consume_block(item_id: String) -> String:
	if ScriptsEngine.alicorn and item_id == "stealth":
		return OriginalLines.info("alicornNot")
	var pot := Effects.item_row(item_id)
	if pot.is_empty():
		return ""
	var tip := str(pot.get("tip", ""))
	if ScriptsEngine.alicorn and tip in ["pot", "him", "food"]:
		return OriginalLines.info("alicornNot")
	if tip == "food" and _in_battle():
		return OriginalLines.info("noUseCombat")
	var name := OriginalLines.name_of(item_id)
	var cap := organ_max()
	match str(pot.get("heal", "")):
		"rad":
			if rad < 1.0:
				return OriginalLines.info("noMedic", name)
		"poison":
			if Effects.poison < 0.1:
				return OriginalLines.info("noMedic", name)
		"blood":
			if cap - blood_hp < 1.0:
				return OriginalLines.info("noMedic", name)
		"organ":
			if cap - head_hp < 1.0 and cap - torso_hp < 1.0 and cap - legs_hp < 1.0:
				return OriginalLines.info("noHeal")
		"mana":
			if mana_max() - mana_hp < 1.0:
				return OriginalLines.info("noMedic", name)
		"pet":
			var pets := get_node_or_null("/root/Pets")
			if pets == null or not pets.can_heal(str(pot.get("pet", "phoenix"))):
				return OriginalLines.info("noMedic", name)
	var minmed := int(pot.get("minmed", 0))
	var prog := get_node_or_null("/root/Progression")
	if minmed > 0 and prog and int(prog.skill_level_of("medic")) < minmed:
		return OriginalLines.info("needSkill", OriginalLines.eff("medic"), str(minmed))
	return ""


## Items that are never used up (items.xml inf).
func consume_keeps(item_id: String) -> bool:
	return int(Effects.item_row(item_id).get("inf", 0)) > 0


func apply_consumable(item_id: String) -> void:
	# ItemInteraction.usePotion. hhp, hhplong and hrad go through healMult;
	# hhplong goes into the slow heal buffer. horgan, horgans, hblood, hmana do not.
	if item_id == "stealth":
		Effects.add(null, "stealth")
		return
	var found: Variant = _consumables.get(item_id, {})
	var row: Dictionary = found if found is Dictionary else {}
	var pot := Effects.item_row(item_id)
	if pot.is_empty():
		pot = row
	if pot.is_empty():
		return
	var hm := heal_mult()
	heal_raw(float(pot.get("hhp", 0.0)) * hm)
	heal_long(float(pot.get("hhplong", 0.0)) * hm)
	var hrad := float(pot.get("hrad", 0.0))
	if hrad > 0.0:
		heal_radiation(hrad * hm)
	if pot.has("hpoison"):
		Effects.heal_poison(float(pot.hpoison))
	if pot.has("hcut"):
		Effects.heal_cut(float(pot.hcut))
	var one_organ := float(pot.get("horgan", 0.0))
	if one_organ > 0.0:
		if organ_target != "":
			_restore(organ_target, one_organ)
		else:
			_restore_worst_organ(one_organ)
	var organs := float(pot.get("horgans", 0.0))
	if organs > 0.0:
		heal_organs(organs)
	var blood := float(pot.get("hblood", 0.0))
	if blood > 0.0:
		heal_blood(blood)
	var mana := float(pot.get("hmana", 0.0))
	if mana > 0.0:
		restore_mana(mana)
	# items.xml radcookie: heal='pet' pet='phoenix' hpet='200'.
	if str(pot.get("heal", "")) == "pet" and get_node_or_null("/root/Pets") != null:
		get_node("/root/Pets").heal(str(pot.get("pet", "phoenix")), float(pot.get("hpet", 200.0)))
	Effects.use_item(item_id, pot)
	var chem_rad := float(pot.get("rad", 0.0))
	if chem_rad > 0.0:
		_drad2 += chem_rad
	var air := float(row.get("breath", 0.0))
	if air > 0.0:
		breath = minf(BREATH_MAX, breath + air)
		_emit_pools()
		_dirty = true
	var stam_gain := float(row.get("stam", 0.0))
	if stam_gain > 0.0:
		stam = minf(STAM_MAX, stam + stam_gain)
		_emit_pools()
		_dirty = true


## PipPageMed: the price of the next doctor heal of kind ("hp", "rad", "cut",
## "poison", "blood", "head", "torso", "legs", "mana"). Organs and blood heal
## at most 200 a visit, mana 100.
func doctor_price(kind: String) -> float:
	var cap := organ_max()
	match kind:
		"hp":
			return maxf(0.0, float(_max_health() - health) - rad) * PRICE_HP
		"rad":
			return rad * dif_value("price_rad")
		"cut":
			return Effects.cut * dif_value("price_cut")
		"poison":
			return Effects.poison * dif_value("price_poison")
		"blood":
			return minf(DOCTOR_RAZ, cap - blood_hp) * dif_value("price_blood")
		"head", "torso", "legs":
			return minf(DOCTOR_RAZ, cap - _read_pool(kind)) * dif_value("price_organ")
		"mana":
			return minf(DOCTOR_RAZ_MANA, mana_max() - mana_hp) * PRICE_MANA
	return 0.0


## PipPageMed heal for up to budget currency; returns what it cost. funds is
## the payer's whole stock: with none at all below level 6, an organ at 2 or
## less gets a free 49 (healCheckPassed).
func doctor_heal(kind: String, budget: float, funds: float = -1.0) -> float:
	var cena := minf(doctor_price(kind), maxf(0.0, budget))
	if funds < 0.0:
		funds = budget
	var prog := get_node_or_null("/root/Progression")
	var low_level := prog == null or int(prog.level) < 6
	match kind:
		"hp":
			heal_raw(cena / PRICE_HP)
		"rad":
			heal_radiation(cena / dif_value("price_rad"))
		"cut":
			Effects.heal_cut(cena / dif_value("price_cut"))
		"poison":
			Effects.heal_poison(cena / dif_value("price_poison"))
		"blood", "head", "torso", "legs":
			var price := dif_value("price_blood" if kind == "blood" else "price_organ")
			if _read_pool(kind) <= 2.0 and funds <= 0.0 and low_level:
				_restore(kind, 49.0)
			_restore(kind, cena / price)
		"mana":
			restore_mana(cena / PRICE_MANA)
	return cena


## Pers.setParameters after an effect changed: maxhp keeps the health ratio.
func refresh_params() -> void:
	var prog := get_node_or_null("/root/Progression")
	if prog and prog.has_method("_apply_health_ratio"):
		prog._apply_health_ratio()
	_clamp_rad()
	health_changed.emit(health, _max_health())


## Obj.ggModum radioactive objects and UnitPlayer.raddamage: rad per second
## this tick, taken at radX at the end of the tick.
func rad_exposure(per_second: float) -> void:
	if per_second > 0.0:
		drad += per_second


## UnitPlayer.udarUnit radDamage: melee from a radioactive unit.
func set_chem_rad(value: float) -> void:
	_drad2 = maxf(_drad2, value)


func rad_mult() -> float:
	var base := 1.0
	var prog := get_node_or_null("/root/Progression")
	if prog:
		base -= 0.2 * float(prog.perk_rank("envir"))
		base -= 0.05 * float(prog.perk_rank("potion_immun"))
	return Effects.stat("radX", base)


func heal_radiation(amount: float) -> void:
	if amount <= 0.0 or rad <= 0.0:
		return
	rad = maxf(0.0, rad - amount)
	_emit_pools()
	_dirty = true
	health_changed.emit(health, _max_health())


func try_blood_shield(dam: float) -> bool:
	# Spell.cast_invulner: fail when bloodHP <= dam * 3, else bloodDamage(dam, BLEED).
	if blood_hp <= dam * 3.0:
		return false
	_blood_from_hit(dam, "DAM_BLEED")
	return true


func spend_jump_stamina() -> void:
	# UnitPlayer spends stamRun * stamJump * dstam once per jump, and only in battle.
	if not _in_battle() or stam <= -100.0:
		return
	stam -= STAM_JUMP * _stam_run_mult()
	_emit_pools()
	_dirty = true


## UnitPlayer dash: stamRun * stamDash (40) * dstam, only in battle.
func spend_dash_stamina() -> void:
	if not _in_battle():
		return
	stam -= STAM_RUN * 40.0 * _stam_run_mult()
	_emit_pools()
	_dirty = true


func set_running(active: bool) -> void:
	# Drain while sprinting on the ground. Standing, air, and crouch refill.
	_running = active


## UnitPlayer.isPlav: head under water, so h2o drains.
func set_swimming(active: bool) -> void:
	_swimming = active


func sprint_allowed() -> bool:
	# possRun locks at empty stamina and stays locked until stam is past 200.
	return _can_run and stam > 0.0


func organ_max() -> float:
	var level := 1
	var prog := get_node_or_null("/root/Progression")
	if prog:
		level = int(prog.level)
	return ORGAN_BASE + float(level - 1) * ORGAN_PER_LEVEL


func torso_hp_mult() -> float:
	return _at(_torso_stage, [1.0, 0.9, 0.8, 0.6])


## Pers.setParameters: no traumaParameters as the alicorn, then allVulnerMult *= alicornVulner.
func damage_taken_mult() -> float:
	if ScriptsEngine.alicorn:
		return Effects.stat("allVulnerMult", 1.0) * Progression.pers("alicornVulner", 0.7)
	return Effects.stat("allVulnerMult", _at(_blood_stage, [1.0, 1.1, 1.2, 1.3]))


## allDamMult, plus meleeDamMult for melee and gunsDamMult for guns.
func damage_dealt_mult(kind: String = "") -> float:
	var mult := Effects.stat("allDamMult", _at(_blood_stage, [1.0, 1.0, 0.9, 0.8]))
	if kind == "melee":
		mult *= Effects.stat("meleeDamMult", 1.0)
	elif kind in ["lightGun", "heavyGun"]:
		mult *= Effects.stat("gunsDamMult", 1.0)
	return mult


## Game.globalDif, 0..4. The new-game choice lives in UiSettings.
func difficulty() -> int:
	return clampi(UiSettings.difficulty(), 0, DIFFICULTY.size() - 1)


func dif_value(key: String) -> float:
	return float(DIFFICULTY[difficulty()].get(key, 0.0))


## Unit comb: a non-player unit's maxhp is x0.4 on dif0 and x0.7 on dif1.
func enemy_max_hp(base: int) -> int:
	match difficulty():
		0:
			return maxi(1, int(round(float(base) * 0.4)))
		1:
			return maxi(1, int(round(float(base) * 0.7)))
	return base


## Land.setLocDif: loc.earMult is halved below dif2. Unit.listen uses noise * ear * earMult.
func enemy_ear_mult() -> float:
	return 0.5 if difficulty() < 2 else 1.0


## UnitPlayer.neujazMax = pers.neujazMax, ticks at 30 Hz.
func hit_invuln_time() -> float:
	return dif_value("neujaz") / 30.0


## UnitPlayer.setSpeeds caps walk and run at pers.maxSpeed (limited-inventory
## overload); walkSpeed is 7 px a tick.
## Effect tormoz (freezing, contusion, drunk, stupor) is ground friction in
## the original; here it scales speed the same way.
func move_speed_mult() -> float:
	var legs := _at(_legs_stage, [1.0, 1.0, 0.9, 0.75])
	legs = Effects.stat("allSpeedMult", legs) * Effects.stat("tormoz", 1.0)
	return minf(legs, Inventory.overload_max_speed() / 7.0)


func sprint_speed_mult() -> float:
	# trauma_legs runSpeedMult. Walk does not use it. Base runSpeedMult is 2.
	var run := Effects.stat("runSpeedMult", 2.0 * _at(_legs_stage, [1.0, 0.85, 0.7, 0.5])) / 2.0
	var walk := move_speed_mult()
	if walk > 0.0:
		run = minf(run, Inventory.overload_max_speed() / (14.0 * walk))
	return run


func jump_velocity_mult() -> float:
	return maxf(0.0, Effects.stat("jumpdy", 12.0 + _at(_legs_stage, [0.0, 0.0, 0.0, -2.0]))) / 12.0 * Inventory.overload_jump_mult()


func aim_prec_mult() -> float:
	return Effects.stat("allPrecMult", _at(_head_stage, [1.0, 0.9, 0.8, 0.7])) * Effects.stat("precMultCont", 1.0)


func aim_mazil() -> float:
	return Effects.stat("mazilAdd", _at(_head_stage, [0.0, 0.0, 5.0, 15.0]))


func melee_speed_mult() -> float:
	return Effects.stat("meleeSpdMult", _at(_head_stage, [1.0, 0.9, 0.8, 0.7]))


func mana_cost_mult() -> float:
	return Effects.stat("allDManaMult", _at(_head_stage, [1.0, 1.0, 1.5, 2.0]))


func spell_damage_mult() -> float:
	return Effects.stat("spellsDamMult", _at(magic_stage(), [1.0, 1.0, 1.0, 0.75, 0.0]))


func tele_mass_mult() -> float:
	return Effects.stat("maxTeleMassa", _at(magic_stage(), [1.0, 1.0, 1.0, 0.8, 0.3]))


## Pers.teleEnemy: the levit a foe's grab gives the player (jumps to break free).
func tele_enemy() -> int:
	return int(Effects.stat("teleEnemy", 60.0))


## Unit.zaput (disorient): left and right swapped.
func controls_swapped() -> bool:
	return Effects.stat("zaput", 0.0) > 0.0


## potion_shadow / potion_rat atkPoss 0: no attacks.
func attack_allowed() -> bool:
	return Effects.stat("atkPoss", 1.0) > 0.0


## Effect ableFly (potion_fly, alicorn).
func can_fly() -> bool:
	return Effects.stat("ableFly", 0.0) > 0.0


## Pers.activateTrap: 0 under potion_shadow / potion_rat, so traps ignore the player.
func activate_trap() -> float:
	# lightstep sets the base to 1.
	return Effects.stat("activateTrap", Progression.pers("activateTrap", 2.0))


## Pers.visiTrap: 1 + 0.4 per Explosives level, potion_infra x10.
func visi_trap() -> float:
	var base := 1.0
	var prog := get_node_or_null("/root/Progression")
	if prog:
		base += 0.4 * float(prog.skill_level_of("explosives"))
	return Effects.stat("visiTrap", base)


func spells_allowed() -> bool:
	return magic_stage() < 4


func hover_allowed() -> bool:
	# trauma_mana stage 4 clears levitOn when teleMana > 0; levit also stops at mana <= 0.
	return (magic_stage() < 4 or dif_value("tele_mana") <= 0.0) and magic > 0.0


## trauma_mana stage, from mana_hp.
func magic_stage() -> int:
	return _ratio_stage(mana_hp, mana_max())


func pool_text() -> String:
	var cap := int(round(organ_max()))
	var hmax := _max_health()
	return "Head %d/%d    Torso %d/%d    Legs %d/%d    Blood %d/%d\nRad %d/%d    Stamina %d/%d    Breath %d/%d" % [
		int(round(head_hp)), cap,
		int(round(torso_hp)), cap,
		int(round(legs_hp)), cap,
		int(round(blood_hp)), cap,
		int(round(rad)), hmax,
		int(round(stam)), int(STAM_MAX),
		int(round(breath)), int(BREATH_MAX),
	]


func try_spend_ammo(amount: int = 1) -> bool:
	if ammo < amount:
		return false
	ammo -= amount
	ammo_changed.emit(ammo, MAX_AMMO)
	return true


func add_ammo(amount: int) -> void:
	ammo = mini(MAX_AMMO, ammo + amount)
	ammo_changed.emit(ammo, MAX_AMMO)


func restore_magic(amount: float) -> void:
	if amount <= 0.0:
		return
	magic = minf(MAX_MAGIC, magic + amount)
	_emit_magic()


func add_radiation(amount: float) -> void:
	if amount <= 0.0 or god:
		return
	rad += amount
	_clamp_rad()
	_emit_pools()
	_dirty = true
	health_changed.emit(health, _max_health())


func try_spend_magic(amount: float = 1.0) -> bool:
	if amount <= 0.0:
		return true
	if magic < amount:
		return false
	pay_spell(amount, 0.0)
	return true


## Crystal shield hits and telekinetic knocks: magic only, may go below 0.
func drain_magic(amount: float) -> float:
	if amount <= 0.0:
		return magic
	magic -= amount
	_emit_magic()
	return magic


func set_weapon_name(value: String) -> void:
	weapon_name = value
	weapon_changed.emit(value)


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func register_enemy() -> void:
	enemies_remaining += 1


func enemy_defeated(points: int = 100) -> void:
	enemies_remaining = maxi(0, enemies_remaining - 1)
	foe_died()
	add_score(points)
	var prog := get_node_or_null("/root/Progression")
	if prog and prog.has_method("add_kill_xp"):
		prog.add_kill_xp(points)
	if enemies_remaining == 0:
		slice_completed.emit()


func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value


func _tick_body(delta: float) -> void:
	_tick_debt += delta * 30.0
	var ticks := int(_tick_debt)
	if ticks <= 0:
		return
	_tick_debt -= float(ticks)
	if not _dead:
		for _i in ticks:
			_tick_rad_heal()
			_tick_alicorn()
	var before_stam := stam
	var before_breath := breath
	if _running and not _swimming:
		if stam > 0.0:
			# stamRun * dstam per tick. Crossing 0 locks sprint (possRun).
			stam -= STAM_RUN * _stam_run_mult() * float(ticks)
			if stam <= 0.0:
				_can_run = false
		else:
			_can_run = false
	elif stam < STAM_MAX:
		stam = minf(STAM_MAX, stam + STAM_REGEN * _stam_res_mult() * float(ticks))
		if stam > 200.0:
			_can_run = true
	if _swimming:
		if breath > 0.0:
			var drain := Effects.stat("h2oPlav", Progression.pers("h2oPlav", BREATH_DRAIN)) * Progression.armor_h2o_mult()
			breath = maxf(0.0, breath - drain * float(ticks))
		else:
			var drown := float(_max_health()) / 500.0 * float(ticks)
			if drown >= 1.0:
				apply_damage(int(round(drown)), "DAM_INTERNAL")
	elif breath < BREATH_MAX:
		breath = minf(BREATH_MAX, breath + BREATH_REGEN * float(ticks))
	if not is_equal_approx(stam, before_stam) or not is_equal_approx(breath, before_breath):
		_emit_pools()
		_dirty = true


## UnitPlayer.actions as the alicorn (sost 1): alicornHeal hp and alicornManaHeal manaHP a tick.
func _tick_alicorn() -> void:
	if not ScriptsEngine.alicorn or Travel.sost != 1:
		return
	var top := _max_health()
	if health < top:
		health = mini(top, health + int(Progression.pers("alicornHeal", 2.0)))
		health_changed.emit(health, top)
	var mana_top := mana_max()
	if mana_hp < mana_top:
		mana_hp = minf(mana_top, mana_hp + Progression.pers("alicornManaHeal", 0.1))
		_mana_moved()


## UnitPlayer.actions: radiation taken at radX, then the potion heal buffer.
func _tick_rad_heal() -> void:
	if _drad2 > 0.0:
		drad += _drad2
		_drad2 -= RAD_DRAD2_DECAY
	if drad > 0.0:
		var x := rad_mult()
		if x > 0.0:
			rad += drad / 30.0 * x
			# radchild: tick radiation stops at maxhp * (1 - radChild).
			var child := Progression.pers("radChild", 0.0)
			if child > 0.0:
				rad = minf(rad, float(_max_health()) * (1.0 - child))
			var before := health
			_clamp_rad()
			_emit_pools()
			_dirty = true
			if health != before:
				health_changed.emit(health, _max_health())
			if health <= 0:
				_die()
		drad = 0.0
	if _healhp > 0.0:
		var amount := heal_mult() / 5.0 * meta_mult()
		_healhp -= amount
		heal_raw(amount)


func _organ_damage(amount: float, tip: String) -> void:
	if amount <= 0.0 or tip in ["DAM_INTERNAL", "DAM_BLEED"]:
		return
	var dam := amount
	if tip == "DAM_DEATH":
		dam *= 0.10
	dam *= dif_value("organ_mult")
	# Pers.damage: potion_dskel organMultPot, and radchild scales by the unirradiated share.
	dam *= Progression.pers("organMultPot", 1.0)
	var max_hp := float(_max_health())
	if Progression.pers("radChild", 0.0) > 0.0 and max_hp > 0.0:
		dam *= maxf(0.0, (max_hp - rad) / max_hp)
	var roll := randf()
	if roll < 0.20:
		_wound("head", dam * 2.0)
	elif roll < 0.60 or tip in ["DAM_POISON", "DAM_VENOM"]:
		_wound("torso", dam)
	else:
		_wound("legs", dam)


func _blood_from_hit(amount: float, tip: String) -> void:
	if amount <= 0.0:
		return
	if tip not in ["DAM_BLEED", "DAM_CUT", "DAM_PIERCE", "DAM_BITE"]:
		return
	var dam := amount * 3.0 * dif_value("organ_mult") * randf()
	if tip in ["DAM_PIERCE", "DAM_BITE"]:
		dam *= 0.5
	_wound("blood", dam)


func _wound(part: String, dam: float) -> void:
	if dam <= 0.0 or _dead:
		return
	var cur := _read_pool(part) - dam
	if cur < 0.0:
		cur = 0.0
	var fatal := cur <= 0.0
	if fatal:
		cur = 1.0
	var prev := _stage_of(part)
	_write_pool(part, cur)
	var nxt := _ratio_stage(cur, organ_max())
	if part == "torso" and nxt != prev:
		_apply_torso_stage(nxt)
	else:
		_write_stage(part, nxt)
	if nxt > prev:
		_trauma_notice(part)
	_emit_pools()
	_dirty = true
	if fatal:
		_die(10)


func _restore_worst_organ(amount: float) -> void:
	# Pers.heal tip 0 picks the most damaged of head, torso, legs.
	var worst := "head"
	var low := head_hp
	if torso_hp < low:
		low = torso_hp
		worst = "torso"
	if legs_hp < low:
		worst = "legs"
	_restore(worst, amount)


func _load_consumables() -> void:
	_consumables.clear()
	if not FileAccess.file_exists(CONSUMABLES_PATH):
		push_error("consumables.json missing")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONSUMABLES_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("consumables.json could not be parsed")
		return
	for entry_v in (parsed as Dictionary).get("items", []):
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry_v
		var item_id := str(row.get("id", ""))
		if item_id == "":
			continue
		_consumables[item_id] = row


func _pool_notice(text: String) -> void:
	if not is_inside_tree():
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("show_notice"):
		return
	hud.show_notice(text)


func _restore(part: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var cap := organ_max()
	var cur := minf(cap, _read_pool(part) + amount)
	var prev := _stage_of(part)
	_write_pool(part, cur)
	var nxt := _ratio_stage(cur, cap)
	if part == "torso" and nxt != prev:
		_apply_torso_stage(nxt)
	else:
		_write_stage(part, nxt)
	_emit_pools()
	_dirty = true


func _apply_torso_stage(nxt: int) -> void:
	var old_max := _max_health()
	_torso_stage = nxt
	var new_max := _max_health()
	if old_max > 0 and new_max != old_max:
		health = clampi(int(round(float(health) * float(new_max) / float(old_max))), 0, new_max)
	var prog := get_node_or_null("/root/Progression")
	if prog and prog.has_method("note_applied_max"):
		prog.note_applied_max(new_max)
	health_changed.emit(health, new_max)


func _clamp_rad() -> void:
	var cap := _hp_cap()
	if health > cap:
		health = cap


## sposob 10 is Pers.die (an organ at 0), anything else UnitPlayer.die.
func _die(sposob := 0) -> void:
	if _dead:
		return
	if sposob >= 0 and Effects.death_cheat():
		return
	if Travel.has_host():
		if sposob == 10:
			Travel.organ_failed()
		else:
			Travel.player_died(sposob)
		return
	_dead = true
	_save_pools()
	preload("res://scripts/exit_trace.gd").arm(get_tree(), "death without host")
	get_tree().call_deferred("change_scene_to_file", load("res://scripts/editor/editor_play.gd").menu_dest())


## Game.dopusk: no organ at 1 or below.
func dopusk() -> bool:
	return head_hp > 1.0 and torso_hp > 1.0 and legs_hp > 1.0 and blood_hp > 1.0


## Pers.damage with isDie: dieDamage of an organ's max, head not doubled.
func die_damage() -> void:
	var dam := dif_value("die_damage") * organ_max() * dif_value("organ_mult")
	if dam <= 0.0:
		return
	var roll := randf()
	if roll < 0.20:
		_wound("head", dam)
	elif roll < 0.60:
		_wound("torso", dam)
	else:
		_wound("legs", dam)


func mark_dead(on: bool) -> void:
	_dead = on
	if on:
		_save_pools()


func is_dead() -> bool:
	return _dead


## UnitPlayer.resurect.
func revive() -> void:
	_dead = false
	var cap := float(_max_health())
	rad = clampf(rad, 0.0, maxf(0.0, cap - 40.0))
	if health <= 0:
		health = mini(_hp_cap(), int(round(minf(100.0, cap * 0.5))))
		var prog := get_node_or_null("/root/Progression")
		if prog and prog.has_method("grant_perk"):
			prog.grant_perk("dead")
	if mana_hp < 50.0:
		restore_mana(50.0 - mana_hp)
	magic = MAX_MAGIC
	_magic_debt = 0.0
	breath = BREATH_MAX
	stam = STAM_MAX
	_can_run = true
	_healhp = 0.0
	_drad2 = 0.0
	Effects.on_revive()
	_clamp_rad()
	health_changed.emit(health, _max_health())
	_emit_magic()
	_emit_pools()
	_save_pools()


func end_effect(id: String) -> void:
	Effects.remove(null, id)


func _trauma_notice(part: String) -> void:
	if not is_inside_tree():
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("show_notice"):
		return
	var stage := _stage_of(part)
	var key := "blood%d" % stage if part == "blood" else "trauma%d" % stage
	hud.show_notice(OriginalLines.info(key))


func _stam_run_mult() -> float:
	return Effects.stat("stamRun", Progression.pers("stamRun", _at(_torso_stage, [1.0, 1.5, 2.0, 3.0])))


func _stam_res_mult() -> float:
	return Effects.stat("stamRes", 2.0 * _at(_torso_stage, [1.0, 0.66, 0.5, 0.25])) / 2.0


func _in_battle() -> bool:
	return t_battle > 0.0


## GameContainer.t_battle: Unit.setCel on the player sets battleNoOut (120
## ticks) while some foe is on the player; World.step counts it down.
func _tick_battle(delta: float) -> void:
	if not is_inside_tree():
		return
	var fight := false
	var props: Node = null
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.get("_track_player") == true and node.get("_on_prior") != true and node.get("_dead") != true:
			fight = true
			if props == null:
				props = get_tree().get_first_node_in_group("land_props")
			if props != null and props.has_method("note_detected"):
				props.note_detected((node as Node2D).global_position)
	if fight:
		t_battle = BATTLE_NO_OUT
		return
	t_battle = maxf(0.0, t_battle - delta * 30.0)


## Unit.die: a foe going down cuts the battle timer to 30 ticks.
func foe_died() -> void:
	t_battle = minf(t_battle, 30.0)


## World: entering a land clears the battle timer.
func clear_battle() -> void:
	t_battle = 0.0


func _ratio_stage(current: float, maximum: float) -> int:
	if maximum <= 0.0:
		return 4
	return 4 - ceili(current / maximum * 4.0)


func _at(stage: int, values: Array) -> float:
	return float(values[clampi(stage, 0, values.size() - 1)])


func _read_pool(part: String) -> float:
	match part:
		"head":
			return head_hp
		"torso":
			return torso_hp
		"legs":
			return legs_hp
		_:
			return blood_hp


func _write_pool(part: String, value: float) -> void:
	match part:
		"head":
			head_hp = value
		"torso":
			torso_hp = value
		"legs":
			legs_hp = value
		_:
			blood_hp = value


func _stage_of(part: String) -> int:
	match part:
		"head":
			return _head_stage
		"torso":
			return _torso_stage
		"legs":
			return _legs_stage
		_:
			return _blood_stage


func _write_stage(part: String, value: int) -> void:
	match part:
		"head":
			_head_stage = value
		"torso":
			_torso_stage = value
		"legs":
			_legs_stage = value
		_:
			_blood_stage = value


func _recompute_stages() -> void:
	var prev := _torso_stage
	var cap := organ_max()
	_head_stage = _ratio_stage(head_hp, cap)
	_legs_stage = _ratio_stage(legs_hp, cap)
	_blood_stage = _ratio_stage(blood_hp, cap)
	var nxt := _ratio_stage(torso_hp, cap)
	if nxt != prev:
		_apply_torso_stage(nxt)
	else:
		_torso_stage = nxt


func _emit_pools() -> void:
	var text := pool_text()
	if text == _shown:
		return
	_shown = text
	_dirty = true
	pools_changed.emit()


func _load_pools() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(POOL_PATH) != OK:
		return
	head_hp = float(cfg.get_value("pools", "head", ORGAN_BASE))
	torso_hp = float(cfg.get_value("pools", "torso", ORGAN_BASE))
	legs_hp = float(cfg.get_value("pools", "legs", ORGAN_BASE))
	blood_hp = float(cfg.get_value("pools", "blood", ORGAN_BASE))
	rad = float(cfg.get_value("pools", "rad", 0.0))
	stam = float(cfg.get_value("pools", "stam", STAM_MAX))
	breath = float(cfg.get_value("pools", "breath", BREATH_MAX))
	mana_hp = float(cfg.get_value("pools", "mana", -1.0))


func _save_pools() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("pools", "head", head_hp)
	cfg.set_value("pools", "torso", torso_hp)
	cfg.set_value("pools", "legs", legs_hp)
	cfg.set_value("pools", "blood", blood_hp)
	cfg.set_value("pools", "rad", rad)
	cfg.set_value("pools", "stam", stam)
	cfg.set_value("pools", "breath", breath)
	cfg.set_value("pools", "mana", mana_hp)
	cfg.save(POOL_PATH)
