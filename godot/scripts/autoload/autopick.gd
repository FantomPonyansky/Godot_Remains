extends Node

## AutoPickupManager: the 14 switches, all true by default, and
## Item.checkAuto. `enabled` is the port's master switch (pause menu).
## A missing user://autopick.cfg keeps the defaults.

signal changed(enabled: bool)

const _UserDir := preload("res://scripts/user_dir.gd")
static var PATH := _UserDir.settings("autopick.cfg")
const _Chrome := preload("res://scripts/pip_chrome.gd")
const IDS: PackedStringArray = ["vsWeaponNew", "vsWeaponRep", "vsAmmoAll", "vsAmmoTek", "vsExplAll",
	"vsMedAll", "vsHimAll", "vsEqipAll", "vsStuffAll", "vsVal", "vsBook", "vsFood", "vsComp", "vsIngr"]
## PipPageOpt PAGE_AUTOPICKUP_OPT: these rows are indented under vsStuffAll.
const SUB: PackedStringArray = ["vsVal", "vsBook", "vsFood", "vsComp", "vsIngr"]

var enabled: bool = true
var flags: Dictionary = {}
var _buttons: Array[CheckButton] = []


func _init() -> void:
	_load()


func flag(id: String) -> bool:
	return bool(flags.get(id, true))


func set_flag(id: String, on: bool) -> void:
	flags[id] = on
	_save()


## Item.checkAuto(false): whether a loot item is taken by walking over it.
func wants(id: String, n: int = 1) -> bool:
	if Inventory.weapon_def_kind(id) != "" and not Inventory.casts_spell(id):
		if Inventory.count(id) > 0:
			return flag("vsWeaponRep") and Inventory.auto_take_ok(id, n)
		return flag("vsWeaponNew") and Inventory.auto_take_ok(id, n)
	if Inventory.casts_spell(id) or Inventory.can_wear(id):
		return true
	if Inventory.item_mass(id) <= 0.0:
		return true
	if not Inventory.auto_take_ok(id, n):
		return false
	var x: Dictionary = Vendors.item_data(id)
	var tip := str(x.get("tip", ""))
	if tip == "a" and (flag("vsAmmoAll") or (flag("vsAmmoTek") and _ammo_used(id, str(x.get("base", id))))):
		return true
	if tip == "e":
		return flag("vsExplAll")
	if tip in ["med", "pot"]:
		return flag("vsMedAll")
	if tip == "him":
		return flag("vsHimAll")
	if tip == "equip" and flag("vsEqipAll"):
		return true
	if flag("vsStuffAll") and Inventory.inv_cat(id) == 3:
		return true
	if tip == "valuables":
		return flag("vsVal")
	if tip in ["book", "sphera"]:
		return flag("vsBook")
	if tip in ["food", "eda"]:
		return flag("vsFood")
	if tip in ["stuff", "compa", "compw", "compe", "compm"]:
		return flag("vsComp")
	if tip == "compp":
		return flag("vsIngr")
	return false


## Ammo for a carried gun (not explosives or magic) the player still uses.
func _ammo_used(id: String, base: String) -> bool:
	for wid in Inventory.carried():
		if Inventory.weapon_def_kind(str(wid)) in ["explosives", "magic"] or Stash.is_hidden(str(wid)):
			continue
		var ammo := str(Vendors.weapon_data(str(wid)).get("ammo", ""))
		if ammo != "" and (ammo == id or ammo == base):
			return true
	return false


func set_enabled(on: bool) -> void:
	if on == enabled:
		_refresh_buttons()
		return
	enabled = on
	_save()
	_refresh_buttons()
	changed.emit(enabled)


func make_block() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	var button := CheckButton.new()
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 32)
	button.set_pressed_no_signal(enabled)
	button.add_theme_color_override("font_color", _Chrome.AMBER)
	button.add_theme_color_override("font_hover_color", _Chrome.AMBER)
	button.add_theme_color_override("font_pressed_color", _Chrome.AMBER)
	button.toggled.connect(set_enabled)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", _Chrome.AMBER_DIM)
	block.add_child(button)
	block.add_child(hint)
	_buttons.append(button)
	var relabel := func(_lang: String) -> void:
		button.text = OriginalLines.pip("autotake")
		hint.text = Locale.t("pickup_hint")
	relabel.call("")
	Locale.language_changed.connect(relabel)
	button.tree_exiting.connect(func() -> void:
		_buttons.erase(button)
		if Locale.language_changed.is_connected(relabel):
			Locale.language_changed.disconnect(relabel)
	)
	block.set_meta("toggle", button)
	return block


func _refresh_buttons() -> void:
	for button in _buttons:
		if is_instance_valid(button) and button.button_pressed != enabled:
			button.set_pressed_no_signal(enabled)


func _load() -> void:
	enabled = true
	flags.clear()
	if not FileAccess.file_exists(PATH):
		return
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	enabled = bool(cfg.get_value("pickup", "enabled", true))
	for id in IDS:
		if cfg.has_section_key("pickup", id):
			flags[id] = bool(cfg.get_value("pickup", id))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("pickup", "enabled", enabled)
	for id: String in flags:
		cfg.set_value("pickup", id, bool(flags[id]))
	cfg.save(PATH)
