extends RefCounted

## One character's stash fields (architecture step R3.1).
## stash.gd forwards a property of the same name to each.

var vault: Dictionary = {}
var hidden: Dictionary = {}
var stored_armor: Dictionary = {}
var prev_armor: String = ""
