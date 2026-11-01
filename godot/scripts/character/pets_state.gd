extends RefCounted

## One character's pets fields (ARCHITECTURE_PLAN R3.1).
## pets.gd forwards a property of the same name to each.

var current: String = ""
var ret_pet: String = ""
var no_pet: int = 0
var no_pet2: int = 0
var proc: Dictionary = {"phoenix": 1.0, "owl": 1.0}
var down: Dictionary = {"phoenix": true, "owl": true}
var pet: CharacterBody2D = null
var _k_pet: int = 0
var _held_out: bool = false
var _pet_on: bool = true
var _fresh_call: bool = false
