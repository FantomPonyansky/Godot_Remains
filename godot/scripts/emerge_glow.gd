extends "res://scripts/magic_aura.gd"

## Unit.step while t_emerg: vis.filters = GlowFilter(0xAADDFF, tf, tf * 20, tf * 20, 1, 3)
## and vis.alpha = 1 - tf, tf = t_emerg / (max_emerg + 1).

const COLOR := Color("aaddff")
## Flash blur b with quality 3 is a gaussian of sigma ~0.493 b; the kernel holds sigma 2.96 taps.
const SIGMA_PER_BLUR := 0.493
const KERNEL_SIGMA := 2.96

var tf := 0.0


static func attach_to(unit: Node) -> Node:
	var glow := (load("res://scripts/emerge_glow.gd") as GDScript).new() as Node2D
	glow.name = "EmergeGlow"
	glow.set("host", unit)
	glow.set_meta("no_tele_glow", true)
	glow.process_mode = Node.PROCESS_MODE_ALWAYS
	unit.add_child(glow)
	return glow


func _update(node: Node, glow: Sprite2D, _color: Color) -> void:
	super._update(node, glow, COLOR)
	var sigma := SIGMA_PER_BLUR * tf * 20.0
	var spread := maxf(1.0, sigma / KERNEL_SIGMA)
	var mat := glow.material as ShaderMaterial
	mat.set_shader_parameter("glow_color", Color(COLOR.r, COLOR.g, COLOR.b, tf))
	mat.set_shader_parameter("sigma", sigma / spread if sigma > 0.0 else 0.01)
	mat.set_shader_parameter("spread", spread)
	mat.set_shader_parameter("margin", 6.0 * spread + 1.0)
