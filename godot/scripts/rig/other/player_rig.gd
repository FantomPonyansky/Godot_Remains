extends "res://scripts/rig/other/rig_base.gd"
## Player character rig controller (visualLittlePip).
##
## The generic part — data loading, node discovery, textures, label variants,
## library switching, playback, tickers, colour channels — is rig_base.gd.
## This subclass adds what Flash's UnitPlayer/Appear/Obj do to the pony in
## code: armour (with the hide-mane rule), eyes (state, style, blink, pupil),
## face, hair and hair1, the cutie mark, wings (pegasus flap, alicorn subtree,
## spread), PipBuck side sync, magic glow, spell origin, head/hair rotation,
## and the root attachments (rat, cryst, fetter, shit, inh, svet).
##
## Data lives in res://assets/rigs/player/data/ as split files mirroring Flash source:
##   index.json, hierarchy.json, state_machine.json, symbols/{name}.json

var _shader_rainbow: Shader = preload("res://assets/rigs/shaders/color_transform_rainbow.gdshader")

var _hide_mane_armors: Array = []
var _morda_bones: Array = []
var _eye_bones: Array = []

var _vis_hair1: bool = false
var _rat_form: bool = false
var _wings_enabled: bool = false
var _wing_alicorn: bool = false
var _facing_right: bool = true
var _hair_frame: int = 0
var _eye_style: int = 0
var _face_frame: int = 0
# hind-leg bone name -> cutie mark hidden (Flash `sleg1.mark.visible=false`)
var _mark_hidden: Dictionary = {}

# Cached references to nested nodes for runtime property animation
var _node_morda: Node2D
var _node_hair: Node2D
var _node_eye: Node2D           # eye container
var _node_eye0: Node2D          # eye0 container (child of eye)
var _node_eye_spr: Sprite2D     # eye container's first element sprite (eye.png / eye_f1/f2/f3)
var _node_zrak_normal: Node2D   # zrak inside eye0 (normal state pupil)
var _node_zrak_shocked: Node2D  # zrak direct child of eye (shocked state pupil)
var _node_magic: Node2D
var _eye_state: int = 0         # 0=normal, 1=shocked, 2=closed, 3=alt-closed
var _zrak_home := Vector2.ZERO  # the pupil's authored place in eye0 (Flash: a new eye0 puts zrak there)

# Self-animating nested symbols of the player: konc sparkle, pegasus wing
# flap, tail_run strands, crystal shield (see RigBase._tickers).
const TICKER_TABLE: Dictionary = {
	# konc.xml: 7 frames, no script, loops; frames 0-1 are empty
	"konc": {"frames": [0, 1, 2, 3, 4, 5, 6], "loop_from": 0, "idle_frame": -1},
	# rwing/lwing.xml: stop() at 0 (folded), gotoAndPlay(2) at 9 -> loop 1..8
	"rwing": {"frames": [1, 2, 3, 4, 5, 6, 7, 8], "loop_from": 0, "idle_frame": 0},
	"lwing": {"frames": [1, 2, 3, 4, 5, 6, 7, 8], "loop_from": 0, "idle_frame": 0},
	# tail_runa*/tail_runb*.xml: 10 frames, gotoAndPlay(3) at 9 -> 0,1 then loop 2..8
	"tail_strand": {"frames": [0, 1, 2, 3, 4, 5, 6, 7, 8], "loop_from": 2, "idle_frame": 0},
	# crystal.xml (UnitPlayer.as:887-892): gotoAndPlay(1) plays 0..4, stop();
	# gotoAndPlay(10) plays 9..14 into the empty frame 14, stop()
	"crystal_up": {"frames": [0, 1, 2, 3, 4], "loop_from": -1, "idle_frame": -1},
	"crystal_down": {"frames": [9, 10, 11, 12, 13, 14], "loop_from": -1, "idle_frame": -1},
	# shit1.xml (magic shield `vis.shit`, UnitPlayer.as:3044-3050): 20 frames,
	# stop() at 0 and 19. gotoAndPlay(1) is issued while the clip already
	# sits on frame 1 (constructed there, or sent back by gotoAndStop(1)), so
	# the frame-1 stop() does not run again and the clip plays 0..19 and holds.
	"shield": {"frames": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
			"loop_from": -1, "idle_frame": 0},
}
# The shit10 tween inside shit1 (scale 0.42->1, alphaOffset -232->0->+90->0) is
# baked per frame into the symbol data and applied by RigBase._apply_nested_frame_transform.
const TAIL_STRAND_LIBS: Array[String] = [
	"tail_runa0", "tail_runa2", "tail_runa3", "tail_runa4",
	"tail_runb0", "tail_runb2", "tail_runb3", "tail_runb4",
]
# Libraries in the alicorn wing subtree (aliwing -> wing1/wing2 -> pero -> konc).
const _ALICORN_WING_LIBS: Array[String] = ["aliwing", "wing1", "wing2", "pero", "konc"]
# morda.konec, the spell origin marker in morda's space (get_spell_origin).
const KONEC := Vector2(-54.4, -75.15)
var _wing_flapping: bool = false
# The mane rule set_armor last received (-1: the hide_mane_armors list; 0/1:
# the driver's Obj.setVisible h), re-applied by refresh_visuals.
var _mane_rule: int = -1


# =============================================================================
# RigBase hooks
# =============================================================================

func _default_paths() -> Dictionary:
	return {"data_dir": "res://assets/rigs/player/data/", "art_dir": "res://assets/rigs/player/art/",
			"anim_library": "res://assets/rigs/player/player_rig_anims.tres"}


func _rig_default_idle() -> String:
	## Flash: a fresh visualLittlePip sits on _osn frame 'stay'.
	return "body_stay"


func _rig_load_data() -> void:
	_morda_bones = _index.get("morda_bones", [])
	_eye_bones = _index.get("eye_bones", [])
	_hide_mane_armors = _index.get("hide_mane_armors", [])


func _rig_load_textures() -> void:
	# Pero shape mask (feather silhouette for the rainbow gradient shader).
	_load_texture_by_name("pero_shape")


func _rig_cache_refs() -> void:
	_cache_nested_refs()


func _rig_setup_visuals() -> void:
	_apply_pero_rainbow()


func _rig_setup_tickers() -> void:
	_setup_tickers()


func _rig_update_ticker_activity() -> void:
	_update_ticker_activity()


func _rig_ready() -> void:
	apply_default_colors()
	set_eye_state(0)
	set_facing_right(true)


func _rig_after_ready() -> void:
	_sync_pipbuck()


func _rig_process(_delta: float) -> void:
	# Wings: runtime visibility (Flash: UnitPlayer.visDetails() — pers.ableFly).
	# Visibility tracks stripped from animations; this is the sole controller.
	var rw: Node2D = _bones.get("rwing")
	var lw: Node2D = _bones.get("lwing")
	if _wings_enabled:
		if rw and not rw.visible:
			rw.visible = true
		if lw and not lw.visible:
			lw.visible = true
	else:
		if rw and rw.visible:
			rw.visible = false
		if lw and lw.visible:
			lw.visible = false

	# Sync PipBuck to front leg every frame (Flash: UnitPlayer.otherVisual()).
	# Animation tracks drive pip1/pip2 position independently, but Flash
	# overrides pip.x/y/rotation from frleg3/flleg3 every frame.
	_sync_pipbuck()


func _rig_lib_frame(lib: String) -> int:
	## The eye style for eye0, the face for morda0, the hair style for the
	## tail_run strand containers.
	if lib in _eye_bones:
		return _eye_style
	if lib in _morda_bones:
		return _face_frame
	if lib == "tail_runa" or lib == "tail_runb":
		return _hair_frame
	return 0


func _rig_nested_gate(entry: Dictionary) -> bool:
	## The hair1 layer and the cutie-mark hide.
	var lib: String = entry["library"]
	if not _vis_hair1 and lib in _color_channels.get("trHair1", []):
		return false
	if lib == "quti" and _mark_hidden.get(entry["bone_name"], false):
		return false
	return true


func _rig_refresh_variant() -> void:
	## Flash refreshVis(): every frame script (setArmor/setColor/setHair/
	## setEye/setMorda/setVisible) runs again.
	set_armor(_variant_id, _mane_rule)
	set_hair(_hair_frame)
	set_eye_style(_eye_style)
	set_eye_state(_eye_state)
	set_face(_face_frame)
	set_wing_alicorn(_wing_alicorn)


func _rig_replay_methods() -> Array[String]:
	return ["_swap_bone_lib", "_set_bone_graphic", "set_eye_state", "set_mark_visible",
			"_on_child_goto", "_on_child_visible"]


func _rig_on_bone_lib_swapped(bone_name: String, _lib_name: String) -> void:
	if bone_name == "tail":
		_update_ticker_activity()


func _rig_on_facing_changed(right: bool) -> void:
	## otherVisual() reads vis.scaleX to select the PipBuck side.
	set_facing_right(right)


func _cache_nested_refs() -> void:
	## Cache references to nested nodes used for runtime property animation.
	## Uses _morda_bones/_eye_bones to identify registered face/eye nodes.

	# Obj.setMorda registers the artwork node (e.g. morda0), but _node_morda
	# needs the parent container (morda) for head rotation / horn position.
	# Resolve: find vis_lib of registered morda bones → that's the container library.
	var morda_containers: Dictionary = {}
	for entry: Dictionary in _nested:
		if entry["library"] in _morda_bones:
			morda_containers[entry["vis_lib"]] = true

	# Obj.setEye registers the inner eye node (e.g. eye0).  _node_eye needs
	# the parent container (eye) for the eye sprite.  Same vis_lib resolution.
	var eye_containers: Dictionary = {}
	for entry: Dictionary in _nested:
		if entry["library"] in _eye_bones:
			eye_containers[entry["vis_lib"]] = true

	for entry: Dictionary in _nested:
		var lib: String = entry["library"]
		if morda_containers.has(lib):
			if entry["node"] is Node2D:
				_node_morda = entry["node"]
		elif lib == "hair":
			if entry["node"] is Node2D:
				_node_hair = entry["node"]
		elif eye_containers.has(lib):
			if entry.get("is_container", false):
				_node_eye = entry["node"]
				_node_eye_spr = _get_sprite_for_nested(entry)
		elif lib in _eye_bones:
			if entry.get("is_container", false):
				_node_eye0 = entry["node"]
		elif lib == "zrak":
			# Two zrak instances: one inside eye0 (normal), one direct child of eye (shocked).
			# Distinguish by vis_lib: "eye0" = inside eye0, "eye" = direct child.
			if entry["vis_lib"] == "eye0":
				_node_zrak_normal = entry["node"]
				_zrak_home = _node_zrak_normal.position
			elif entry["vis_lib"] == "eye":
				_node_zrak_shocked = entry["node"]
		elif lib == "magic":
			if entry["node"] is Node2D or entry["node"] is Sprite2D:
				_node_magic = entry["node"]


func _set_mask_style(style: int) -> void:
	## Select the eyelid aperture mask of eye style `style` (Flash eye0 frame).
	_set_mask_frame(style)


func _apply_pero_rainbow() -> void:
	## Apply rainbow gradient shader to pero L2 element sprites and swap
	## texture to the shape mask. The shader generates the animated gradient
	## procedurally, matching Flash's 70-frame pero MovieClip animation.
	var shape_tex: Texture2D = _textures.get("pero_shape")
	if shape_tex == null:
		print_verbose("[player_rig] pero_shape texture not loaded — rainbow shader skipped")
		return
	var count := 0
	for entry: Dictionary in _nested:
		if entry["library"] != "pero":
			continue
		var pero_node: Node = entry["node"]
		for child in pero_node.get_children():
			if child is Sprite2D and child.name.begins_with("spr_L2"):
				if child.material is ShaderMaterial:
					(child.material as ShaderMaterial).shader = _shader_rainbow
				child.texture = shape_tex
				count += 1
	print_verbose("[player_rig] Rainbow shader applied to %d pero L2 sprites" % count)


# =============================================================================
# Tickers
# =============================================================================

func _setup_tickers() -> void:
	## Register the self-animating nested symbols (TICKER_TABLE). The body
	## timeline never keys their frames; Flash plays each MovieClip on its own.
	_tickers.clear()
	# konc sparkle: leaf sprites under rwing/lwing (7 per wing)
	var konc: Array = []
	for entry: Dictionary in _nested:
		if entry["library"] == "konc" and entry["bone_name"] in ["rwing", "lwing"] \
				and entry["node"] is Sprite2D:
			konc.append({"sprite": entry["node"], "kind": "leaf"})
	_add_ticker("konc", "konc", konc, TICKER_TABLE["konc"])
	# pegasus flap: the wing bones' own artwork sprites (layer 1, element 0)
	for wing: String in ["rwing", "lwing"]:
		var sprites: Array = []
		for es: Dictionary in _bone_element_sprites.get(wing, []):
			if es["lib"] == wing:
				sprites.append({"sprite": es["sprite"], "kind": "element",
						"layer": es["layer_index"], "element": es["element_index"]})
		_add_ticker(wing, wing, sprites, TICKER_TABLE[wing])
	# tail strands: one ticker per strand library (all share the table row)
	for lib: String in TAIL_STRAND_LIBS:
		var strands: Array = []
		for entry: Dictionary in _nested:
			if entry["library"] == lib and entry["node"] is Sprite2D:
				strands.append({"sprite": entry["node"], "kind": "leaf"})
		_add_ticker(lib, lib, strands, TICKER_TABLE["tail_strand"])
	# crystal shield (attachment "cryst", library crystal): two one-shots
	var cryst: Array = []
	for es: Dictionary in _bone_element_sprites.get("@cryst", []):
		if es["lib"] == "crystal":
			cryst.append({"sprite": es["sprite"], "kind": "element",
					"layer": es["layer_index"], "element": es["element_index"]})
	_add_ticker("crystal_up", "crystal", cryst, TICKER_TABLE["crystal_up"])
	_add_ticker("crystal_down", "crystal", cryst, TICKER_TABLE["crystal_down"])
	# magic shield (attachment "shit", library shit1): the ticker drives the
	# attachment node, whose only child shit10 follows the frame (no own art)
	var shield_row: Dictionary = TICKER_TABLE["shield"].duplicate()
	var shield_node: Node2D = _attachments.get("shit")
	if shield_node:
		shield_row["target"] = {"node": shield_node, "lib": "shit1", "entry": {}, "bone": "@shit"}
		_add_ticker("shield", "shit1", [], shield_row)
		_apply_ticker_frame(_ticker("shield"), 0)
	print_verbose("[player_rig] Tickers: %d (konc %d sprites, wings %d/%d, strands %d, crystal %d, shield %s)" % [
		_tickers.size(), konc.size(),
		_ticker("rwing")["sprites"].size(), _ticker("lwing")["sprites"].size(),
		TAIL_STRAND_LIBS.size(), cryst.size(), "yes" if shield_node else "no"])


func _update_ticker_activity() -> void:
	## Derive which tickers run from the rig state (Flash: otherVisual() and
	## the library switches decide which nested clips exist and play).
	var alicorn := _wings_enabled and _wing_alicorn
	_set_ticker_active("konc", alicorn)
	var flap := _wings_enabled and not _wing_alicorn and _wing_flapping
	_set_ticker_active("rwing", flap)
	_set_ticker_active("lwing", flap)
	var run_tail: bool = _strip_lib_prefix(_bone_lib.get("tail", "")) == "tail_run"
	for lib: String in TAIL_STRAND_LIBS:
		_set_ticker_active(lib, run_tail)


# =============================================================================
# Colour channels
# =============================================================================

func set_fur_color(c: Color) -> void:
	set_channel_color("trFur", c)


func set_hair_color(c: Color) -> void:
	set_channel_color("trHair", c)


func set_eye_color(c: Color) -> void:
	set_channel_color("trEye", c)


func set_magic_color(c: Color) -> void:
	set_channel_color("trMagic", c)


# =============================================================================
# Armor system
# =============================================================================

func set_armor(armor_id: String, hide_mane: int = -1) -> void:
	## Swap textures for all bones that have armor variants (Flash
	## Obj.setArmor: gotoAndStop(label) on every armour symbol).
	## hide_mane: Flash Obj.setVisible (Obj.as:174-179) hides the mane when
	## `h != 0`, h = pip.hideMane while the PipBuck preview is active, else
	## Appear.hideMane (the worn armour's AllData `hide`, UnitPlayer.as:2334).
	## -1 (the default: galleries, tests, Part B) keeps the rig's own rule —
	## the armour id in index.json `hide_mane_armors` (the AllData armours with
	## hide='1'); the UnitPlayer driver passes h (Step 16.1), which differs from
	## the id rule when the label is not the worn armour (World.alicorn shows
	## 'ali' with Appear.hideMane of the worn armour; armorWork; mmArmor).
	_apply_variant(armor_id)
	_mane_rule = hide_mane

	var hide: bool = armor_id in _hide_mane_armors if hide_mane < 0 else hide_mane != 0
	if _bones.has("mane"):
		_bones["mane"].visible = not hide

	# Re-apply eye state — _update_nested_visibility resets eye0/zrak to default (state 0)
	_apply_eye_state_visibility()


func get_armor_list() -> Array[String]:
	var armors: Array[String] = [""]
	# Collect unique armor labels from korpus (the main body part)
	var korpus: Dictionary = _body_parts.get("korpus", {})
	var labels: Dictionary = korpus.get("armor_labels", {})
	for idx: String in labels:
		var label: String = labels[idx]
		if label not in armors:
			armors.append(label)
	return armors


func set_transparent(enabled: bool) -> void:
	super.set_transparent(enabled)
	_apply_eye_state_visibility()


func set_hair1_visible(is_visible: bool) -> void:
	## Toggle the Hair1 (secondary hair colour) layer (Flash Appear.visHair1,
	## Obj.setColor channel 2 hides the instance when false).
	_vis_hair1 = is_visible
	_update_nested_visibility()
	_apply_eye_state_visibility()


# =============================================================================
# Eyes, face, hair, cutie mark
# =============================================================================

func set_eye_state(state: int) -> void:
	## Switch eye STATE (0=normal, 1=shocked, 2=closed, 3=alt-closed).
	## Controls eye container spr texture and child visibility.
	## Independent of eye STYLE (set_eye_style controls eye0 variant).
	## Step 16.5 (16.3 gap 2): back to frame 1 the eye shows a new `eye0`
	## instance, its pupil at the authored place (UnitPlayer.as:2925-2931 —
	## the jitter accumulates only while the eye stays open).
	if state == 0 and _eye_state != 0:
		_pupil_home()
	_eye_state = state
	# Swap eye container texture to match state (states 1-3 have artwork,
	# state 0 has none — eye0 provides the visuals instead)
	if _node_eye:
		# Every artwork layer of eye.xml keyed by the eye frame: L2 (state art
		# for frames 1-3) and the hidden-but-published L1 glare (frames 0-1).
		for child: Sprite2D in _container_artwork_sprites(_node_eye):
			var li := int(str(child.get_meta("artwork_layer")))
			var si := int(str(child.get_meta("element_index", 0)))
			var elem_list: Array = _get_element_svgs("eye", li).get(str(state), [])
			if si < elem_list.size():
				_apply_texture(child, str(elem_list[si]).replace(".svg", ""))
				child.visible = true
			else:
				child.texture = null
				child.visible = false
	_apply_eye_state_visibility()


func get_eye_state() -> int:
	## R3 #6 (Step 16.1): the eye state (0 normal = Flash `eye` frame 1, where
	## `eye.eye` exists; 1 shocked; 2 closed; 3 alt-closed). The pupil jitter
	## of UnitPlayer.as:2931 draws only when `eye.eye` exists: state 0.
	return _eye_state


func _apply_eye_state_visibility() -> void:
	## Set eye0/zrak-direct visibility based on current _eye_state.
	if _node_eye0:
		_node_eye0.visible = (_eye_state == 0)
	if _node_zrak_shocked:
		_node_zrak_shocked.visible = (_eye_state == 1)


func set_eye_style(style: int) -> void:
	## Switch eye STYLE variant (0-5). Controls eye0 nested sprite texture
	## and the corresponding mask texture for pupil clipping.
	## Independent of eye STATE (set_eye_state controls open/shocked/closed).
	_eye_style = style
	_swap_nested_texture("eye0", style)
	if not _masked_sprites.is_empty():
		_set_mask_style(style)


func set_face(frame: int) -> void:
	## Switch face/helmet variant (0-2). Controls morda0 nested sprite texture.
	_face_frame = frame
	_swap_nested_texture("morda0", frame)


func set_hair(frame: int) -> void:
	## Switch hairstyle variant (0-4). Controls all 10 hair bone textures/visibility.
	_hair_frame = frame
	# Simple texture swap bones (standing + running variants)
	for lib_name: String in ["haira0", "hairb0", "mane0", "mane1",
			"tail0", "tail1", "mane_run0", "mane_run1"]:
		_swap_nested_texture(lib_name, frame)
	# tail_runa/tail_runb use frame-based sub-child visibility (tail_runa0-4, tail_runb0-4)
	_set_sub_visibility("tail_runa", frame)
	_set_sub_visibility("tail_runb", frame)


func set_mark_visible(is_visible: bool, bone_name: String = "") -> void:
	## Show/hide the cutie mark (instance "mark" = library "quti") on the
	## hind-leg bones. Flash addresses one instance by name: the timeline
	## script `sleg1.mark.visible=false` targets the far leg (node sleg1_l)
	## only, so the method keys pass that bone; Stand.as:231 hides both.
	## bone_name == "" hides/shows every hind-leg mark. The state is kept so
	## armour changes and refreshes preserve it.
	for entry: Dictionary in _nested:
		if entry["library"] != "quti" or not entry["bone_name"].begins_with("sleg"):
			continue
		if bone_name != "" and entry["bone_name"] != bone_name:
			continue
		_mark_hidden[entry["bone_name"]] = not is_visible
		_refresh_nested_entry(entry)


# =============================================================================
# Root attachments (Flash: siblings of osn in visualLittlePip)
# =============================================================================

func set_rat_form(enabled: bool) -> void:
	## Rat form (Flash UnitPlayer.as:2488-2513): the pony body is hidden and
	## the root attachment `rat` shown.
	if _pre_ready(set_rat_form.bind(enabled)): return
	_rat_form = enabled
	_body.visible = not _rat_form
	_set_attachment_visible("rat", enabled)


func set_crystal_visible(is_visible: bool) -> void:
	## Shield crystal (Flash `vis.cryst`, UnitPlayer.as:887-897): show it on
	## its first frame; play_crystal() runs the rise / break timeline.
	_set_attachment_visible("cryst", is_visible)
	if is_visible:
		_set_ticker_active("crystal_down", false)
		_set_ticker_active("crystal_up", false)
		_apply_ticker_frame(_ticker("crystal_up"), 0)


func play_crystal(up: bool) -> void:
	## Flash crystal.xml (15 frames, stop() at 4 and 14): `gotoAndPlay(1)`
	## when the shield rises (frames 0..4, hold), `gotoAndPlay(10)` when it
	## breaks (frames 9..14, ending on the empty frame). UnitPlayer.as:888-891.
	_set_attachment_visible("cryst", true)
	_set_ticker_active("crystal_down" if up else "crystal_up", false)
	var t := _ticker("crystal_up" if up else "crystal_down")
	t["active"] = false
	_set_ticker_active(str(t["id"]), true)


func set_fetter(is_visible: bool, scale_x: float = 1.0, rotation_rad: float = 0.0) -> void:
	## Fetter beam (Flash `vis.fetter`, UnitPlayer.as:3054-3061:
	## scaleX = rfetter/100, rotation = atan2(dfy, dfx*storona)).
	var node: Node2D = _attachments.get("fetter")
	if node == null:
		return
	node.visible = is_visible
	node.scale.x = scale_x
	node.rotation = rotation_rad


func set_shield_visible(is_visible: bool) -> void:
	## Magic shield (Flash `vis.shit.visible`, UnitPlayer.as:197, 3044-3050;
	## hardlight, y -40 in visualLittlePip.xml).
	_set_attachment_visible("shit", is_visible)


func play_shield() -> void:
	## Flash `vis.shit.gotoAndPlay(1)` (UnitPlayer.as:3046): the 20-frame
	## shit1 timeline plays from frame 1 and holds its last frame (stop()).
	var t := _ticker("shield")
	if t.is_empty():
		return
	t["active"] = false
	_set_ticker_active("shield", true)


func stop_shield() -> void:
	## Flash `vis.shit.gotoAndStop(1)` (UnitPlayer.as:3050).
	var t := _ticker("shield")
	if t.is_empty():
		return
	t["active"] = false
	_apply_ticker_frame(t, 0)


func is_shield_visible() -> bool:
	var node: Node2D = _attachments.get("shit")
	return node != null and node.visible


func set_inhibitor_visible(is_visible: bool) -> void:
	## Magic inhibitor ring (Flash `vis.inh`, screen blend, x1.54).
	_set_attachment_visible("inh", is_visible)


func set_sky_light(is_visible: bool) -> void:
	## Sky flare (Flash `vis.svet.visible = loc.sky`, UnitPlayer.as:432).
	_set_attachment_visible("svet", is_visible)


# =============================================================================
# Wings
# =============================================================================

func set_wings_visible(enabled: bool) -> void:
	## Gate wing visibility (Flash: pers.ableFly).
	## When disabled, rwing/lwing are forced hidden after each animation frame.
	_wings_enabled = enabled
	if not enabled:
		var rw: Node2D = _bones.get("rwing")
		if rw:
			rw.visible = false
		var lw: Node2D = _bones.get("lwing")
		if lw:
			lw.visible = false
	_update_ticker_activity()


func set_wing_flapping(enabled: bool) -> void:
	## Pegasus flap (Flash otherVisual(): `rwing.gotoAndPlay(2)` while flying
	## and not alicorn, UnitPlayer.as:3033-3034): loop the wing symbols'
	## frames 1..8 at 30 fps; folded frame 0 otherwise (`gotoAndStop(1)`).
	_wing_flapping = enabled
	_update_ticker_activity()


func set_wing_alicorn(enabled: bool) -> void:
	## Switch between regular wing artwork and alicorn wing subtree.
	## Flash: UnitPlayer.visDetails() — rwing.gotoAndStop(11) for alicorn.
	_wing_alicorn = enabled
	# Toggle alicorn subtree nested entries (aliwing, wing1, wing2, pero, konc)
	for entry: Dictionary in _nested:
		if entry["bone_name"] not in ["rwing", "lwing"]:
			continue
		if entry["library"] in _ALICORN_WING_LIBS:
			entry["node"].visible = enabled
			# Apply frame_transforms when showing (pero needs correct pos/rot/scale)
			if not entry["frame_transforms"].is_empty():
				if enabled:
					_apply_nested_frame_transform(entry, 0)
				else:
					_reset_nested_transform(entry)
	# Toggle regular wing artwork sprites (opposite of alicorn).
	# Only hide the bone's OWN sprites (lib matches bone library), not sprites
	# inside nested containers (aliwing, wing2, pero) which have their own libs.
	for bone_name: String in ["rwing", "lwing"]:
		var own_lib: String = _bone_lib.get(bone_name, "")
		for es: Dictionary in _bone_element_sprites.get(bone_name, []):
			if es["lib"] == own_lib:
				es["sprite"].visible = not enabled
	_update_ticker_activity()


func set_wing_angles(right_rad: float, left_rad: float) -> void:
	## Alicorn wing spread (Flash otherVisual(), UnitPlayer.as:3028-3029):
	## `rwing.wing.wing2.rotation = 50 - |dx|*1.6`, `lwing... = 50 - |dx|*1.2`
	## degrees — both positive; the left wing's symbol is authored mirrored,
	## so no sign flip. The driver computes the two values.
	for pair in [["rwing", right_rad], ["lwing", left_rad]]:
		var bone: Node2D = _bones.get(pair[0])
		if bone:
			var wing2 := bone.find_child("wing2", true, false)
			if wing2:
				wing2.rotation = pair[1]


func set_wing_angle(rad: float) -> void:
	## Same spread on both wings.
	set_wing_angles(rad, rad)


# =============================================================================
# Runtime property animation
# =============================================================================
# These methods control per-frame behaviors that Flash handled via AS3 code:
# head rotation (head-tracking), hair spring physics, pupil jitter, magic glow,
# facing direction, eye blink cycle.

func set_head_rotation(rad: float) -> void:
	## Rotate head for head-tracking (Flash: morda.rotation).
	if _node_morda:
		_node_morda.rotation = rad


func set_hair_rotation(rad: float) -> void:
	## Rotate hair for spring physics (Flash: hair.rotation = hairR, tail.h0/h1.rotation = -hairR).
	if _node_hair:
		_node_hair.rotation = rad
	# Tail children rotate the opposite way (Flash: tail.h0, tail.h1). The
	# instances named h0/h1 are tail0/tail1 while the tail shows `tail`, and
	# tail_runa/tail_runb while it shows `tail_run` (UnitPlayer.as:2994-2997).
	var tail_lib := _strip_lib_prefix(_bone_lib.get("tail", ""))
	var names: Array = ["tail_runa", "tail_runb"] if tail_lib == "tail_run" else ["tail0", "tail1"]   # untyped: a ternary of two literals is an untyped Array (typed it raised at run time)
	var tail_bone: Node2D = _bones.get("tail")
	if tail_bone:
		for child_name in names:
			var child := tail_bone.find_child(child_name, true, false)
			if child:
				child.rotation = -rad


func set_pupil_offset(x: float, y: float) -> void:
	## Absolute pupil position in eye0 space (mask_clip has an identity
	## transform). Flash accumulates instead (see nudge_pupil).
	if _node_zrak_normal:
		_node_zrak_normal.position = Vector2(x, y)
		_recompute_mask_uv()


func _pupil_home() -> void:
	if _node_zrak_normal:
		_node_zrak_normal.position = _zrak_home
		_recompute_mask_uv()


## Step 16.5 (16.3 gap 2): a new osn frame re-creates `head.morda.eye` at frame
## 1 with a fresh `eye0` (Flash): the eye opens (state 0) and the pupil goes home
## before the new body's frame-1 script (which may close the eyes again).
func _rig_on_state_entered(_label: String) -> void:
	if _eye_state != 0:
		set_eye_state(0)
	_pupil_home()


## Step 16.5 (16.3 gap 3): Flash's `stop()` halts the body's playhead on its
## frame. The sections end on their stop frames (hold_last) except body_punch and
## body_kick, which run 1..20 past the `stop()` at 13 (the XFL frames 14..20 are
## never shown in Flash; 16.3's finding): reached while playing, that stop pauses
## the section. Limited to these two sources — elsewhere the section data already
## encodes the stops (lurk/levit navigation frames continue by design).
const STOP_PAUSE_SOURCES := ["body_punch", "body_kick"]

func _on_frame_stop(frame: int) -> void:
	super._on_frame_stop(frame)
	if _anim_player != null and _anim_player.is_playing():
		var a := _anim_player.assigned_animation
		if str(get_anim_meta(a).get("source", a)) in STOP_PAUSE_SOURCES and get_current_frame() > 0 				and get_current_frame() < get_anim_frame_count(a) - 1:
			pause_anim()


func nudge_pupil(dx: float, dy: float) -> void:
	## Flash pupil jitter (UnitPlayer.as:2931-2936): `zrak.x += rnd*8-4`
	## clamped to [-20, -11], `zrak.y += rnd*4-2` unclamped, when klip%10==3.
	if _node_zrak_normal:
		var p := _node_zrak_normal.position + Vector2(dx, dy)
		p.x = clampf(p.x, -20.0, -11.0)
		_node_zrak_normal.position = p
		_recompute_mask_uv()


func set_magic_intensity(alpha: float) -> void:
	## Set magic glow intensity (Flash: magic.alpha).
	if _node_magic:
		_node_magic.modulate.a = alpha


func set_facing_right(facing_right: bool) -> void:
	## Toggle PipBuck facing direction.
	## Actual sync (visibility + position from leg bone) runs in _process().
	_facing_right = facing_right


func _sync_pipbuck() -> void:
	## Copy PipBuck position/rotation from front leg every frame.
	## Flash: UnitPlayer.otherVisual() — pip1 follows frleg3, pip2 follows flleg3.
	var pip1: Node2D = _bones.get("pip1")
	var pip2: Node2D = _bones.get("pip2")
	if _facing_right:
		if pip1:
			pip1.visible = true
		if pip2:
			pip2.visible = false
		var frleg3: Node2D = _bones.get("frleg3")
		if pip1 and frleg3:
			pip1.position = frleg3.position
			pip1.rotation = frleg3.rotation
	else:
		if pip1:
			pip1.visible = false
		if pip2:
			pip2.visible = true
		var flleg3: Node2D = _bones.get("flleg3")
		if pip2 and flleg3:
			pip2.position = flleg3.position
			pip2.rotation = flleg3.rotation


func get_spell_origin() -> Vector2:
	## R3 #8 (Step 16.1): the spell/telekinesis origin `morda.konec` in the
	## rig's PARENT space (Flash UnitPlayer.as:2183-2185: konec (-54.4, -75.15)
	## in morda's space, `morda.localToGlobal`, `vis.parent.globalToLocal`) —
	## the room layer's space, the unit's X/Y frame. konec is the empty clip
	## "Символ 1" on morda's own timeline (Слой 7, all 16 frames): the same
	## point under every helmet. Computed through the local transforms morda →
	## … → osn → the rig root → the parent (no global-transform cache, valid off
	## the tree too). An unparented rig: Flash throws (vis.parent null) and the
	## driver takes the `catch` (magicX = X, magicY = Y − scY/2, :2191-2194);
	## this then returns the point in the space the rig's own transform maps to.
	var t := transform
	if _node_morda:
		var chain := Transform2D.IDENTITY
		var n: Node = _node_morda
		while n != null and n != self:
			if n is Node2D:
				chain = (n as Node2D).transform * chain
			n = n.get_parent()
		t = transform * chain
		return t * KONEC
	return position


func update_blink(klip: int, shock: bool, lurked: bool = false) -> void:
	## Eye blink state machine (Flash UnitPlayer.as:2922-2929): klip counts
	## down each frame; at 5 the eyes close, at 1 they reopen. shock = wide
	## pupil (zrak without the eye0 mask). lurked: Flash keeps the eyes open
	## every frame while hiding (`eye.gotoAndStop(1)`, :2641-2643).
	if lurked:
		if _eye_state != 0:
			set_eye_state(0)
		return
	if shock and _eye_state == 0:
		set_eye_state(1)          # normal → shocked
	if not shock and _eye_state == 1:
		set_eye_state(0)          # shocked → normal (un-shock)
	if klip == 1 and _eye_state != 0:
		set_eye_state(0)          # force normal on klip==1
	if klip == 5 and _eye_state == 0:
		set_eye_state(2)          # normal → blink
