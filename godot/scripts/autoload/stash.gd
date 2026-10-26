extends Node

## Limited inventory (GameContainer.hardInv) rules the Inventory does not
## carry: the home vault (Item.vault, PipPageVault), hidden weapons
## (Weapon.respect 1, the Stand), Invent.prevArmor for changeArmor and the
## equipment damage of Invent.damageItems. Saved with the run (WorldState
## provider "stash").

signal changed

## PipPageVault: tips that never go to the vault.
const NO_VAULT: PackedStringArray = ["money", "paint", "spell", "spec", "key", "instr", "impl", "art", "scheme"]
## PipPageVault.sbrosHlam keeps these.
const KEEP_TIPS: PackedStringArray = ["food", "book", "sphera", "valuables"]
const NO_ITEM_DAMAGE: PackedStringArray = ["DAM_BLEED", "DAM_POISON", "DAM_INTERNAL", "DAM_PINKCLOUD"]

var vault: Dictionary = {}
var hidden: Dictionary = {}
## Armor.stored: armour and amulets left on the stand.
var stored_armor: Dictionary = {}
var prev_armor := ""

var _eqip: Array = []


func _ready() -> void:
	call_deferred("_register")


func _register() -> void:
	WorldState.register("stash", get_state, set_state)
	WorldState.run_reset.connect(reset_run)


func reset_run() -> void:
	vault.clear()
	hidden.clear()
	stored_armor.clear()
	prev_armor = ""
	changed.emit()


func get_state() -> Dictionary:
	return {"vault": vault.duplicate(), "hidden": hidden.keys(), "stored_armor": stored_armor.keys(), "prev_armor": prev_armor}


func set_state(data: Variant) -> void:
	reset_run()
	if not data is Dictionary:
		return
	var d: Dictionary = data
	for id in (d.get("vault", {}) as Dictionary):
		vault[str(id)] = int(d.vault[id])
	for id in d.get("hidden", []):
		hidden[str(id)] = true
	for id in d.get("stored_armor", []):
		stored_armor[str(id)] = true
	prev_armor = str(d.get("prev_armor", ""))
	changed.emit()


func in_base() -> bool:
	return Travel.can_travel_here()


# --- Vault ---

func vault_count(id: String) -> int:
	return int(vault.get(id, 0))


## Item.kol + Item.vault, the count crafting and the vault page use.
func total(id: String) -> int:
	return Inventory.count(id) + vault_count(id)


## PipPageVault.chKol: n is the wanted vault count.
func set_vault(id: String, n: int) -> void:
	var cur := vault_count(id)
	var d := clampi(n - cur, -cur, Inventory.count(id))
	if d == 0:
		return
	if d > 0:
		Inventory.spend(id, d)
	else:
		Inventory.add(id, -d)
	if cur + d > 0:
		vault[id] = cur + d
	else:
		vault.erase(id)
	changed.emit()


## Invent.minusItem with the vault: carried first, then the vault.
func spend_with_vault(id: String, n: int) -> void:
	var carried := mini(n, Inventory.count(id))
	if carried > 0:
		Inventory.spend(id, carried)
	var rest := n - carried
	if rest > 0 and vault_count(id) > 0:
		var left := vault_count(id) - rest
		if left > 0:
			vault[id] = left
		else:
			vault.erase(id)
		changed.emit()


func vault_ok(id: String) -> bool:
	var x: Dictionary = Vendors.item_data(id)
	if x.is_empty() or bool(x.get("invis", false)):
		return false
	return str(x.get("tip", "")) not in NO_VAULT


func vault_rows(cat: int) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var ids: Array = Inventory.carried()
	ids.append_array(vault.keys())
	for id_v in ids:
		var id := str(id_v)
		if seen.has(id):
			continue
		seen[id] = true
		if (Inventory.count(id) <= 0 and vault_count(id) <= 0) or not vault_ok(id) or Inventory.inv_cat(id) != cat:
			continue
		var x: Dictionary = Vendors.item_data(id)
		var tip := str(x.get("tip", ""))
		var cat_name := OriginalLines.pip(tip) if OriginalLines.has("pip", tip) else OriginalLines.pip("stuff")
		out.append({"id": id, "tip": tip, "nazv": Inventory.name_of(id), "kol": Inventory.count(id), "vault": vault_count(id),
			"mass": Inventory.item_mass(id), "cat": cat_name, "keep": int(x.get("keep", 0)) > 0, "sort2": float(x.get("sort", 0))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a.cat) != str(b.cat):
			return str(a.cat) < str(b.cat)
		if float(a.sort2) != float(b.sort2):
			return float(a.sort2) < float(b.sort2)
		return str(a.nazv) < str(b.nazv))
	return out


## PipPageVault.sbrosHlam.
func to_vault(rows: Array) -> void:
	for row_v in rows:
		var row: Dictionary = row_v
		if str(row.tip) in KEEP_TIPS or bool(row.keep):
			continue
		if str(row.tip) in ["a", "e", "compw"] and _ammo_in_use(str(row.id)):
			continue
		set_vault(str(row.id), vault_count(str(row.id)) + Inventory.count(str(row.id)))


## PipPageVault.checkAmmo.
func _ammo_in_use(id: String) -> bool:
	var x: Dictionary = Vendors.item_data(id)
	var want := id
	if str(x.get("tip", "")) == "a" and x.has("base"):
		want = str(x.base)
	for wid in Inventory.carried():
		var w: Dictionary = Vendors.weapon_data(wid)
		if w.is_empty() or is_hidden(wid):
			continue
		if int(w.get("tip", 0)) == 4 and want == wid:
			return true
		if want == str(w.get("ammo", "")):
			return true
	return false


# --- Hidden weapons (respect) ---

func is_hidden(id: String) -> bool:
	return hidden.has(id)


## Invent.respectWeapon: 1 hides, 2 shows; a hidden weapon or spell in use is put away.
func toggle_hidden(id: String) -> bool:
	if weapon_tip(id) == 4:
		return false
	if hidden.has(id):
		hidden.erase(id)
	else:
		hidden[id] = true
		if Inventory.weapon_id == id:
			Inventory.weapon_id = ""
			Inventory._applied_player = 0
		if Inventory.spell_id == id:
			Inventory.change_spell("", false)
		if MagicBinds.magic_weapon() == id:
			MagicBinds.set_magic("")
	Inventory._save()
	Inventory.changed.emit()
	changed.emit()
	return hidden.has(id)


## PipPageInv: hidden weapons show (and the showhidden button) only like this.
func can_show_hidden() -> bool:
	return not Inventory.hard_inv() or in_base() or _in_train()


## PipPageInv: a hidden spell or magic weapon can always be shown, a weapon
## left on the stand only where the stand can be reached.
func hidden_listable(id: String) -> bool:
	return weapon_tip(id) == 5 or can_show_hidden()


## weapons.xml @tip: 1-3 melee / light / heavy guns, 4 explosives, 5 magic.
func weapon_tip(id: String) -> int:
	return int(Vendors.weapon_data(id.trim_suffix("^1")).get("tip", 0))


## ItemInteraction.canDropWeapon: carried guns and blades, not spells,
## magic, explosives or anything on the stand.
func can_drop_weapon(id: String) -> bool:
	var tip := weapon_tip(id)
	return Inventory.count(id) > 0 and not hidden.has(id) and tip >= 1 and tip <= 3 \
		and not Vendors.weapon_data(id.trim_suffix("^1")).has("spell")


## ItemInteraction.canDropArmor: amulets (tip 3) and stored armour stay.
func can_drop_armor(id: String) -> bool:
	return Inventory.count(id) > 0 and not stored_armor.has(id) and int(Vendors.armor_data(id).get("tip", 1)) != 3


func is_stored(id: String) -> bool:
	return stored_armor.has(id)


## ItemInteraction.storeArmor: worn armour comes off first (not in battle).
func store_armor(id: String, stored: bool) -> bool:
	if Inventory.count(id) <= 0:
		return false
	if stored and Inventory.is_worn(id):
		if GameState._in_battle():
			Story.info("noChArmor")
			return false
		Inventory.unworn(id)
	if stored:
		stored_armor[id] = true
	else:
		stored_armor.erase(id)
	changed.emit()
	return true


func _in_train() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var land := get_tree().get_first_node_in_group("active_land")
	if player == null or land == null:
		return false
	var props := land.get_node_or_null("Actors")
	if props == null or not props.has_method("room_options_at"):
		return false
	return (props.call("room_options_at", player.global_position) as Dictionary).has("train")


# --- UnitPlayer.changeArmor ---

## The battle and hardinv checks, with their info lines. id "" is taking it off.
func can_change_armor(id: String) -> bool:
	if stored_armor.has(id):
		return false
	if GameState._in_battle():
		Story.info("noChArmor")
		return false
	var a: Dictionary = Vendors.armor_data(id)
	var tip := int(a.get("tip", 1))
	var clo := int(a.get("clo", 0))
	if Inventory.hard_inv() and not in_base() and tip == 1 and clo == 0 and id != prev_armor:
		Story.info("noChArmor2")
		return false
	return true


func armor_worn(id: String) -> void:
	var a: Dictionary = Vendors.armor_data(id)
	if id != "" and int(a.get("tip", 1)) == 1 and int(a.get("clo", 0)) == 0:
		prev_armor = id


## PipPageInv: outside base in hardinv the suits that cannot be put on are dim.
func armor_locked(id: String) -> bool:
	var a: Dictionary = Vendors.armor_data(id)
	return Inventory.hard_inv() and not in_base() and int(a.get("tip", 1)) == 1 and int(a.get("clo", 0)) == 0 and id != prev_armor


# --- Invent.damageItems ---

func damage_items(dam: float, destroy := true) -> void:
	if not Inventory.hard_inv():
		return
	if not destroy and not in_base():
		dam = 5.0
	var over := Inventory.mass(1) - Inventory.max_mass("maxm1")
	if over <= 0.0 or dam <= 0.0:
		return
	var p := dam * over / 800.0
	if not (p >= 1.0 or randf() < p):
		return
	var n := int(ceil(p * randf()))
	var eqip := _eqip_ids()
	if eqip.is_empty():
		return
	for _i in 19:
		var id := str(eqip[randi() % eqip.size()])
		if Inventory.count(id) <= 0:
			continue
		var take := mini(n, Inventory.count(id))
		if destroy:
			if take > 0:
				Inventory.spend(id, take)
			Story.info("itemDestr", Inventory.name_of(id), str(n))
		else:
			if not in_base():
				_drop(id, take)
			Story.info("itemLose", Inventory.name_of(id), str(n))
		return


func hit(dam: float, tip: String, tt: bool) -> void:
	if tt or tip in NO_ITEM_DAMAGE:
		return
	damage_items(dam)


## UnitPlayer jump from the ground.
func jumped() -> void:
	if Inventory.hard_inv():
		damage_items(0.0, false)


func _eqip_ids() -> Array:
	if _eqip.is_empty():
		for id in (Inventory._hard.get("items", {}) as Dictionary):
			if Inventory.inv_cat(str(id)) == 1 and Inventory.item_mass(str(id)) > 0.0 and not Vendors.item_data(str(id)).has("perk"):
				_eqip.append(str(id))
	return _eqip


func _drop(id: String, n: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var host := get_tree().get_first_node_in_group("land_props")
	if n <= 0 or player == null or host == null:
		return
	var drop := GroundLoot.new()
	GroundLoot.keep_condition(drop, id)
	if not Inventory.spend(id, n):
		drop.free()
		return
	drop.item_id = id
	drop.stack = n
	drop.auto = false
	host.add_child(drop)
	drop.global_position = player.global_position + Vector2(0, -40.0)
	drop.shove_clear()


# --- retMass ---

## Invent.retMass: n 1-3 the bag categories, 4 weapon slots, 5 magic.
func ret_mass(n: int) -> String:
	var key := "allmass%d" % n
	var cur := 0.0
	var cap := 0.0
	if n >= 1 and n <= 3:
		cur = Inventory.mass(n)
		cap = Inventory.max_mass("maxm%d" % n)
	elif n == 4:
		key = "allweap"
		cur = float(Inventory.mass_w())
		cap = Inventory.max_mass("maxmW")
	else:
		key = "allmagic"
		cur = float(Inventory.mass_m())
		cap = Inventory.max_mass("maxmM")
	return "%s: %s/%d" % [OriginalLines.pip(key), _numb(cur), int(round(cap))]


func over_mass(n: int) -> bool:
	match n:
		4:
			return float(Inventory.mass_w()) > Inventory.max_mass("maxmW")
		5:
			return float(Inventory.mass_m()) > Inventory.max_mass("maxmM")
	return Inventory.mass(n) > Inventory.max_mass("maxm%d" % n)


## Res.numb.
func _numb(v: float) -> String:
	if is_equal_approx(v, round(v)):
		return str(int(round(v)))
	return str(snapped(v, 0.1))

