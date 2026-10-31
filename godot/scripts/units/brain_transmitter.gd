extends UnitBrain

## UnitTransmitter: a necromantic beacon stuck to a floor, ceiling or wall. While the
## player is in the room it ramps up its noise, and inside 400 px it hurts them
## every 30 ticks, harder the closer they are.

const DIST := 1000.0
const DIST_DAM := 400.0

var up_koef := 0.0
var cep := -1


func configure() -> void:
	storona = 1.0
	flips_sprite = false
	ai_state = 1
	if str(u.get_meta("cid", "")) == "box":
		cep = 0


func ready() -> void:
	# Two kinds: `stay` is the floor radio (osn frame 1), `wall` the loudspeaker hung on a
	# ceiling or wall (osn frame 2), picked once by UnitTransmitter.putLoc.
	var at := u.global_position
	var shift := (40.0 - body().x) / 2.0 - 1.0
	if cep < 0 and not solid_at(at + Vector2(0.0, 10.0)):
		if solid_at(at + Vector2(0.0, -50.0)):
			cep = 1
			u.global_position.y -= 10.0
			anim("wall")
			u.anim.rotation = PI * 0.5
		elif solid_at(at + Vector2(-40.0, -10.0)):
			cep = 2
			u.global_position.x -= shift
			anim("wall")
		elif solid_at(at + Vector2(40.0, -10.0)):
			cep = 3
			u.global_position.x += shift
			anim("wall")
			u.anim.flip_h = true


func expl() -> void:
	new_part("metal", 4)


func forces() -> void:
	if cep > 0:
		vel = Vector2.ZERO
		return
	super.forces()


func command(com: String, _val: String = "") -> void:
	match com:
		"off":
			ai_state = 0
		"on":
			ai_state = 1


func control() -> void:
	if not enemy_act():
		up_koef = 0.0
		return
	ai_tch += 1
	if ai_state != 1 or float(u.get("_detect_delay")) > 0.0 or ai_tch % 3 != 1:
		return
	up_koef += 0.05
	var p := player_node()
	var rasst := sqrt(dist2_to_player())
	if p == null or rasst >= DIST:
		return
	var vol := (DIST - rasst) / DIST
	vol = minf(vol * 2.0 if vol < 0.5 else 1.0, up_koef)
	UnitFx.hum(u.get_tree(), str(row.get("snd", {}).get("run", "")), vol)
	if ai_tch % 15 == 1:
		emit_part("necronoise", u.global_position + Vector2(0.0, -10.0), {"alpha": vol})
	if ai_tch % 30 == 1 and rasst < DIST_DAM:
		var rkoef := (DIST_DAM - rasst) / DIST_DAM
		rkoef = rkoef * 2.0 if rkoef < 0.5 else 1.0
		if p.has_method("take_hit"):
			p.take_hit(int(round(dam * rkoef)), tip)


func animate() -> void:
	pass
