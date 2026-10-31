class_name FlashUiBlend
extends RefCounted
## Stand-in for OTHER's UI blend helper (see entity_effects.gd).


static func under_canvas_group(node: Node) -> bool:
	var at := node.get_parent() if node else null
	while at != null:
		if at is CanvasGroup:
			return true
		at = at.get_parent()
	return false
