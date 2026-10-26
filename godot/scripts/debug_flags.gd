extends RefCounted

## Port-only debug hotkeys (craft F6/F7/F8, the begin-land map on F1 / pad Y)
## work only when the game is started with --debug-keys, e.g.
##   Godot.exe --path godot -- --debug-keys
## The debug console (`) is not gated.

const FLAG := "--debug-keys"

static var _on := -1


static func keys() -> bool:
	if _on < 0:
		_on = 1 if FLAG in OS.get_cmdline_user_args() or FLAG in OS.get_cmdline_args() else 0
	return _on == 1
