extends StaticBody2D

const _Art := preload("res://scripts/door_art.gd")


func _ready() -> void:
	if bool(get_meta("breakable", false)):
		add_to_group("destructibles")


## amount is char_destroy (block damage), not hit-point damage.
## Tile.udar: thre > hit does nothing. Otherwise the full hit comes off HP.
## Box.damage subtracts thre first; doors do not use that path.
## EMP ammo forces destroy to 0 (Weapon.setBullet).
func take_hit(amount: int = 0, type: String = "") -> void:
	if bool(get_meta("dead", false)) or not bool(get_meta("breakable", false)):
		return
	if bool(get_meta("door_open", false)):
		return
	var hit := amount
	if type == "DAM_EMP":
		hit = 0
	if int(get_meta("thre", 0)) > hit or hit <= 0:
		return
	var left := int(get_meta("hp", 1)) - hit
	set_meta("hp", left)
	if left <= 0:
		_Art.break_open(self)
