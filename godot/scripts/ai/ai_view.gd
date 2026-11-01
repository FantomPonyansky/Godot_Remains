class_name AiView
extends Node2D

## Console aiview: draws what the AI knows over the world. It only reads, so a
## run plays the same with it on. Per unit: state and fraction, and a line to
## its goal while it tracks a player. Per fraction: last-seen markers. Per room:
## an outline while alarmed (10 s), and spawner kol left plus units spawned.
## Per squad (TacticsDirector): spokes to its centre, its label, roles, orders
## and the slot counts.

const NAME := "AiView"
const ROOM := Vector2(1920.0, 1000.0)
const ALARM_SHOW_TICKS := 300
const REDRAW := 0.1
const STATES := ["idle", "patrol", "search", "chase", "hold", "surprised", "flee", "dash", "dash_prep"]
const COLORS := [Color(1, 0.3, 0.3), Color(1, 0.8, 0.2), Color(0.3, 0.8, 1), Color(0.6, 1, 0.4), Color(1, 0.5, 1)]

var _left := 0.0


## Turn the view on or off in the current scene. Returns true when it is on.
static func toggle(tree: SceneTree) -> bool:
	var host := tree.current_scene
	if host == null:
		return false
	var old := host.get_node_or_null(NAME)
	if old != null:
		old.queue_free()
		return false
	var view := AiView.new()
	view.name = NAME
	host.add_child(view)
	return true


func _ready() -> void:
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_left = REDRAW
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	_draw_rooms(font)
	_draw_seen(font)
	_draw_squads(font)
	for node in Units.enemies():
		var unit := node as Node2D
		if unit == null or not is_instance_valid(unit) or bool(unit.get("_dead")):
			continue
		var at := unit.global_position
		var fraction := int(unit.get("fraction"))
		var col: Color = COLORS[posmod(fraction, COLORS.size())]
		draw_circle(at, 6.0, col)
		var st := int(unit.get("ai_state"))
		var label := "%s f%d" % [STATES[st] if st >= 0 and st < STATES.size() else str(st), fraction]
		if bool(unit.get("_asleep")):
			label += " zz"
		draw_string(font, at + Vector2(-30, -unit_height(unit) - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		if unit.get("_track_player") == true:
			var goal: Variant = unit.get("_goal")
			if goal is Vector2:
				draw_line(at, goal, col, 2.0)


func _draw_rooms(font: Font) -> void:
	var now := Sim.tick
	var alarms := AiWorld.alarms_all()
	for fraction in alarms:
		for room: Vector2i in alarms[fraction]:
			if now - int(alarms[fraction][room]) > ALARM_SHOW_TICKS:
				continue
			var r := Rect2(Vector2(room) * ROOM, ROOM).grow(-8.0)
			draw_rect(r, Color(1, 0.2, 0.2, 0.8), false, 4.0)
			draw_string(font, r.position + Vector2(12, 28), "alarm f%d" % fraction, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.3, 0.3))
	var director := SpawnDirector.of(self)
	if director == null:
		return
	var spawners: Dictionary = director.rooms.get("_rooms")
	for key: String in spawners:
		var parts := key.split(",")
		var origin := Vector2(float(parts[0]), float(parts[1])) * ROOM
		var text := "spawn left %d, made %d" % [int(spawners[key].kol), int(director.by_room.get(key, 0))]
		draw_string(font, origin + Vector2(16, ROOM.y - 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.5))


func _draw_seen(font: Font) -> void:
	var now := Sim.tick
	var seen := AiWorld.seen_all()
	for fraction in seen:
		var col: Color = COLORS[posmod(int(fraction), COLORS.size())]
		for pid in seen[fraction]:
			var rec: Dictionary = seen[fraction][pid]
			var at: Vector2 = rec.pos
			draw_line(at + Vector2(-10, -10), at + Vector2(10, 10), col, 3.0)
			draw_line(at + Vector2(-10, 10), at + Vector2(10, -10), col, 3.0)
			var ago := float(now - int(rec.tick)) / 30.0
			draw_string(font, at + Vector2(12, -12), "f%d saw p%d %.1fs" % [int(fraction), int(pid), ago], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)


## TacticsDirector squads: a spoke from each member to the centre, the squad
## label, roles and orders beside the units, and slots granted / denied.
func _draw_squads(font: Font) -> void:
	var tactics := AiWorld.tactics
	if tactics == null:
		return
	for sq: TacticsDirector.Squad in tactics.squads:
		var col: Color = COLORS[posmod(sq.fraction, COLORS.size())]
		var faint := Color(col, 0.35)
		for unit in sq.members:
			if not is_instance_valid(unit):
				continue
			var at := (unit as Node2D).global_position
			draw_line(at, sq.centre, faint, 1.0)
			var role := str(sq.roles.get(unit.get_instance_id(), ""))
			var brain: Variant = unit.call("_ai") if unit.has_method("_ai") else null
			var order: Dictionary = brain.order if brain != null else {}
			var bits: PackedStringArray = []
			if role != "":
				bits.append(role)
			if not order.is_empty():
				bits.append(str(order.get("kind", "")))
				if order.get("at") is Vector2:
					draw_dashed_line(at, order.at, col, 1.5, 8.0)
			if not bits.is_empty():
				draw_string(font, at + Vector2(-30, 14), " ".join(bits), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		draw_circle(sq.centre, 4.0, col)
		draw_string(font, sq.centre + Vector2(8, -6), "sq%d f%d n%d lost %d" % [sq.id, sq.fraction, sq.members.size(), sq.losses], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
	var player := Run.local_player() as Node2D
	if player != null:
		draw_string(font, player.global_position + Vector2(-60, 40), "slots %d / denied %d" % [tactics.granted, tactics.denied], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))


static func unit_height(unit: Node2D) -> float:
	var size: Variant = unit.get("body_size")
	return (size as Vector2).y if size is Vector2 else 60.0
