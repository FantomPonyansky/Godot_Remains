extends RefCounted

## Pers.setGlobalDif for dif0..dif4. neujaz is Pers.neujazMax in ticks; below
## dif3 setGlobalDif leaves the Pers default of 30. him_bad_dif scales chem
## addiction, bonus_heal_mult the bonus heal pickups, price_* the doctors
## (PipPageMed, per point healed; price_hp 0.5 and price_mana 1 on every level).
## pet_res is Pers.petRes, the phoenix's rebirth wait in seconds.
## The chosen row is UiSettings difficulty. GameState.difficulty / dif_value
## forward here so call sites keep their names.
const PATH := "res://assets/data/balance/difficulty.json"
static var ROWS: Array = []
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	ROWS = DataLib.rows(PATH)


static func level() -> int:
	_ensure()
	var n := ROWS.size()
	if n <= 0:
		return 0
	return clampi(UiSettings.difficulty(), 0, n - 1)


static func value(key: String) -> float:
	_ensure()
	if ROWS.is_empty():
		return 0.0
	return float((ROWS[level()] as Dictionary).get(key, 0.0))
