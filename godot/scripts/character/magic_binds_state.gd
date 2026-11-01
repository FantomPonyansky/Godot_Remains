extends RefCounted

## One character's magic_binds fields (ARCHITECTURE_PLAN R3.1).
## magic_binds.gd forwards a property of the same name to each.

var _slots: Array[String] = []
var _magic: String = ""
var _throw: String = ""
var _queued: Array[String] = []
