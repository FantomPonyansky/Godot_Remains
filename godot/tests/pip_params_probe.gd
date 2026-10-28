extends Node

## Prints the PipBuck Status Main param rows and whether each has a tooltip,
## then the perk / skill tooltip text for the ids in the user args.

func _ready() -> void:
	for row in preload("res://scripts/pip_params.gd").rows():
		var id := str(row[0])
		print("[pp] %s | %s | %s | tip %d" % [id, OriginalLines.pip(id), row[1], OriginalLines.desc("pip", id).length()])
	print("[pp] diff tip %d" % OriginalLines.desc("gui", "dif%d" % UiSettings.difficulty()).length())
	var pip: Node = load("res://scenes/pipbuck.tscn").instantiate()
	add_child(pip)
	for id in OS.get_cmdline_user_args():
		if id.begins_with("--"):
			continue
		print("[pp] keys %s %s" % [id, OriginalLines.keys_of("eff", id)])
		print("[pp] tip %s: %s" % [id, pip._eff_str(id, 1)])
		print("[pp] item %s: %s" % [id, OriginalLines.desc_of(id)])
	get_tree().quit()
