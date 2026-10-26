extends RefCounted

## The contextual PipBuck pages drawn by pipbuck.gd: Торговля 4 (PipPageVend),
## Лечение 6 (PipPageMed), Ремесло 7 (PipPageWork) and Хранилище 9
## (PipPageVault). Data and transactions live in Vendors, Craft and Stash.
## Rows: A (click) takes one, X (right click) gives one back, left / right
## step the count, Y (shift + click) takes all. The category buttons of
## PipPageVend.setCats sit above the list; up from the first row reaches them.

const StoryText := preload("res://scripts/story/story_text.gd")
const TROL := "res://assets/ui/trol/%s.png"
const GREEN := Color("00ff99")
const DARK := Color("007e4b")
const ORANGE := Color("ff9900")
const YELLOW := Color("ffff33")
const BUT := Color("004629")
const BUT_ON := Color("006d40")
const VEND := 4
const MED := 6
const WORK := 7
const VAULT := 9
const PAGES := [VEND, MED, WORK, VAULT]
const SUBS := {
	VEND: ["vend1", "vend2", "vend3", "vend4", ""],
	MED: ["med1", "med2", "", "", ""],
	WORK: ["work1", "work2", "work3", "", ""],
	VAULT: ["vault1", "vault2", "vault3", "", ""],
}
const WORK_PAGES := ["craft", "upgrade", "repair"]
## PipPageVend.setCats: the icon of each category button (trol frames).
const CAT_TIPS := {
	0: ["", "weapon", "a", "med", "equip", "stuff", "scheme"],
	1: ["", "valuables", "a", "med", "food", "stuff", "compp"],
}
const MED_ROWS := [["hp", "hp"], ["organism", ""], ["head", "Head"], ["tors", "Tors"], ["legs", "Legs"],
	["blood", "Blood"], ["mana", "Mana"], ["rad", ""], ["cut", ""], ["poison", ""]]
const MED_KIND := {"hp": "hp", "head": "head", "tors": "torso", "legs": "legs", "blood": "blood",
	"mana": "mana", "rad": "rad", "cut": "cut", "poison": "poison"}

var pip
var _cat := {0: 0, 1: 0}
var _key := ""
var _data: Array = []
var _stale := true
var _selall := false
var _cat_buttons: Array[Button] = []
var _focus_cat := -1


func _init(owner: Control) -> void:
	pip = owner


static func handles(page: int) -> bool:
	return page in PAGES


func stale() -> void:
	_stale = true


func sub_label(page: int, i: int) -> String:
	var id := str((SUBS[page] as Array)[i])
	if page == VEND and i == 2 and Vendors.npc_inter == "doc":
		id = "med1"
	return OriginalLines.pip(id) if id != "" else ""


func sub_visible(page: int, i: int) -> bool:
	if str((SUBS[page] as Array)[i]) == "":
		return false
	match page:
		VEND:
			if i == 2:
				return Vendors.npc_inter != "v"
			if i == 3:
				return Vendors.npc_id != ""
		MED:
			if i == 1:
				return Vendors.npc_inter not in ["adoc", "vdoc"] and not Vendors.vendor.is_empty()
		WORK:
			return WORK_PAGES[i] in Craft.work_pages(Vendors.work_tip)
	return true


## PipPageVend / PipPageMed page2Click: the doctor's repair tab is the
## healing page and the healing page's second tab is the trade page.
func redirect(page: int, i: int) -> Array:
	if page == VEND and i == 2 and Vendors.npc_inter == "doc":
		return [MED, 0]
	if page == MED and i == 1:
		return [VEND, 0]
	return []


func first_sub(page: int) -> int:
	for i in 5:
		if sub_visible(page, i):
			return i
	return 0


func fill(page: int, sub: int) -> void:
	_cat_buttons.clear()
	match page:
		VEND:
			_fill_vend(sub)
		MED:
			_fill_med()
		WORK:
			_fill_work(sub)
		VAULT:
			_fill_vault(sub)


func ok(page: int, sub: int) -> void:
	if page == VEND and sub == 0:
		if Vendors.trade(_data):
			_stale = true
	elif page == VEND and sub == 1:
		if _selall:
			Vendors.sell_all(_data)
		else:
			Vendors.sell(_data)
		_stale = true
	elif page == VAULT:
		Stash.to_vault(Stash.vault_rows(sub + 1))
	pip._fill()


## After pipbuck._wire_focus: the category buttons sit between the subpage
## tabs and the first row.
func after_wire() -> void:
	wire_cats(pip, _cat_buttons, int(_cat.get(int(pip._sub[pip._page]), 0)), _focus_cat)
	_focus_cat = -1


static func wire_cats(owner, buttons: Array[Button], cur_i: int, focus_i: int) -> void:
	if buttons.is_empty():
		return
	var sub_b: Control = owner._sub_buttons[int(owner._sub[owner._page])]
	var first: Control = owner._rows[0] if not owner._rows.is_empty() else null
	for i in buttons.size():
		var b := buttons[i]
		b.focus_neighbor_top = b.get_path_to(sub_b)
		b.focus_neighbor_left = b.get_path_to(buttons[maxi(0, i - 1)])
		b.focus_neighbor_right = b.get_path_to(buttons[mini(buttons.size() - 1, i + 1)])
		b.focus_neighbor_bottom = b.get_path_to(first) if first != null else NodePath("")
	var cur := buttons[clampi(cur_i, 0, buttons.size() - 1)]
	if first != null:
		first.focus_neighbor_top = first.get_path_to(cur)
	sub_b.focus_neighbor_bottom = sub_b.get_path_to(cur)
	if focus_i >= 0 and focus_i < buttons.size():
		buttons[focus_i].call_deferred("grab_focus")


func _rows_for(key: String, build: Callable) -> Array:
	if key != _key or _stale:
		_key = key
		_stale = false
		_data = build.call()
		_selall = Vendors.in_base() and key.begins_with("s")
	return _data


# --- Торговля ---

func _fill_vend(sub: int) -> void:
	if Vendors.vendor.is_empty():
		pip._empty.text = OriginalLines.pip("emptybuy")
		return
	match sub:
		0:
			_fill_buy()
		1:
			_fill_sell()
		2:
			_fill_repair()
		3:
			_fill_tasks()


func _cats(sub: int) -> void:
	_cat_buttons = add_cats(pip, CAT_TIPS[sub], int(_cat[sub]), func(i: int) -> void: _set_cat(sub, i))


## PipPage.setCats: one button per tips entry (an Array shows its first tip),
## 32 px apart above the list. pick is called with the button index.
static func add_cats(owner, tips: Array, cur: int, pick: Callable) -> Array[Button]:
	var out: Array[Button] = []
	for i in tips.size():
		var tip := str(tips[i][0] if tips[i] is Array else tips[i])
		var label := "" if tip == "" else OriginalLines.pip(tip)
		if label == tip:
			label = ""
		elif label.length() > 2 and label.substr(1, 1) == " ":
			label = label.substr(2)
		var b := cat_button(tip, cur == i)
		b.tooltip_text = label
		b.position = Vector2(686.0 + 32.0 * i, -31.0)
		b.pressed.connect(pick.bind(i))
		b.focus_entered.connect(func() -> void: owner._title.text = label)
		owner._header.add_child(b)
		out.append(b)
	return out


## PipBuck/butCat: the butCatFon plate (frame 2 when chosen) with the trol
## icon of the tip (frame 1, empty, for "all").
static func cat_button(tip: String, on: bool) -> Button:
	var b := Button.new()
	b.size = Vector2(31, 31)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var plate: Texture2D = load(TROL % ("_fon2" if on else "_fon1"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxTexture.new()
		box.texture = load(TROL % "_fon2") if state in ["hover", "pressed"] else plate
		if state == "focus":
			box.modulate_color = Color(1.4, 1.4, 1.4)
		b.add_theme_stylebox_override(state, box)
	var path := TROL % tip
	if tip != "" and ResourceLoader.exists(path):
		var icon := TextureRect.new()
		icon.texture = load(path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(3, 3)
		icon.size = Vector2(25, 25)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
	elif tip != "":
		b.text = OriginalLines.pip(tip).substr(0, 2)
	return b


## The trol icon of an inventory or trade row, centred where visPipInvItem
## puts it (the name starts just right of it).
static func row_icon(row: Control, tip: String) -> void:
	var path := TROL % tip
	if tip == "" or not ResourceLoader.exists(path):
		return
	var icon := TextureRect.new()
	icon.texture = load(path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(4.5, 2.25)
	icon.size = Vector2(20.5, 19.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)


func _set_cat(sub: int, i: int) -> void:
	SfxBank.play("ui_click")
	_cat[sub] = i
	_focus_cat = i
	_stale = true
	pip._fill()


func _fill_buy() -> void:
	_cats(0)
	var rows := _rows_for("b%d" % int(_cat[0]), func() -> Array: return Vendors.buy_rows(int(_cat[0])))
	if rows.is_empty():
		pip._empty.text = OriginalLines.pip("emptybuy")
	else:
		pip._head([[OriginalLines.pip("iv1"), 30, 200], [OriginalLines.pip("iv2") + " / " + OriginalLines.pip("iv6"), 220, 120, HORIZONTAL_ALIGNMENT_RIGHT],
			[OriginalLines.pip("iv4"), 343.5, 80, HORIZONTAL_ALIGNMENT_RIGHT], [OriginalLines.pip("iv3"), 490, 68, HORIZONTAL_ALIGNMENT_RIGHT]])
	var any := false
	for row_v in rows:
		var row: Dictionary = row_v
		var gear := str(row.tip) == "weapon" or str(row.tip) == "armor"
		var color: Color = YELLOW if int(row.bou) > 0 else GREEN
		var cols: Array = [[str(row.barter) if int(row.barter) > 0 else "", 7, 20, ORANGE], [str(row.nazv), 30, 200, color]]
		if gear:
			cols.append(["%d%%" % int(round(float(row.sost) * 100.0)), 220, 120, color, HORIZONTAL_ALIGNMENT_RIGHT])
			cols.append([OriginalLines.pip("est") if int(row.bou) == 0 else OriginalLines.pip("sel"), 343.5, 80, color, HORIZONTAL_ALIGNMENT_RIGHT])
			cols.append([str(int(round(float(row.price) * float(row.mp)))), 490, 68, color, HORIZONTAL_ALIGNMENT_RIGHT])
		else:
			cols.append([str(int(row.sost)) if int(row.sost) != 0 else "-", 220, 120, color, HORIZONTAL_ALIGNMENT_RIGHT])
			cols.append([str(int(row.kol) - int(row.bou)), 343.5, 80, color, HORIZONTAL_ALIGNMENT_RIGHT])
			cols.append(["< %d >" % int(row.bou), 428, 60, color, HORIZONTAL_ALIGNMENT_CENTER])
			cols.append([Effects._num(round(float(row.price) * float(row.mp) * 10.0) / 10.0), 490, 68, color, HORIZONTAL_ALIGNMENT_RIGHT])
		any = any or int(row.bou) > 0
		pip._row(cols, _pick_data(row, Vendors.sel_buy, Vendors.unsel_buy))
	pip._bottom.text = _buy_text()
	pip._top.text = pip._help("infotrade")
	if any:
		pip._ok.text = OriginalLines.pip("transaction")
		pip._ok.visible = true


func _buy_text() -> String:
	var money := Vendors.money()
	var bou := float(Vendors.vendor.kol_bou)
	var s := "%s: %d (" % [OriginalLines.pip("caps"), money]
	if bou > 0.0:
		s += "-%d; " % int(ceil(bou))
	return s + "%d %s)" % [int(floor(money - bou)), OriginalLines.pip("ost")]


func _pick_data(row: Dictionary, sel: Callable, unsel: Callable) -> Dictionary:
	var id := str(row.get("rid", row.id))
	return {
		"title": str(row.nazv),
		"info": OriginalLines.desc_of(id) if OriginalLines.desc_of(id) != "" else OriginalLines.desc_of(str(row.id)),
		"primary": func() -> void:
			if _no_act():
				return
			_selall_off()
			var all := Input.is_key_pressed(KEY_SHIFT)
			if Input.is_key_pressed(KEY_CTRL):
				unsel.call(row, int(row.bou) if all else 1)
			else:
				sel.call(row, int(row.kol) - int(row.bou) if all else 1)
			pip._fill(),
		"secondary": func() -> void:
			unsel.call(row, 10 if Input.is_key_pressed(KEY_SHIFT) else 1)
			pip._fill(),
		"adjust": func(step: int) -> void:
			if _no_act():
				return
			_selall_off()
			if step > 0:
				sel.call(row, 1)
			else:
				unsel.call(row, 1)
			pip._fill(),
		"third": func() -> void:
			if _no_act():
				return
			_selall_off()
			sel.call(row, int(row.kol) - int(row.bou))
			pip._fill(),
	}


func _selall_off() -> void:
	_selall = false


func _no_act() -> bool:
	if Travel.no_act():
		Story.info("noAct")
		return true
	return false


func _fill_sell() -> void:
	_cats(1)
	var rows := _rows_for("s%d" % int(_cat[1]), func() -> Array: return Vendors.sell_rows(int(_cat[1])))
	if rows.is_empty():
		pip._empty.text = OriginalLines.pip("emptysell")
	else:
		pip._head([[OriginalLines.pip("iv1"), 30, 300], [OriginalLines.pip("iv6"), 343.5, 80, HORIZONTAL_ALIGNMENT_RIGHT],
			[OriginalLines.pip("iv3"), 490, 68, HORIZONTAL_ALIGNMENT_RIGHT]])
	var any := false
	for row_v in rows:
		var row: Dictionary = row_v
		var color: Color = YELLOW if int(row.bou) > 0 else GREEN
		pip._row([[str(row.nazv), 30, 300, color], [str(int(row.kol) - int(row.bou)), 343.5, 80, color, HORIZONTAL_ALIGNMENT_RIGHT],
			["< %d >" % int(row.bou), 428, 60, color, HORIZONTAL_ALIGNMENT_CENTER],
			[Effects._num(round(float(row.price) * 10.0) / 10.0), 490, 68, color, HORIZONTAL_ALIGNMENT_RIGHT]],
			_pick_data(row, Vendors.sel_sell, Vendors.unsel_sell))
		any = any or int(row.bou) > 0
	var s := "%s: %d (+%d)" % [OriginalLines.pip("caps"), Vendors.money(), int(floor(float(Vendors.vendor.kol_sell)))]
	if not Vendors.in_base():
		s += "   %s: %d" % [OriginalLines.pip("vcaps"), int(Vendors.vendor.money)]
	pip._bottom.text = s
	pip._top.text = pip._help("infotrade")
	if _selall and not any:
		pip._ok.text = OriginalLines.pip("sellall")
		pip._ok.visible = true
	elif any:
		_selall = false
		pip._ok.text = OriginalLines.pip("transaction")
		pip._ok.visible = true


func _fill_repair() -> void:
	var rows := Vendors.repair_rows()
	if rows.is_empty():
		pip._empty.text = OriginalLines.pip("emptyrep")
	else:
		pip._head([[OriginalLines.pip("iv2"), 300, 100, HORIZONTAL_ALIGNMENT_RIGHT], [OriginalLines.pip("iv5"), 420, 138, HORIZONTAL_ALIGNMENT_RIGHT]])
	for row_v in rows:
		var row: Dictionary = row_v
		var pct := int(round(float(row.hp) / maxf(1.0, float(row.maxhp)) * 100.0))
		pip._row([[str(row.nazv), 30, 270], ["%d%%" % pct, 300, 100, pip._med(float(row.hp), float(row.maxhp)), HORIZONTAL_ALIGNMENT_RIGHT],
			[str(Vendors.repair_cost(row)), 420, 138, GREEN, HORIZONTAL_ALIGNMENT_RIGHT]], {
			"title": str(row.nazv),
			"info": OriginalLines.desc_of(str(row.id)),
			"primary": func() -> void:
				if _no_act():
					return
				Vendors.repair(row)
				pip._fill(),
		})
	pip._bottom.text = "%s: %d" % [OriginalLines.pip("caps"), Vendors.money()]
	pip._top.text = pip._help("inforepair")


func _fill_tasks() -> void:
	var rows := Vendors.task_rows()
	if rows.is_empty():
		pip._empty.text = OriginalLines.pip("emptytasks")
		return
	var states := {1: "perform", 2: "done", 3: "surr", 4: "progress"}
	var acts := {0: "actTake", 3: "actSurr", 4: "actGive"}
	for row_v in rows:
		var row: Dictionary = row_v
		var st := int(row.state)
		var color: Color = DARK if st == 2 else GREEN
		var text := Story.quest_text(str(row.id), YELLOW.to_html(false), DARK.to_html(false)) if Story.quest(str(row.id)) != null else ""
		if text == "":
			text = StoryText.quest_info(str(row.id))
		if acts.has(st):
			text += "\n\n[color=#%s]%s[/color]" % [ORANGE.to_html(false), OriginalLines.pip(str(acts[st]))]
		pip._row([[str(row.nazv), 30, 360, color], [OriginalLines.pip(str(states[st])) if states.has(st) else "", 400, 158, color]], {
			"title": str(row.nazv),
			"rich": text,
			"primary": func() -> void:
				Vendors.task_click(row)
				pip._fill(),
		})


# --- Лечение ---

func _plata() -> String:
	match Vendors.npc_inter:
		"adoc":
			return "gel"
		"vdoc":
			return "good"
	return "money"


func _fill_med() -> void:
	pip._head([[OriginalLines.pip("medprice"), 420, 138, HORIZONTAL_ALIGNMENT_RIGHT]])
	var cap := maxf(1.0, GameState.organ_max())
	var mmax := maxf(1.0, GameState.mana_max())
	var maxh := float(Progression.max_health()) if Progression.has_method("max_health") else float(GameState.MAX_HEALTH)
	for spec: Array in MED_ROWS:
		var id := str(spec[0])
		if id == "organism":
			pip._row([[OriginalLines.pip("organism") + ":", 7, 300]], {})
			continue
		var kind := str(MED_KIND[id])
		var lvl := ""
		var info_id := id
		var color: Color = GREEN
		match id:
			"hp":
				lvl = "%d/%d" % [GameState.health, int(round(maxh))]
				color = pip._med(float(GameState.health), maxh)
			"rad":
				lvl = str(int(round(GameState.rad)))
			"cut":
				lvl = Effects._num(round(Effects.cut * 10.0) / 10.0)
			"poison":
				lvl = Effects._num(round(Effects.poison * 10.0) / 10.0)
			"mana":
				var stage: int = 4 if GameState.mana_hp <= 0.0 else pip._stage_of(GameState.mana_hp, mmax)
				lvl = "%d/%d" % [int(round(GameState.mana_hp)), int(round(mmax))]
				info_id = "statMana%d" % stage
				color = pip._med(GameState.mana_hp, mmax)
			_:
				var cur: float = {"head": GameState.head_hp, "tors": GameState.torso_hp, "legs": GameState.legs_hp, "blood": GameState.blood_hp}[id]
				lvl = "%d/%d" % [int(round(cur)), int(round(cap))]
				info_id = "stat%s%d" % [str(spec[1]), pip._stage_of(cur, cap)]
				color = pip._med(cur, cap)
		var name := OriginalLines.pip(id)
		if id not in ["hp", "rad", "cut", "poison"]:
			name = "   " + name
		pip._row([[name, 7, 260], [lvl, 260, 150, color, HORIZONTAL_ALIGNMENT_RIGHT],
			[str(int(round(GameState.doctor_price(kind)))), 420, 138, GREEN, HORIZONTAL_ALIGNMENT_RIGHT]], {
			"title": OriginalLines.pip(info_id),
			"info": OriginalLines.desc("pip", info_id),
			"primary": _heal.bind(kind),
		})
	var plata := _plata()
	var label := OriginalLines.pip("caps") if plata == "money" else OriginalLines.name_of(plata)
	pip._bottom.text = "%s: %d" % [label, Inventory.count(plata)]
	pip._top.text = pip._help("usemed2")


## PipPageMed.itemClick.
func _heal(kind: String) -> void:
	if _no_act():
		return
	var plata := _plata()
	var funds := Inventory.count(plata)
	var cost := GameState.doctor_heal(kind, float(funds), float(funds))
	var paid := mini(int(round(cost)), funds)
	if paid > 0:
		Inventory.spend(plata, paid)
		if plata == "money" and not Vendors.vendor.is_empty():
			Vendors.vendor.money = int(Vendors.vendor.money) + paid
	pip._fill()


# --- Ремесло ---

func _fill_work(sub: int) -> void:
	var station := Vendors.work_tip
	var page := str(WORK_PAGES[clampi(sub, 0, 2)])
	pip._title.text = Craft.work_title(station)
	var rows := Craft.work_rows(station, page)
	if rows.is_empty():
		pip._empty.text = Craft.work_empty(page)
		return
	for row_v in rows:
		var row: Dictionary = row_v
		var color: Color = GREEN if bool(row.get("skilled", true)) else DARK
		var id := str(row.get("result", row.get("id", "")))
		pip._row([[Craft.work_text(row, page), 7, 546, color]], {
			"title": Inventory.name_of(id),
			"info": Craft.work_detail(row, page) + "\n\n" + OriginalLines.desc_of(id),
			"primary": func() -> void:
				Craft.work_activate(station, page, row)
				pip._fill(),
		})


# --- Хранилище ---

func _fill_vault(sub: int) -> void:
	var cat := sub + 1
	var hard := Inventory.hard_inv()
	var cols: Array = [[OriginalLines.pip("ii2"), 30, 250], [OriginalLines.pip("ii7"), 250, 170, HORIZONTAL_ALIGNMENT_CENTER]]
	if hard:
		cols.append([OriginalLines.pip("ii8"), 430, 50, HORIZONTAL_ALIGNMENT_RIGHT])
		cols.append([OriginalLines.pip("ii9"), 490, 68, HORIZONTAL_ALIGNMENT_RIGHT])
	pip._head(cols)
	for row_v in Stash.vault_rows(cat):
		var row: Dictionary = row_v
		var id := str(row.id)
		var color: Color = DARK if int(row.kol) == 0 else GREEN
		var line: Array = [[str(row.nazv), 30, 250, color], [str(int(row.kol)), 250, 70, color, HORIZONTAL_ALIGNMENT_RIGHT],
			["< %d >" % int(row.vault), 340, 80, color, HORIZONTAL_ALIGNMENT_CENTER]]
		if hard:
			line.append([Stash._numb(float(row.mass)), 430, 50, color, HORIZONTAL_ALIGNMENT_RIGHT])
			line.append([Stash._numb(float(row.mass) * float(row.kol)), 490, 68, color, HORIZONTAL_ALIGNMENT_RIGHT])
		pip._row(line, {
			"title": str(row.nazv),
			"info": OriginalLines.desc_of(id),
			"primary": func() -> void:
				Stash.set_vault(id, Stash.total(id))
				pip._fill(),
			"secondary": func() -> void:
				Stash.set_vault(id, 0)
				pip._fill(),
			"adjust": func(step: int) -> void:
				Stash.set_vault(id, Stash.vault_count(id) + step)
				pip._fill(),
		})
	if pip._rows.is_empty():
		pip._empty.text = OriginalLines.pip("emptyinv")
	if sub >= 1:
		pip._ok.text = OriginalLines.pip("tovault")
		pip._ok.visible = true
	pip._top.text = pip._help("vaultupr")
	if hard:
		pip._bottom.text = Stash.ret_mass(cat)
