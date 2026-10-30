extends UnitBrain

## UnitRoller: the shared Brain + WalkMotor + BodyAttack of a rolling ball robot.
## It never strolls; once alerted it rolls at the target, hops at reach and slams
## on contact. roller2 bursts into plasma when destroyed.

const SPIN := 1.5
const ALERT_RANGE := 200.0
const CALM_RANGE := 600.0
const HOP := 0.3

var roll_spin := 0.0
var alert_frame := false
var alert_left := 0


func configure() -> void:
	max_speed += randf_range(-1.0, 1.0)
	walk_speed = max_speed
	run_speed = max_speed
	elast = 0.8
	storona = 1.0
	flips_sprite = false


func ready() -> void:
	u.anim.rotation = randf() * TAU
	# setVisPos draws the ball at the body centre, and the sheet's origin is the ball's.
	u.anim.position = Vector2(0.0, -body().y * 0.5)


func drop_loot() -> void:
	if tr >= 2 or id == "roller2":
		explode(dam * 4.0, "DAM_PLASMA", 150.0)


func control() -> void:
	if not enemy_act():
		return
	if ai_tch % 10 == 1:
		if find_cel():
			ai_spok = max_spok
			alert_left = randi_range(40, 90)
	if ai_tch > 0:
		ai_tch -= 1
	else:
		ai_tch = 10
	if alert_left > 0:
		alert_left -= 1
	var alert := ai_spok > 0 or alert_left > 0
	ai_state = 1 if alert else 0
	walk = 0.0
	if alert:
		var dx := cel.x - u.global_position.x
		walk = signf(dx) if absf(dx) > 4.0 else 0.0
		if walk != 0.0:
			storona = walk
			if absf(vel.x) < max_speed or signf(vel.x) != walk:
				vel.x += walk * accel
		var reach := body().x * 0.5 + 40.0
		if stay and cel_unit != null and absf(dx) < reach * 4.0 and cel.y < center().y - 20.0 and rnd(0.1):
			vel.y = -jumpdy * randf_range(0.5, 1.0)
	if turn_x != 0.0:
		turn_x = 0.0
	var p := player_node()
	if p != null and att_korp(p):
		vel.y -= jumpdy * HOP
		vel.x = -vel.x * 0.5


func animate() -> void:
	var d2 := dist2_to_player()
	if ai_state == 0:
		alert_frame = false
	elif d2 < ALERT_RANGE * ALERT_RANGE:
		alert_frame = true
	elif d2 > CALM_RANGE * CALM_RANGE:
		alert_frame = false
	# osn frame 1 is shut, frame 2 the open shell whose spikes play (UnitRoller.animate).
	anim("walk" if alert_frame and has_clip("walk") else "stay")
	if stay or turn_y < 0.0:
		roll_spin = vel.x * SPIN
	turn_y = 0.0
	u.anim.rotation += deg_to_rad(roll_spin)


func expl() -> void:
	new_part("metal", 4)
	new_part("miniexpl")
