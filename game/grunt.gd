# The sword grunt: the hero's cutout rig (its four views, sword in the right hand) in a
# darker tint, walking on a MotionGait, attacking with the hero's first
# swing after a held windup that telegraphs it (the blade glows), staggering
# back when hit, falling flat on a KO. A slimmer pose than the hero's: no
# look-at, chains or squash spring.
class_name Grunt
extends Enemy

const TINT := Color(0.66, 0.56, 0.86)
const SWING := preload("res://moves/swing_1.tres")
const TELEGRAPH := 0.42             # seconds the windup is held before the swing

var cut: MotionCutout
var gait: MotionGait
var _rest := {}
var _sword: MeshInstance3D
var _face := Vector3(0, 0, 1)


func _build_visual() -> void:
	max_hp = 4.0
	hp = max_hp
	speed = 2.1
	attack_range = 1.35
	hit_cue = &"hit.metal"
	cut = MotionCutout.new()
	cut.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(cut)
	var mat := look.flat.actor()       # one material for every part and view (no instance uniforms)
	for v: StringName in Hero.VIEWS:
		var rig := MotionCutoutRig.build(Hero.view_data(v), Hero.WIDTH * 0.95, mat, look.card_edges, {origin = Hero.ORIGIN})
		rig.set_tint(TINT)
		cut.add_view(v, rig, NAN, Hero.VIEW_STYLE[v].facing)
		_rest[v] = {
			torso = rig.parent_of[&"arm_r_upper"],
			hips = rig.rest_pivot(&"hips"), hand_r = rig.rest_pivot(&"hand_r"), hand_l = rig.rest_pivot(&"hand_l"),
			foot_l = rig.rest_pivot(&"foot_l"), foot_r = rig.rest_pivot(&"foot_r"),
			arm_len = (rig.rest_pivot(&"hand_r") - rig.rest_pivot(&"arm_r_upper")).length() * 0.98,
		}
	cut.lean(50.0, 20.0)
	gait = MotionGait.new(preload("res://game/hero_gait.tres"), 2)
	gait.planted.connect(func(_i: int, p: Vector3) -> void:
		var isl := get_tree().get_first_node_in_group(&"island")
		var surface: StringName = isl.surface_at(p) if isl else &"grass"
		GameEvents.emit(StringName("step." + String(surface)), p, 0.4, {source = self}))
	_sword = MotionCutoutRig.card(MotionSvgData.load_any(Hero.SWORD), 0.12, look.cutout, look.card_edges, Vector2(0.5, 136.0 / 160.0))
	MotionFlat3D.set_tint(_sword, Color(0.85, 0.8, 0.95))
	cut.view_changed.connect(_attach)
	_attach(cut.view, false)


func _attach(_view: StringName, _m: bool) -> void:
	var hand := cut.rig.part(&"hand_r")
	if _sword.get_parent():
		_sword.get_parent().remove_child(_sword)
	var z: float = (cut.rig.meshes[&"hand_r"] as MeshInstance3D).mesh.get_aabb().position.z
	_sword.position = Vector3(0, -0.012, z - 0.025)
	hand.add_child(_sword)


func _set_flash(a: float) -> void:
	cut.rig.set_flash(Color("#fff4d8"), a)


func _attack_update(_dt: float) -> bool:
	var f := (_state_t - TELEGRAPH) * 30.0
	hitbox.position = _face * 0.65 + Vector3(0, 0.5, 0)
	if f >= SWING.marker(&"active_from") and f <= SWING.marker(&"active_to"):
		_try_hit_hero(1.0)
	if _state_t < 0.05:
		GameEvents.emit(&"charge.full", global_position, 0.4, {source = self})   # a tell you can hear
	if absf(f - SWING.marker(&"active_from") + 1.0) < 0.6:
		GameEvents.emit(&"swing", global_position, 0.7, {source = self})
	return f >= SWING.length


func _attack_velocity() -> Vector3:
	if state != State.ATTACK:
		return Vector3.ZERO
	var f := (_state_t - TELEGRAPH) * 30.0
	return _face * (2.2 if f > 2.0 and f < 6.0 else 0.0)        # a step into the slash


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state in [State.APPROACH, State.ATTACK] and target:
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1 and (state == State.APPROACH or _state_t < TELEGRAPH):
			_face = to.normalized()
	gait.step(delta * clock.rate() if state != State.KO else 0.0, global_position, velocity, _face)


func _pose(dt: float) -> void:
	if state == State.KO:
		var k := clock.since(&"ko")
		cut.visible = k < 0.6
		cut.rotation = Vector3(-minf(k * 6.0, 1.45), 0, 0)      # falls flat
		return
	cut.visible = true
	cut.rotation = Vector3.ZERO
	cut.face(Vector2(_face.x, _face.z))
	cut.step(dt)
	var rig := cut.rig
	var rd: Dictionary = _rest[cut.view]
	var style: Dictionary = Hero.VIEW_STYLE[cut.view]
	var side: bool = style.side > 0.5
	var sx: float = style.sx
	var fx: float = style.fx
	rig.reset_pose()
	var frac := Engine.get_physics_interpolation_fraction()
	var body := get_global_transform_interpolated().origin
	rig.pose(&"hips", 0.0, Vector2(0, gait.body.y))
	var stagger := MotionSquash.land(clock.frames_since(&"hit"), -1.0) if state == State.STAGGER else 0.0
	var lean := -gait.body.x * fx * (1.0 if side else 0.0) + stagger * 0.35
	for p in [&"torso", &"chest"]:
		if rig.has_part(p):
			rig.pose(p, lean)
	var hips: Vector3 = rd.hips
	var feet := [rd.foot_l, rd.foot_r]
	var names := [[&"leg_l_upper", &"leg_l_lower", &"foot_l"], [&"leg_r_upper", &"leg_r_lower", &"foot_r"]]
	for i in 2:
		var m := cut.ground_to_card(gait.foot(i, frac) - body)
		var rf: Vector3 = feet[i]
		rig.solve_limb(names[i][0], names[i][1], names[i][2], Vector3(m.x, rf.y + m.y, 0), fx if side else signf(rf.x - hips.x))
	# sword arm: rest, the held windup, or the swing
	var w := 0.0
	var phi := 0.0
	if state == State.ATTACK:
		var f := maxf(0.0, (_state_t - TELEGRAPH) * 30.0)
		var hold := clampf(_state_t / 0.12, 0.0, 1.0)
		w = hold if _state_t < TELEGRAPH else float(SWING.sample(&"weight", f, cut.view))
		w = maxf(w, 1.0 if _state_t < TELEGRAPH else 0.0) * hold
		phi = SWING.sample_deg(&"arc", 2.6 if _state_t < TELEGRAPH else f, cut.view)
	var sh: Vector3 = rig.rig_transform(rd.torso) * (rig.rest[&"arm_r_upper"] as Transform3D).origin
	var hand_t: Vector3 = (rd.hand_r as Vector3).lerp(sh + Vector3(cos(phi) * sx, sin(phi), 0) * float(rd.arm_len), w)
	var elbow := signf((rd.hand_r as Vector3).x - hips.x) if not side else -fx
	rig.solve_limb(&"arm_r_upper", &"arm_r_lower", &"hand_r", hand_t, elbow if w < 0.5 else -elbow)
	if state == State.ATTACK and _state_t >= TELEGRAPH:
		var ad := float(SWING.sample(&"arm_depth", maxf(0.0, (_state_t - TELEGRAPH) * 30.0), cut.view))
		rig.depth(&"arm_r_upper", ad * rig.front_depth(&"arm_r_upper"))
	var rest := deg_to_rad(Hero.BLADE_REST_DEG)
	var blade := lerp_angle(atan2(sin(rest), cos(rest) * sx), atan2(sin(phi), cos(phi) * sx), w)
	var hx := rig.rig_transform(&"hand_r").basis.x
	_sword.rotation.z = blade - PI * 0.5 - atan2(hx.y, hx.x)
	var glow := 0.0
	if state == State.ATTACK and _state_t < TELEGRAPH:
		glow = 0.5 + 0.3 * sin(_state_t * TAU * 2.4)            # the tell: under 3 pulses a second
	MotionFlat3D.set_flash(_sword, Color("#ffd27a"), glow)
	var hl: Vector3 = rd.hand_l
	rig.solve_limb(&"arm_l_upper", &"arm_l_lower", &"hand_l", hl, signf(hl.x - hips.x) if not side else -fx)
