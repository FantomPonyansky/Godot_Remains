class_name VisSnapshot
extends RefCounted
## Stand-in for OTHER's CPU snapshot of a visual (BitmapData.draw); the port never asks.


static func compose(_vis: Node, _ct: Variant) -> Image:
	return null


static func origin_of(_vis: Node) -> Vector2:
	return Vector2.ZERO
