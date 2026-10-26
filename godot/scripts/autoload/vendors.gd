extends Node

## Game.vendors (Vendor.as, Item.as prices) and the trade side of PipBuck:
## PipPageVend buy / sell / repair / tasks and PipPageMed payment. Stock comes
## from Vendors.xml, the "random" vendor and NPCs without a vendor xml get
## setRndBuys stock. Data: res://assets/data/trade.json (tools/extract_trade.py).
## Saved with the run (WorldState provider "vendors"): the Vendor.save rows of
## every xml vendor. Money is not saved; it is rolled again on load.

const DATA := "res://assets/data/trade.json"
const StoryText := preload("res://scripts/story/story_text.gd")
const Registry := preload("res://scripts/map/land_registry.gd")
## Game.refillVendors: invent.good.kol.
const GOOD_HP := 1000
## Pers.priceRepArmor.
const PRICE_REP_ARMOR := 0.5
## PipPageVend.repOwl.
const REP_OWL := 2.0
## items.xml stat_fl: sk barterMult ref mult v1 0.9.
const ART_BARTER := {"stat_fl": 0.9}
const NO_REFILL: PackedStringArray = ["armor", "weapon", "scheme", "uniq", "impl"]
## PipPageVend.setCats tips: page -> category -> item tips ("" is every tip).
const BUY_CATS := ["", ["weapon", "armor", "spell"], ["a", "e"], ["med", "him", "pot", "food"],
	["equip", "art", "book", "sphera", "spec", "key", "impl", "instr"],
	["stuff", "compa", "compw", "compe", "compm", "compp"], "scheme"]
const SELL_CATS := ["", "valuables", ["a", "e"], ["med", "him", "pot", "equip", "food"], "food",
	["stuff", "compa", "compw", "compe", "compm", "spec"], "compp"]
## Pers.repTex thresholds (rep1..repGood) and the pip lines.
const REP_STEPS := [[70, "reputmax"], [50, "reput4"], [35, "reput3"], [20, "reput2"], [10, "reput1"]]

var vendors: Dictionary = {}
## PipBuck.vendor / npcId / npcInter / workTip for the next PipBuck.
var vendor: Dictionary = {}
var npc_id := ""
var npc_inter := ""
var work_tip := "work"

var _items: Dictionary = {}
var _weapons: Dictionary = {}
var _armors: Dictionary = {}
var _xml: Dictionary = {}
var _saved: Dictionary = {}
var _npc_vendors: Dictionary = {}
var _land_xp: Dictionary = {}


func _ready() -> void:
	_load_data()
	call_deferred("_register")


func _register() -> void:
	WorldState.register("vendors", get_state, set_state)
	WorldState.run_reset.connect(reset_run)
	Travel.land_entered.connect(_on_land_entered)


func reset_run() -> void:
	vendors.clear()
	_saved.clear()
	_npc_vendors.clear()
	_land_xp.clear()
	clear_context()


func get_state() -> Dictionary:
	_ensure()
	var out := {}
	for vid in vendors:
		var rows: Array = []
		for e_v in (vendors[vid] as Dictionary).buys:
			var e: Dictionary = e_v
			rows.append({"tip": e.tip, "id": e.id, "kol": e.kol, "sost": e.sost, "barter": e.barter,
				"lvl": e.lvl, "trig": e.trig, "variant": e.variant})
		out[vid] = rows
	return out


func set_state(data: Variant) -> void:
	vendors.clear()
	_npc_vendors.clear()
	_saved = (data as Dictionary).duplicate(true) if data is Dictionary else {}
	_ensure()


# --- Vendor.as ---

func vendor_of(vid: String) -> Dictionary:
	_ensure()
	return vendors.get(vid, {})


## UnitNPC without a vendor xml: new Vendor(ndif, null, null, vid). Not saved
## and not refilled; one per NPC.
func npc_vendor(npc: Node, vid: String) -> Dictionary:
	var key := npc.get_instance_id()
	if not _npc_vendors.has(key):
		_npc_vendors[key] = _make(vid, _land_dif(), null)
	return _npc_vendors[key]


func _ensure() -> void:
	if not vendors.is_empty():
		return
	for vid in _xml:
		vendors[vid] = _make(str(vid), 0, _saved.get(vid))


func _make(vid: String, lvl: int, saved: Variant) -> Dictionary:
	var v := {"id": vid, "xml": _xml.has(vid), "buys": [], "money": 0, "mult_price": 1.0,
		"kol_bou": 0.0, "kol_sell": 0.0}
	if v.xml:
		if vid == "random":
			if saved is Array and not (saved as Array).is_empty():
				for o_v in saved:
					var o: Dictionary = o_v
					v.buys.append(_item("", str(o.get("id", "")), int(o.get("kol", -1)), int(o.get("variant", 0))))
			else:
				_set_rnd_buys(v, 100, "random")
		else:
			for b_v in (_xml[vid] as Dictionary).get("buys", []):
				var b: Dictionary = b_v
				var e := _item("", str(b.get("id", "")), int(b.get("n", 0)))
				e.barter = int(b.get("barter", 0))
				e.lvl = int(b.get("lvl", 0))
				e.trig = str(b.get("trigger", ""))
				e.noref = bool(b.get("noref", false))
				e.nocheap = bool(b.get("nocheap", false))
				e.hardinv = bool(b.get("hardinv", false))
				e.pmult = float(b.get("pmult", 1.0))
				if saved is Array:
					for o_v in saved:
						var o: Dictionary = o_v
						if str(o.get("id", "")) == e.id and int(o.get("variant", 0)) == e.variant:
							e.kol = int(o.get("kol", e.kol))
							e.sost = float(o.get("sost", e.sost))
							break
				v.buys.append(e)
	else:
		_set_rnd_buys(v, lvl, vid)
	v.money = int(round(randf() * 450.0 + 50.0))
	if randf() < 0.2:
		v.money *= 2
	return v


## new Item(tip, id, kol, variant).
func _item(tip: String, raw: String, nkol: int = -1, nvar: int = 0) -> Dictionary:
	var id := raw
	var variant := nvar
	if id.length() > 2 and id[id.length() - 2] == "^":
		variant = int(id.right(1))
		id = id.left(id.length() - 2)
	if tip == "":
		tip = _item_tip(id)
	if tip == "uniq":
		tip = "weapon"
	var e := {"tip": tip, "id": id, "variant": variant, "kol": nkol, "sost": 1.0, "barter": 0, "lvl": 0,
		"trig": "", "noref": false, "nocheap": false, "hardinv": false, "pmult": 1.0, "bou": 0}
	if tip == "weapon" or tip == "armor":
		e.kol = 1
		if tip == "armor" and int((_armors.get(id, {}) as Dictionary).get("tip", 1)) == 3:
			e.sost = 1.0
		elif nkol == 0:
			e.sost = 0.05 + randf() * 0.15
		elif nkol == 1:
			e.sost = 0.6 + randf() * 0.25
	elif tip not in ["weapon", "armor"] and _items.has(id):
		var it: Dictionary = _items[id]
		if tip == "item" and it.has("tip"):
			e.tip = str(it.tip)
	if int(e.kol) < 0:
		e.kol = maxi(1, int(_xml_of(e).get("kol", 1)))
	return e


## Item.itemTip: items first, then weapons, then armors.
func _item_tip(id: String) -> String:
	if _items.has(id):
		return str((_items[id] as Dictionary).get("tip", "item"))
	if _weapons.has(id):
		return "weapon"
	if _armors.has(id):
		return "armor"
	return "item"


func _xml_of(e: Dictionary) -> Dictionary:
	match str(e.tip):
		"weapon":
			return _weapons.get(e.id, {})
		"armor":
			return _armors.get(e.id, {})
	return _items.get(e.id, {})


## Item.getPrice.
func price_of(e: Dictionary) -> float:
	var x := _xml_of(e)
	if x.is_empty():
		return 0.0
	var p := float(x.get("price", 0.0))
	if str(e.tip) == "weapon" and int(e.variant) > 0:
		p = float(x.get("price1", p * 3.0))
	return p * float(e.sost) * float(e.pmult)


## Item.getMultPrice.
func item_mult(e: Dictionary) -> float:
	var x := _xml_of(e)
	var p := float(x.get("price", 0.0))
	var s := float(x.get("sell", 0.0))
	if p > 0.0 and s > 0.0:
		return s / p
	return 0.1


## Vendor.setRndBuys.
func _set_rnd_buys(v: Dictionary, lvl: int, tip: String) -> void:
	if randf() < 0.7:
		v.mult_price = floor(randf() * 6.0 + 8.0) / 10.0
	var num := 10 + 6 * barter_lvl()
	if tip == "random":
		num = 30
	elif tip == "doctor":
		num = 5 + 3 * barter_lvl()
	num = int(round(num * (0.5 + randf() * 0.7)))
	var num2 := int(num * (0.1 + randf() * 0.3))
	var by: Dictionary = {}
	var gen := _gen()
	for i in num:
		if i < num2 and tip != "doctor":
			var wid := gen._pick("weapon", 1.0 + lvl / 4.0)
			if wid == "" or by.has(wid):
				continue
			var w := _item("weapon", wid, 1)
			if randf() < 0.2:
				w.barter = mini(5, int(floor(randf() * lvl / 4.0 + 1.0)))
			v.buys.append(w)
			by[wid] = w
		else:
			var kind := _rnd_kind(int(floor(randf() * 110.0)), tip)
			var id := gen._pick(kind, lvl)
			if id == "":
				continue
			var e := _item(kind, id)
			if not by.has(id):
				if randf() < 0.3:
					e.lvl = mini(5, int(floor(randf() * lvl + 1.0)))
				if kind == "a":
					e.kol = int(round(e.kol * (3.0 + randf() * 12.0)))
				elif kind != "uniq" and kind != "scheme":
					e.kol = int(round(e.kol * (1.0 + randf() * 4.0)))
				v.buys.append(e)
				by[id] = e
			elif kind != "uniq" and kind != "scheme":
				(by[id] as Dictionary).kol = int((by[id] as Dictionary).kol) + int(e.kol)


func _rnd_kind(t: int, tip: String) -> String:
	if tip == "doctor":
		return "med" if t < 70 else "him"
	for step: Array in [[5, "uniq"], [10, "scheme"], [25, "med"], [35, "him"], [55, "e"], [60, "compa"],
			[65, "compw"], [70, "compe"], [75, "compm"]]:
		if t < int(step[0]):
			return str(step[1])
	return "a"


func _gen() -> LootRoll:
	LootRoll._ensure()
	var gen := LootRoll.new()
	gen._stage = Registry.int_of(Registry.land(Travel.cur_land_id).get("stage"), 0)
	return gen


func _land_dif() -> int:
	var land := get_tree().get_first_node_in_group("active_land") if is_inside_tree() else null
	if land != null:
		var plan: Variant = land.get("plan")
		if plan != null and plan.get("ctx") != null:
			var ctx: Variant = plan.get("ctx")
			if ctx is Dictionary:
				return int((ctx as Dictionary).get("land_dif", 0))
			if ctx is Object and (ctx as Object).get("land_dif") != null:
				return int((ctx as Object).get("land_dif"))
	return Registry.int_of(Registry.land(Travel.cur_land_id).get("dif"), 0)


## Vendor.refill.
func refill_vendor(v: Dictionary) -> void:
	if not bool(v.get("xml", false)):
		return
	if str(v.id) == "random":
		v.buys = []
		_set_rnd_buys(v, 100, "random")
		return
	var lb := limit_buys()
	for e_v in v.buys:
		var e: Dictionary = e_v
		if bool(e.noref) or str(e.tip) in NO_REFILL:
			continue
		var n := _xml_n(str(v.id), str(e.id))
		if n < 0:
			continue
		var lim := int(ceil(n * lb))
		if int(e.kol) < lim:
			e.kol = mini(lim, int(e.kol) + int(ceil(0.25 * lim)))


func _xml_n(vid: String, id: String) -> int:
	for b_v in (_xml.get(vid, {}) as Dictionary).get("buys", []):
		var b: Dictionary = b_v
		if str(b.get("id", "")) == id:
			return int(b.get("n", -1)) if b.has("n") else -1
	return -1


## Game.refillVendors.
func refill_all() -> void:
	_ensure()
	for v in vendors.values():
		refill_vendor(v)
	for key in Travel.triggers.keys():
		if str(Travel.triggers[key]) == "wait":
			Travel.triggers[key] = 1
	var good := Inventory.count("good")
	if good < GOOD_HP:
		Inventory.add("good", GOOD_HP - good)
	elif good > GOOD_HP:
		Inventory.spend("good", good - GOOD_HP)
	Story.info("refill")


## Land.refill: once a land, when a tenth of its xp is taken or it is not random.
func land_refill(land: Node) -> bool:
	if land == null or bool(land.get_meta("refilled", false)):
		return false
	if Travel._is_rnd(Travel.cur_land_id):
		var xp := _xp_of(land)
		if not (xp.x * 10.0 > xp.y):
			return false
	land.set_meta("refilled", true)
	refill_all()
	return true


## Land.summXp / allXp from enemy points: the score gained in this land and
## the most xp it held.
func _xp_of(land: Node) -> Vector2:
	var alive := 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if land.is_ancestor_of(e) and e.get("points") != null:
			alive += float(e.get("points"))
	var key := land.get_instance_id()
	var rec: Dictionary = _land_xp.get(key, {"score": GameState.score, "all": 0.0})
	var summ := float(GameState.score - int(rec.score))
	rec.all = maxf(float(rec.all), alive + summ)
	_land_xp[key] = rec
	return Vector2(summ, float(rec.all))


func _on_land_entered(_id: String) -> void:
	var land := get_tree().get_first_node_in_group("active_land")
	if land != null and not _land_xp.has(land.get_instance_id()):
		_land_xp[land.get_instance_id()] = {"score": GameState.score, "all": 0.0}


# --- Pers barter values ---

func barter_lvl() -> int:
	return Progression.skill_level_of("barter")


func barter_mult() -> float:
	var v := Progression.pers("barterMult", 1.0 - 0.03 * float(Progression.rank("barter")))
	for art in ART_BARTER:
		if Inventory.count(str(art)) > 0:
			v *= float(ART_BARTER[art])
	return v


func limit_buys() -> float:
	return Progression.pers("limitBuys", 1.0 + 0.2 * float(barter_lvl()))


## Pers.repTex.
func rep_text(rep: int) -> String:
	for step: Array in REP_STEPS:
		if rep >= int(step[0]):
			return OriginalLines.pip(str(step[1]))
	return OriginalLines.pip("reput0")


# --- PipBuck context ---

## UnitNPC.activate -> PipBuck.onoff(n): sets vendor / npcId / npcInter.
func open_npc(npc: Node, page: int) -> void:
	var vid := str(npc.get("vendor"))
	npc_inter = str(npc.get("npc_inter"))
	npc_id = str(npc.get("npc_id"))
	if vid == "":
		vendor = {}
	elif _xml.has(vid):
		vendor = vendor_of(vid)
	else:
		vendor = npc_vendor(npc, vid)
		npc_id = ""
	Story.open_pip(page, 0)


func open_work(tip: String) -> void:
	work_tip = tip
	Story.open_pip(7, 0)


func clear_context() -> void:
	vendor = {}
	npc_id = ""
	npc_inter = ""
	work_tip = "work"


func in_base() -> bool:
	return Travel.can_travel_here()


func money() -> int:
	return Inventory.count("money")


func has_tasks() -> bool:
	return npc_id != "" and not vendor.is_empty() and not task_rows().is_empty()


# --- PipPageVend rows ---

func _cat_ok(cats: Array, cat: int, tip: String) -> bool:
	if cat <= 0 or cat >= cats.size():
		return true
	var want: Variant = cats[cat]
	if want is Array:
		return tip in want
	return tip == str(want)


## The weapon variant held (-1 none). Blueprints (respect 3) count as 0.
func owned_variant(id: String) -> int:
	if Inventory.count(id + "^1") > 0:
		return 1
	if Inventory.count(id) > 0 or Inventory.count("s_" + id) > 0:
		return 0
	return -1


func buy_rows(cat: int) -> Array:
	var out: Array = []
	if vendor.is_empty():
		return out
	vendor.mult_price = barter_mult()
	vendor.kol_bou = 0.0
	vendor.kol_sell = 0.0
	for e_v in vendor.buys:
		var b: Dictionary = e_v
		b.bou = 0
		if int(b.kol) <= 0:
			continue
		var tip := str(b.tip)
		if tip == "scheme" and (owned_variant(str(b.id).substr(2)) >= 0 or Inventory.count(str(b.id)) > 0):
			continue
		if tip == "weapon" and owned_variant(str(b.id)) >= int(b.variant):
			continue
		if tip == "armor" and Inventory.count(str(b.id)) > 0:
			continue
		if tip != "weapon" and not _xml_of(b).is_empty() and not _xml_of(b).has("price"):
			continue
		if (tip == "art" or tip == "impl") and Inventory.count(str(b.id)) > 0:
			continue
		if int(b.lvl) > Progression.level or int(b.barter) > barter_lvl():
			continue
		if str(b.trig) != "" and str(Travel.trigger(str(b.trig))) != "1":
			continue
		if bool(b.hardinv) and not Inventory.hard_inv():
			continue
		if not _cat_ok(BUY_CATS, cat, tip):
			continue
		var mp := maxf(item_mult(b), float(vendor.mult_price))
		if bool(b.nocheap):
			mp = 1.0
		var rid := str(b.id) + ("^%d" % int(b.variant) if int(b.variant) > 0 else "")
		var row := {"tip": tip, "id": str(b.id), "rid": rid, "nazv": Inventory.name_of(rid), "sost": float(b.sost),
			"price": price_of(b), "mp": mp, "kol": int(b.kol), "bou": 0, "sort": OriginalLines.pip(tip),
			"barter": int(b.barter), "variant": int(b.variant), "entry": b}
		if tip != "weapon" and tip != "armor":
			row.sost = Inventory.count(str(b.id))
		out.append(row)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a.sort) != str(b.sort):
			return str(a.sort) < str(b.sort)
		if int(a.barter) != int(b.barter):
			return int(a.barter) < int(b.barter)
		return float(a.price) < float(b.price))
	return out


## PipPageVend.selBuy; the info line when the caps run out.
func sel_buy(row: Dictionary, n: int) -> void:
	if int(row.kol) - int(row.bou) <= 0:
		return
	if str(row.tip) == "weapon" and owned_variant(str(row.id)) >= int(row.variant):
		return
	if str(row.tip) == "armor" and Inventory.count(str(row.id)) > 0:
		return
	n = mini(n, int(row.kol) - int(row.bou))
	var unit := float(row.price) * float(row.mp)
	var left := float(money()) - float(vendor.kol_bou)
	if round(unit * n) > left:
		n = int(floor(left / unit)) if unit > 0.0 else n
		if n <= 0:
			Story.info("noMoney", str(int(round(unit - left))))
			return
	row.bou = int(row.bou) + n
	vendor.kol_bou = float(vendor.kol_bou) + unit * n
	vendor.kol_sell = float(vendor.kol_sell) + float(row.price) * n


func unsel_buy(row: Dictionary, n: int) -> void:
	n = mini(n, int(row.bou))
	if n <= 0:
		return
	row.bou = int(row.bou) - n
	vendor.kol_bou = float(vendor.kol_bou) - float(row.price) * float(row.mp) * n
	vendor.kol_sell = float(vendor.kol_sell) - float(row.price) * n


## PipPageVend.trade.
func trade(rows: Array) -> bool:
	if float(vendor.kol_bou) > float(money()):
		return false
	for row_v in rows:
		var row: Dictionary = row_v
		if int(row.bou) <= 0:
			continue
		var e: Dictionary = row.entry
		e.kol = int(e.kol) - int(row.bou)
		if str(row.tip) == "weapon":
			take_weapon(str(row.rid), float(row.sost), 1)
		elif str(row.tip) == "armor":
			Inventory.add(str(row.id), 1)
			Condition.set_armor_hp(str(row.id), float(Condition.armor_max(str(row.id))) * float(row.sost))
		else:
			Inventory.add(str(row.id), int(row.bou))
		row.bou = 0
	var pay := int(ceil(float(vendor.kol_bou)))
	Inventory.spend("money", mini(pay, money()))
	vendor.money = int(vendor.money) + pay
	vendor.kol_bou = 0.0
	vendor.kol_sell = 0.0
	return true


func sell_rows(cat: int) -> Array:
	var out: Array = []
	if not vendor.is_empty():
		vendor.kol_sell = 0.0
		vendor.kol_bou = 0.0
	for id_v in Inventory.carried():
		var id := str(id_v)
		var x: Dictionary = _items.get(id, {})
		if x.is_empty() or float(x.get("sell", 0.0)) <= 0.0 or Inventory.count(id) <= 0:
			continue
		var tip := str(x.get("tip", ""))
		if not _cat_ok(SELL_CATS, cat, tip):
			continue
		var wtip := "drink" if tip == "food" and str(x.get("ftip", "")) == "1" else tip
		out.append({"tip": tip, "id": id, "rid": id, "nazv": Inventory.name_of(id), "kol": Inventory.count(id),
			"bou": 0, "price": float(x.sell), "wtip": wtip, "sort": "a" if wtip == "valuables" else "b"})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a.sort) != str(b.sort):
			return str(a.sort) < str(b.sort)
		if str(a.wtip) != str(b.wtip):
			return str(a.wtip) < str(b.wtip)
		return float(a.price) < float(b.price))
	return out


func sel_sell(row: Dictionary, n: int) -> void:
	n = mini(n, int(row.kol) - int(row.bou))
	if n <= 0:
		return
	row.bou = int(row.bou) + n
	vendor.kol_sell = float(vendor.kol_sell) + float(row.price) * n


func unsel_sell(row: Dictionary, n: int) -> void:
	n = mini(n, int(row.bou))
	if n <= 0:
		return
	row.bou = int(row.bou) - n
	vendor.kol_sell = float(vendor.kol_sell) - float(row.price) * n


## PipPageVend.sell: outside base the vendor must have the caps.
func sell(rows: Array) -> bool:
	if not in_base() and int(ceil(float(vendor.kol_sell))) > int(vendor.money):
		Story.info("noSell")
		return false
	for row_v in rows:
		var row: Dictionary = row_v
		if int(row.bou) <= 0:
			continue
		var found := false
		for e_v in vendor.buys:
			var e: Dictionary = e_v
			if str(e.id) == str(row.id) and int(e.variant) == 0:
				e.kol = int(e.kol) + int(row.bou)
				found = true
				break
		if not found:
			var e := _item("", str(row.id), 0)
			e.kol = int(row.bou)
			vendor.buys.append(e)
		Inventory.spend(str(row.id), int(row.bou))
		row.kol = int(row.kol) - int(row.bou)
		row.bou = 0
	Inventory.add("money", int(floor(float(vendor.kol_sell))))
	vendor.money = int(vendor.money) - int(ceil(float(vendor.kol_sell)))
	vendor.kol_sell = 0.0
	return true


## PipPageVend.sellAll: every valuable.
func sell_all(rows: Array) -> bool:
	for row_v in rows:
		var row: Dictionary = row_v
		if str(row.wtip) == "valuables":
			sel_sell(row, int(row.kol) - int(row.bou))
	return sell(rows)


func repair_rows() -> Array:
	var out: Array = []
	if Inventory.count("owl") > 0:
		var maxhp := float(Pets.stats("owl").maxhp)
		out.append({"tip": "instr", "id": "owl", "rid": "owl", "nazv": Inventory.name_of("owl"),
			"hp": maxf(0.0, Pets.hp_of("owl")), "maxhp": maxhp, "price": maxhp * REP_OWL})
	for id in Inventory.carried():
		var base := id.trim_suffix("^1")
		var w: Dictionary = _weapons.get(base, {})
		if w.is_empty() or not Condition.is_durable_weapon(id) or int(w.get("tip", 0)) in [0, 4]:
			continue
		if Stash.is_hidden(id):
			continue
		var hp := Condition.weapon_hp(id)
		var cap := float(Condition.weapon_max(id))
		if hp >= cap:
			continue
		var variant := 1 if id.ends_with("^1") else 0
		var price := float(w.get("price1", 0.0)) if variant > 0 else float(w.get("price", 0.0))
		out.append({"tip": "weapon", "id": id, "rid": id, "nazv": Inventory.name_of(id), "hp": hp, "maxhp": cap,
			"price": price, "variant": variant})
	for id in Inventory.carried():
		var a: Dictionary = _armors.get(id, {})
		if a.is_empty() or int(a.get("tip", 1)) >= 3 or not Condition.is_armor(id):
			continue
		var hp := Condition.armor_hp(id)
		var cap := float(Condition.armor_max(id))
		if hp >= cap:
			continue
		out.append({"tip": "armor", "id": id, "rid": id, "nazv": Inventory.name_of(id), "hp": hp, "maxhp": cap,
			"price": float(a.get("price", 0.0))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.price) < float(b.price))
	return out


func repair_cost(row: Dictionary) -> int:
	var mp := PRICE_REP_ARMOR if str(row.tip) == "armor" else 1.0
	return int(ceil(float(row.price) * (float(row.maxhp) - float(row.hp)) / maxf(1.0, float(row.maxhp)) * float(vendor.get("mult_price", 1.0)) * mp))


## PipPageVend.itemClick page 3.
func repair(row: Dictionary) -> void:
	var cash := money()
	if cash <= 0:
		return
	var pay := repair_cost(row)
	if pay <= 0:
		return
	pay = mini(pay, cash)
	var mult := float(vendor.get("mult_price", 1.0))
	match str(row.tip):
		"instr":
			var add := pay / REP_OWL / mult
			if add > float(row.maxhp) - float(row.hp):
				add = float(row.maxhp) - float(row.hp)
				pay = int(add * REP_OWL * mult)
			Pets.repair_owl(add)
			row.hp = Pets.hp_of("owl")
		"weapon":
			var add := ceilf(pay / maxf(1.0, float(row.price)) * float(row.maxhp) / mult)
			Condition.set_weapon_hp(str(row.id), minf(float(row.maxhp), Condition.weapon_hp(str(row.id)) + add))
			row.hp = Condition.weapon_hp(str(row.id))
		"armor":
			var add := ceilf(pay / maxf(1.0, float(row.price)) * float(row.maxhp) / mult / PRICE_REP_ARMOR)
			Condition.set_armor_hp(str(row.id), minf(float(row.maxhp), Condition.armor_hp(str(row.id)) + add))
			row.hp = Condition.armor_hp(str(row.id))
	Inventory.spend("money", pay)
	vendor.money = int(vendor.money) + pay


## PipPage.checkQuest.
func _task_ok(task: Dictionary) -> bool:
	if task.has("land"):
		var lid := str(task.land)
		if not Travel.lands.has(lid):
			return false
		var act: Dictionary = Travel.lands[lid]
		var dif := Registry.int_of(Registry.land(lid).get("dif"), 0)
		if not bool(act.get("access", false)) and not bool(act.get("visited", false)) and Progression.level < dif:
			return false
	if task.has("trigger") and str(Travel.trigger(str(task.trigger))) != "1":
		return false
	if task.has("skill") and task.has("skilln"):
		if Progression.skill_level_of(str(task.skill)) < int(task.skilln):
			return false
	return true


func task_rows() -> Array:
	var out: Array = []
	if npc_id == "" or vendor.is_empty() or not bool(vendor.get("xml", false)):
		return out
	for t_v in (_xml.get(str(vendor.id), {}) as Dictionary).get("tasks", []):
		var task: Dictionary = t_v
		if not _task_ok(task):
			continue
		var id := str(task.get("id", ""))
		var row := {"id": id, "state": 0, "sort": 0, "nazv": StoryText.quest_name(id)}
		var q: Variant = Story.quest(id)
		if q != null:
			row.state = int(q.state)
			if row.state == 1 and q.ch_report(npc_id, false):
				row.state = 3
			if row.state == 1 and q.ch_give(npc_id, false):
				row.state = 4
		if int(row.state) in [3, 4]:
			row.sort = 1
		elif int(row.state) == 1:
			row.sort = 2
		elif int(row.state) == 2:
			row.sort = 3
		out.append(row)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.sort) < int(b.sort))
	return out


func task_click(row: Dictionary) -> void:
	var q: Variant = Story.quest(str(row.id))
	if q != null:
		q.ch_give(npc_id, true)
		q.ch_report(npc_id, true)
	else:
		Story.add_quest(str(row.id))


## PipPageInfo quests page in a base: every vendor task the player qualifies for and has not taken.
func open_tasks() -> PackedStringArray:
	var out := PackedStringArray()
	for v_v in _xml.values():
		for t_v in (v_v as Dictionary).get("tasks", []):
			var task: Dictionary = t_v
			var id := str(task.get("id", ""))
			if id == "" or out.has(id) or str(task.get("man", "")) == "1" or not _task_ok(task):
				continue
			var q: Variant = Story.quest(id)
			if q == null or int(q.state) == 0:
				out.append(id)
	return out


## PipPageInfo.addAllQuestsToGameClass.
func take_all_tasks() -> void:
	for id in open_tasks():
		Story.add_quest(id, {}, false, false, false)


## PipPageVend.setSigns: a task to take or to report.
func task_sign() -> bool:
	for row_v in task_rows():
		if int((row_v as Dictionary).state) in [0, 3, 4]:
			return true
	return false


# --- Invent.take for a weapon (tr 1 trade, tr 0 pickup) ---

func take_weapon(uid: String, sost: float, tr: int) -> void:
	var base := uid.trim_suffix("^1")
	var variant := 1 if uid.ends_with("^1") else 0
	var own := owned_variant(base)
	if Inventory.count(base) <= 0 and Inventory.count(base + "^1") <= 0:
		own = -1
	var hp := float(Condition.weapon_max(uid)) * sost
	if own >= 0:
		var cur := base + ("^1" if own > 0 else "")
		if own < variant:
			var held := Inventory.weapon_id == cur
			var keep := Condition.weapon_hp(cur)
			Inventory.spend(cur, 1)
			Inventory.add(uid, 1)
			Condition.set_weapon_hp(uid, minf(keep, float(Condition.weapon_max(uid))))
			if held:
				Inventory.equip(uid)
			cur = uid
			if tr == 0:
				Story.info("takeWeapon", Inventory.name_of(uid), str(int(round(sost * 100.0))))
		if int((_weapons.get(base, {}) as Dictionary).get("tip", 0)) != 5:
			repair_weapon_by(cur, hp)
		return
	if tr == 0:
		Story.info("takeWeapon", Inventory.name_of(uid), str(int(round(sost * 100.0))))
	Inventory.add(uid, 1)
	Condition.set_weapon_hp(uid, hp)


## Invent.repairWeapon(id, hp): a found copy mends the one held.
func repair_weapon_by(id: String, hp: float) -> void:
	var cur := Condition.weapon_hp(id)
	var cap := float(Condition.weapon_max(id))
	var rm := Condition.repair_mult()
	var add := roundf(hp * rm)
	if cur < hp:
		add = roundf(hp - cur + cur * rm)
	Condition.set_weapon_hp(id, minf(cap, cur + add))
	Story.info("repairWeapon", Inventory.name_of(id), str(int(round(Condition.weapon_hp(id) / maxf(1.0, cap) * 100.0))))
	if Progression.perk_rank("barahlo") <= 0:
		return
	var rep := float(Condition.weapon_row(id).get("rep", 1.0))
	if rep <= 0.0:
		return
	var p := maxf(0.3, hp / maxf(1.0, cap) / rep)
	if p < 1.0 and p < randf():
		return
	var n := int(round(p))
	if n > 0:
		Inventory.add("frag", n)
		Story.info("take", Inventory.name_of("frag") + (" (%d)" % n if n > 1 else ""))


## Weapons with com uniq (the uniq loot pool) and a ^1 variant.
func has_uniq(id: String) -> bool:
	return (_weapons.get(id.trim_suffix("^1"), {}) as Dictionary).has("uniq")


func weapon_data(id: String) -> Dictionary:
	return _weapons.get(id.trim_suffix("^1"), {})


func item_data(id: String) -> Dictionary:
	return _items.get(id, {})


func armor_data(id: String) -> Dictionary:
	return _armors.get(id, {})


func _load_data() -> void:
	if not FileAccess.file_exists(DATA):
		push_error("Vendors missing trade.json")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Vendors could not parse trade.json")
		return
	var doc: Dictionary = parsed
	_items = doc.get("items", {})
	_weapons = doc.get("weapons", {})
	_armors = doc.get("armors", {})
	_xml = doc.get("vendors", {})
