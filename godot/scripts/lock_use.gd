extends RefCounted

## Interact.act from Remains-Source2.
## lockPick / hacker are raw skill points (skills.xml dop=1, vd=1).
## unlockMaster / hackerMaster are the skill level (0-5).
## signal is 1 + Sneak level. remine is 1 + Explosives level.
## Begin land difficulty is 0, so locksLevel and mechLevel stay 0.
## A placed lock is kept. lockch is not rolled again.

const CHANCE := [0.90, 0.75, 0.50, 0.30, 0.15, 0.05, 0.01]
const CHANCE2 := [0.95, 0.80, 0.55, 0.35, 0.20, 0.08, 0.03]
# Pers.lockPickTime. 30 ticks at 30 Hz. 18 when difficulty is below the skill.
const PICK_TIME := 30

const TEMPL := {
	"safe": {"lockhp": 16, "mine": 2, "minech": 0.6, "inter": 1},
	"wallsafe": {"lockhp": 13, "mine": 3, "minech": 0.75, "hack": 1, "inter": 1},
	"chest": {"low": 0.4, "inter": 1},
	"ammobox": {"low": 0.5, "inter": 1},
	"explbox": {"low": 0.5, "inter": 1},
	"bigexpl": {"low": 0.2, "inter": 1},
	"weapbox": {"low": 0.3, "inter": 1},
	"weapcase": {"inter": 1},
	"instr1": {"low": 0.7, "inter": 1},
	"table": {"low": 0.5, "inter": 1},
	"wallcab": {"low": 0.5, "inter": 1},
	"locker": {"low": 0.5, "inter": 1},
	"cup": {"inter": 1},
	"basechest": {"locktip": 2, "low": 0.4, "inter": 1},
	"enclchest": {"low": 0.4, "inter": 1},
	"enclcase": {"inter": 1},
	"door1": {"low": 0.8, "inter": 1},
	"door1a": {"low": 0.8, "inter": 1},
	"door1b": {"low": 0.8, "inter": 1},
	"door2": {"low": 0.8, "hack": 1, "inter": 1},
	"door2a": {"locktip": 2, "low": 0.5, "inter": 1},
	"stdoor": {"low": 0.7, "mine": 1, "minech": 0.2, "minetip": 6, "hack": 1, "inter": 1, "time": 15},
	"basedoor": {"low": 0.7, "mine": 1, "minech": 0.2, "minetip": 6, "hack": 1, "inter": 1, "time": 15},
	"door3": {"lockhp": 16, "hack": 1, "inter": 1, "time": 15},
	"door4": {"locktip": 4, "lockhp": 10, "hack": 1, "once": 1, "inter": 1, "time": 15},
	"hatch1": {"low": 0.8, "inter": 1},
	"hatch2": {"low": 0.8, "inter": 1},
	"encldoor": {"low": 0.7, "mine": 1, "minech": 0.2, "minetip": 6, "hack": 1, "inter": 1, "time": 15},
	"enclpole": {"locktip": 4, "lockhp": 10, "hack": 1, "once": 1, "inter": 1, "time": 15},
	"term": {"locktip": 2, "inter": 2},
	"term1": {"locktip": 2, "allact": "hack_robot", "inter": 2, "time": 30},
	"term2": {"locktip": 2, "allact": "hack_lock", "inter": 2, "time": 30},
	"term3": {"locktip": 2, "mine": 1, "minech": 0.3, "minetip": 6, "inter": 2, "time": 30},
	"termh": {"locktip": 2, "allact": "prob_help", "inter": 2, "time": 20},
	"elpanel": {"locktip": 2, "allact": "electro_check", "inter": 2, "time": 20},
	"knop3": {"locktip": 5, "inter": 4},
	"knop4": {"locktip": 2, "inter": 4},
	"robocell": {"locktip": 2, "allact": "robocell", "once": 1, "inter": 5},
	"alarm": {"mine": 1, "minetip": 6, "allact": "alarm", "once": 1, "inter": 5},
	"checkpoint1": {"locktip": 1, "low": 0.2},
	"checkpoint2": {"locktip": 2, "low": 0.2},
	"checkpoint3": {"locktip": 5},
	"checkpoint4": {"mine": 1, "minetip": 3},
	"checkpoint5": {"mine": 1, "minetip": 6},
}


static func stamp(node: Node, id: String, stored: float, attrs: Dictionary) -> void:
	var tmpl: Dictionary = TEMPL.get(id, {})
	var tip := int(node.get_meta("locktip", int(tmpl.get("locktip", 1))))
	if tmpl.has("locktip"):
		tip = int(tmpl["locktip"])
	if attrs.has("locktip"):
		tip = int(attrs["locktip"])
	var explicit := attrs.has("lock")
	var lk := stored
	if explicit:
		lk = float(attrs["lock"])
	elif stored < 0.0 and tmpl.has("lock"):
		lk = float(tmpl["lock"])
	var lock_i := int(floor(lk))
	if not explicit and lk > 0.0:
		var frac: float = lk - float(floor(lk))
		if frac > 0.0 and randf() < frac:
			lock_i += 1
		var low := float(tmpl.get("low", 0.0))
		if low > 0.0 and randf() < low:
			lock_i = int(ceil(float(lock_i) * 0.5))
	if lock_i < 0:
		lock_i = 0
	if tip == 1 or tip == 2:
		lock_i = mini(lock_i, 24)
	var hp := float(tmpl.get("lockhp", 10.0))
	if attrs.has("lockhp"):
		hp = float(attrs["lockhp"])
	var level := 0
	if lock_i > 2 and (tip == 1 or tip == 2):
		level = mini(5, int(round(randf() * float(lock_i - 2) / 3.2)))
	var mine := 0
	var mine_tip := 3
	if tmpl.has("mine"):
		if tmpl.has("minetip"):
			mine_tip = int(tmpl["minetip"])
		elif int(tmpl.get("inter", 1)) != 3 and randf() < 0.4:
			mine_tip = 6
		if not attrs.has("mine"):
			var minech: Variant = tmpl.get("minech", null)
			if minech == null or randf() < float(minech):
				mine = int(floor(randf() * (float(tmpl["mine"]) + 1.0)))
				if mine >= 2 and randf() < 0.25:
					mine -= 1
	if attrs.has("mine"):
		mine = int(float(attrs["mine"]))
	if explicit and str(attrs.get("lock", "")) == "0" and not attrs.has("mine"):
		mine = 0
	if attrs.has("minetip"):
		mine_tip = int(attrs["minetip"])
	var att := -100
	if attrs.has("lockatt"):
		att = int(float(attrs["lockatt"]))
	node.set_meta("locktip", tip)
	node.set_meta("lock", float(lock_i))
	node.set_meta("lock_hp", hp)
	node.set_meta("lock_level", level)
	node.set_meta("lock_att", att)
	node.set_meta("mine", mine)
	node.set_meta("mine_tip", mine_tip)
	node.set_meta("hackable", int(tmpl.get("hack", 0)) > 0 or str(attrs.get("hack", "0")) == "1")
	var allact := str(tmpl.get("allact", ""))
	if attrs.has("allact"):
		allact = str(attrs["allact"])
	node.set_meta("allact", allact)
	node.set_meta("once", int(float(attrs.get("once", tmpl.get("once", 0)))))
	var act_time := int(tmpl.get("time", 0))
	if attrs.has("time"):
		act_time = int(float(attrs["time"]))
	node.set_meta("act_time", act_time)
	node.set_meta("lock_key", str(attrs.get("key", "")))
	node.set_meta("keyloss", int(float(str(attrs.get("keyloss", 0)))))
	if attrs.has("allid"):
		node.set_meta("allid", str(attrs["allid"]))
	# Box.initFun("generator"): a repair 4 job of 45 ticks that runs fixGenerator once.
	if str(attrs.get("fun", "")) == "generator":
		node.set_meta("fun", "generator")
		node.set_meta("act_time", 45)
		node.set_meta("user_action", "repair")
	node.set_meta("sec", true)


static func attempt(node: Node) -> Dictionary:
	var out := {"open": false, "text": "", "alarm": false, "blast": 0}
	if str(node.get_meta("fun", "")) == "generator":
		if int(Progression.skill_level_of("repair")) < 4:
			out["text"] = OriginalLines.info("needSkill", OriginalLines.eff("repair"), "4")
			return out
		node.set_meta("fun", "done")
		out["text"] = OriginalLines.info("unFixLock")
		out["script"] = "fixGenerator"
		return out
	if str(node.get_meta("fun", "")) == "done":
		return out
	var mine := int(node.get_meta("mine", 0))
	if mine > 0:
		return _mine(node, mine, out)
	var lock := int(round(float(node.get_meta("lock", 0.0))))
	if has_key(node):
		# Editor.txt keyloss: 1 spends the key, 2 only when the lock has no other way open.
		var loss := int(node.get_meta("keyloss", 0))
		if loss == 1 or (loss == 2 and (lock >= 100 or int(node.get_meta("locktip", 1)) == 0)):
			Inventory.spend(str(node.get_meta("lock_key", "")))
		node.set_meta("lock", 0.0)
		out["open"] = true
		out["text"] = str({1: OriginalLines.info("unLockKey"), 2: OriginalLines.info("unTermLock"), 4: OriginalLines.info("unRepLock"), 5: OriginalLines.info("unFixPart")}.get(int(node.get_meta("locktip", 1)), ""))
		return out
	if lock >= 100:
		out["text"] = OriginalLines.info("unLockBlock") if int(node.get_meta("locktip", 1)) == 2 else OriginalLines.info("unLockZhopa")
		return out
	if lock <= 0:
		out["open"] = true
		return out
	var tip := int(node.get_meta("locktip", 1))
	if tip == 2:
		return _hack(node, lock, out)
	if tip == 1:
		return _pick(node, lock, out)
	out["text"] = OriginalLines.gui("lock")
	return out


static func _pick(node: Node, lock: int, out: Dictionary) -> Dictionary:
	if Inventory.count("screwdriver") <= 0 and Inventory.count("titansd") <= 0:
		out["text"] = OriginalLines.info("noPoss")
		return out
	var points := _pick_points()
	var fail := 1.0 - _chance(lock - points)
	if _master("lockpick") < int(node.get_meta("lock_level", 0)):
		fail = 1.0
	if randf() < fail:
		return _pick_fail(node, lock - points, out)
	node.set_meta("lock", 0.0)
	out["open"] = true
	out["text"] = OriginalLines.info("unLock")
	return out


static func _pick_fail(node: Node, gap: int, out: Dictionary) -> Dictionary:
	var d1 := 0.0
	var d2 := 2.0
	if gap == 1:
		d1 = 1.0
		d2 = 3.0
	elif gap > 1:
		d1 = 2.0
		d2 = 4.0
	var pin_break := 0.5 if Progression.perk_rank("infiltrator") > 0 else 1.0
	var cracked := false
	if Inventory.count("pin") > 0:
		if pin_break >= 1.0 or randf() < pin_break:
			Inventory.spend("pin", 1)
			cracked = true
	else:
		d1 += 2.0
	var mult := 0.75 if Progression.perk_rank("infiltrator") > 0 else 1.0
	var hp := float(node.get_meta("lock_hp", 10.0)) - (d1 + randf() * d2) * mult
	node.set_meta("lock_hp", hp)
	if hp <= 0.0:
		node.set_meta("lock", 100.0)
		out["text"] = OriginalLines.info("unLockZhopa")
		return out
	if cracked:
		out["text"] = OriginalLines.info("unLockFailP")
	elif hp > 100.0:
		out["text"] = OriginalLines.info("unLockFailA")
	else:
		out["text"] = OriginalLines.info("unLockFail")
	return out


static func _hack(node: Node, lock: int, out: Dictionary) -> Dictionary:
	var points := _hack_points()
	var fail := 1.0 - _chance(lock - points)
	if _master("science") < int(node.get_meta("lock_level", 0)):
		fail = 1.0
	if randf() >= fail:
		node.set_meta("lock", 0.0)
		out["open"] = true
		out["text"] = OriginalLines.info("unTermLock")
		return out
	var left := int(node.get_meta("lock_att", -100))
	if left == -100:
		left = 5 if Progression.perk_rank("coolhacker") > 0 else 3
	left -= 1
	node.set_meta("lock_att", left)
	if left <= 0:
		node.set_meta("lock", 100.0)
		out["text"] = OriginalLines.info("unLockBlock")
	elif left > 10:
		out["text"] = OriginalLines.info("unTermLockFail2")
	elif left == 1:
		out["text"] = OriginalLines.info("unTermLockFail1")
	else:
		out["text"] = OriginalLines.info("unTermLockFail", str(left))
	return out


static func _mine(node: Node, mine: int, out: Dictionary) -> Dictionary:
	var alarm := int(node.get_meta("mine_tip", 3)) == 6
	var skill := _signal() if alarm else _remine()
	var crit := 0.0
	if mine > skill:
		crit = float(mine - skill + 1) * 0.15
	var fail := float(mine - skill + 2) * 0.2
	if randf() < crit:
		node.set_meta("mine", 0)
		if alarm:
			out["text"] = OriginalLines.info("signalZhopa")
			out["alarm"] = true
			if str(node.get_meta("allact", "")) == "alarm":
				node.set_meta("allact", "")
				node.set_meta("dead", true)
		else:
			out["text"] = OriginalLines.info("remineZhopa")
			out["blast"] = int(round(float(mine) * 50.0 * (0.8 + randf() * 0.4)))
		if int(node.get_meta("once", 0)) > 0 and str(node.get_meta("allact", "")) != "":
			out["open"] = true
		return out
	if randf() < fail:
		out["text"] = OriginalLines.info("signalFail") if alarm else OriginalLines.info("remineFail")
		return out
	node.set_meta("mine", 0)
	out["text"] = OriginalLines.info("signalOff") if alarm else OriginalLines.info("remine")
	if int(node.get_meta("once", 0)) > 0:
		out["open"] = true
	return out


static func _chance(dif: int) -> float:
	if dif < -2:
		return 1.0
	if dif > 4:
		return 0.0
	var table: Array = CHANCE2 if Inventory.count("stat_tw") > 0 else CHANCE
	return float(table[dif + 2])


static func _pick_points() -> int:
	var n := Progression.rank("lockpick")
	if Inventory.count("titansd") > 0:
		n += 1
	if Inventory.count("stethoscope") > 0:
		n += 1
	if Inventory.count("kogit") > 0:
		n += 1
	if Inventory.count("impl_intel") > 0:
		n += 1
	if Inventory.count("mod_trans") > 0:
		n += 1
	return int(Effects.stat("lockPick", float(n)))


static func _hack_points() -> int:
	var n := Progression.rank("science")
	if Inventory.count("kogit") > 0:
		n += 1
	if Inventory.count("impl_intel") > 0:
		n += 1
	if Inventory.count("mod_hacker") > 0:
		n += 2
	if Inventory.count("mod_trans") > 0:
		n += 1
	return int(Effects.stat("hacker", float(n)))


## unlockMaster / hackerMaster: the skill level plus effect bonuses (mint, muffin).
static func _master(skill: String) -> int:
	var key := "unlockMaster" if skill == "lockpick" else "hackerMaster"
	return int(Effects.stat(key, float(Progression.skill_level_of(skill))))


static func _signal() -> int:
	return 1 + Progression.skill_level_of("sneak")


static func _remine() -> int:
	return int(Effects.stat("remine", float(1 + Progression.skill_level_of("explosives"))))


# getLockPickTime: 18 when difficulty < skill, else 30, plus Interact.t_action.
# Mines pass lockTip 3, so the wait uses remine, not the disarm skill.
static func needs_wait(node: Node) -> bool:
	if int(node.get_meta("mine", 0)) > 0:
		return true
	if has_key(node):
		return false
	var lock := int(round(float(node.get_meta("lock", 0.0))))
	if lock <= 0 or lock >= 100:
		return false
	var tip := int(node.get_meta("locktip", 1))
	return tip == 1 or tip == 2


static func action_ticks(node: Node) -> int:
	var extra := int(node.get_meta("act_time", 0))
	if bool(node.get_meta("hold_use", false)) and int(node.get_meta("mine", 0)) <= 0 and float(node.get_meta("lock", 0.0)) <= 0.0:
		return maxi(1, extra)
	if extra > 0 and not needs_wait(node):
		return extra
	var diff := 0
	var pick := 0
	if int(node.get_meta("mine", 0)) > 0:
		diff = int(node.get_meta("mine", 0))
		pick = _remine()
	else:
		diff = int(round(float(node.get_meta("lock", 0.0))))
		var tip := int(node.get_meta("locktip", 1))
		if tip == 1:
			pick = _pick_points() if _can_pick() else -100
		elif tip == 2:
			pick = _hack_points()
	var work := PICK_TIME
	if diff < pick:
		work = int(float(PICK_TIME) * 0.60)
	return maxi(1, extra + work)


static func prompt_detail(node: Node) -> Dictionary:
	var mine := int(node.get_meta("mine", 0))
	var lock := int(round(float(node.get_meta("lock", 0.0))))
	var tip := int(node.get_meta("locktip", 1))
	var out := {"action": "", "hold": false, "extra": "", "blocked": ""}
	if mine == 0 and has_key(node):
		out["action"] = OriginalLines.gui("termunlock" if tip == 2 else "unlock")
		return out
	if mine == 0 and lock > 0 and tip == 0:
		out["blocked"] = OriginalLines.gui("undef0")
		return out
	if mine == 0 and lock > 0 and lock < 100:
		var need := int(node.get_meta("lock_level", 0))
		if tip == 1 and _master("lockpick") < need:
			out["blocked"] = OriginalLines.gui("undef1")
			return out
		if tip == 2 and _master("science") < need:
			out["blocked"] = OriginalLines.gui("undef2")
			return out
	out["action"] = action_text(node)
	out["hold"] = mine > 0 or (lock > 0 and lock < 100 and (tip == 1 or tip == 2)) or bool(node.get_meta("hold_use", false)) or (int(node.get_meta("act_time", 0)) > 0 and not bool(node.get_meta("door_open", false)))
	var extra: PackedStringArray = PackedStringArray()
	if mine > 0:
		var skill := _signal() if int(node.get_meta("mine_tip", 3)) == 6 else _remine()
		var word := _difficulty_word(mine, skill)
		if word != "":
			extra.append("(%s)" % word)
	elif lock > 0 and lock < 100 and (tip == 1 or tip == 2):
		var points := _hack_points() if tip == 2 else (_pick_points() if _can_pick() else -100)
		var chance := _chance(lock - points)
		var line := "%s: %d%%" % [OriginalLines.gui("chance"), int(round(chance * 100.0))]
		if tip == 1 and Inventory.count("pin") > 0:
			line += " {%d}" % Inventory.count("pin")
		extra.append(line)
	out["extra"] = "\n".join(extra)
	return out


static func _difficulty_word(lock: int, pick: int) -> String:
	if lock < pick:
		return OriginalLines.gui("soft")
	if lock > pick + 2:
		return OriginalLines.gui("unreal")
	if lock > pick + 1:
		return OriginalLines.gui("veryhard")
	if lock > pick:
		return OriginalLines.gui("hard")
	return ""


static func action_text(node: Node) -> String:
	if int(node.get_meta("mine", 0)) > 0:
		if int(node.get_meta("mine_tip", 3)) == 6:
			return OriginalLines.gui("shutoff")
		return OriginalLines.gui("remine")
	var lock := int(round(float(node.get_meta("lock", 0.0))))
	if lock > 0 and int(node.get_meta("locktip", 1)) == 2:
		return OriginalLines.gui("termunlock")
	if lock > 0:
		return OriginalLines.gui("unlock")
	if node.has_meta("user_action"):
		var action := str(node.get_meta("user_action"))
		return OriginalLines.gui(action) if action != "" else ""
	return OriginalLines.gui("open")


## Interact.lockKey: a locked object whose key item is in the bag.
static func has_key(node: Node) -> bool:
	var key := str(node.get_meta("lock_key", ""))
	return key != "" and float(node.get_meta("lock", 0.0)) > 0.0 and Inventory.count(key) > 0


static func _can_pick() -> bool:
	return Inventory.count("screwdriver") > 0 or Inventory.count("titansd") > 0
