# The hero: 8-way analogue movement, a sword swing with a hitbox, and a
# cutout rig in three views (front, back, side) with a paper turn between
# them (MotionCutout / MotionCutoutRig from the motion kit).
# Procedural layers on the rig, in order (each switchable through Tune):
#   gait (MotionGait: planted feet in world space, stepping when the body
#   passes a stride; body dip, rise and lean) -> hips -> legs by IK to the
#   feet -> arms by IK (sword arm follows the swing arc, the other swings
#   against the legs) -> head look-at and eyes on springs, blinks.
# Time: everything reads `clock` (a MotionClock under the world clock), so a
# hit-stop on the hero freezes its pose, its smear and its movement.
class_name Hero
extends CharacterBody3D

signal hit_landed(target: Node, info: Dictionary)

const VIEWS := {&"front": "res://art/hero_front.svg", &"back": "res://art/hero_back.svg", &"side": "res://art/hero_side.svg"}
const SWORD := "res://art/sword.svg"
const WIDTH := 0.8                    # card width in metres (220 SVG units)
const ORIGIN := Vector2(110, 318)     # the feet, in SVG units

@export var speed := 4.2
@export var accel_damping := 16.0
@export var accel_stiffness := 140.0
## How far the cards lean back from vertical toward the camera (degrees).
@export var card_lean_deg := 20.0
## Swing timing in frames at 30 fps: windup, slash, settle, recover.
@export var swing_keys := PackedFloat64Array([0.0, 3.0, 6.0, 10.0, 18.0])
## The sword arm's angle around the shoulder at those keys (degrees, card
## plane, 0 = forward, 90 = up), drawn facing right.
@export var swing_arc := PackedFloat64Array([40.0, 135.0, -45.0, -58.0, -58.0])
## Frames of the swing when the hitbox is live.
@export var active_from := 3.0
@export var active_to := 7.0
## The walk: stride, step time, lift, body dip and lean.
@export var gait_settings: MotionGaitSettings = preload("res://game/hero_gait.tres")

var clock: MotionClock
var look: Look
var camera_pitch := 50.0
var aim := Vector3(1, 0, 0)       # last move direction, for the hitbox and facing
var look_target: Node3D

var cut: MotionCutout
var gait: MotionGait
var secondary: HeroSecondary
var _move := MotionSpring3D.new(Vector3.ZERO, 16.0, 140.0)
var _head_aim := MotionAimSpring.new(0.0, 11.0, 150.0)
var _eyes := MotionSpring2D.new(Vector2.ZERO, 14.0, 220.0)
var _sword: MeshInstance3D
var _smear: MeshInstance3D
var _smear_mat: StandardMaterial3D
var _shadow: MeshInstance3D
var _hitbox: Area3D
var _hit_this_swing := {}
var _rest := {}                   # view -> cached rest data
var _keys_a: Array = []           # swing_keys / swing_arc as plain Arrays for MK.interp
var _arc_a: Array = []
var _w_keys: Array = []
var _lunge_keys: Array = []


func setup(p_look: Look, world: MotionClock, pitch_deg: float) -> void:
	look = p_look
	clock = MotionClock.new(world)
	camera_pitch = pitch_deg
	_build()


func _build() -> void:
	collision_layer = 1 << 1
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.24
	cap.height = 0.9
	shape.shape = cap
	shape.position.y = 0.45
	add_child(shape)

	_shadow = look.ground_decal(look.blob_uv, Vector2(0.36, 0.22), Color(0.1, 0.12, 0.2, 0.55))
	_shadow.position.y = 0.01
	add_child(_shadow)

	cut = MotionCutout.new()
	cut.name = "Cutout"
	cut.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # posed in _process
	add_child(cut)
	for v: StringName in VIEWS:
		var rig := MotionCutoutRig.build(MotionSvgData.load_any(VIEWS[v]), WIDTH, look.cutout, look.card_edges, {origin = ORIGIN})
		rig.name = String(v)
		cut.add_view(v, rig)
		_rest[v] = _rest_data(rig)
	cut.lean(camera_pitch, card_lean_deg)
	gait = MotionGait.new(gait_settings, 2)
	gait.planted.connect(_on_planted)
	_keys_a = Array(swing_keys)
	_arc_a = Array(swing_arc)
	_w_keys = [0.0, 2.0, swing_keys[3], swing_keys[4]]
	_lunge_keys = [swing_keys[1], swing_keys[2], swing_keys[4]]

	# the sword: a card held in hand_r, moved to whichever view is showing
	_sword = Cutout.card(look, SWORD, 0.13, Vector2(0.5, 136.0 / 160.0))
	_smear = _build_smear()
	cut.view_changed.connect(_attach)
	_attach(cut.view, cut.mirrored)

	secondary = HeroSecondary.new()
	secondary.name = "Secondary"
	add_child(secondary)
	secondary.setup(self)

	_hitbox = Area3D.new()
	_hitbox.collision_layer = 1 << 3
	_hitbox.collision_mask = 1 << 4
	_hitbox.monitorable = false
	var hs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.6
	hs.shape = sph
	_hitbox.add_child(hs)
	add_child(_hitbox)


## What the pose code needs from a view, measured once.
func _rest_data(rig: MotionCutoutRig) -> Dictionary:
	var torso: StringName = rig.parent_of[&"arm_r_upper"]
	var d := {
		torso = torso,
		lean_parts = [&"torso", &"chest"].filter(func(n: StringName) -> bool: return rig.has_part(n)),
		hips = rig.rest_pivot(&"hips"),
		shoulder_r = rig.rest_pivot(&"arm_r_upper"),
		hand_r = rig.rest_pivot(&"hand_r"),
		hand_l = rig.rest_pivot(&"hand_l"),
		foot_l = rig.rest_pivot(&"foot_l"),
		foot_r = rig.rest_pivot(&"foot_r"),
	}
	d.arm_len = (d.hand_r - d.shoulder_r).length() * 0.98
	return d


## Move the sword and smear into the view that's showing.
func _attach(view: StringName, _mirrored: bool) -> void:
	var rig := cut.rig
	var hand := rig.part(&"hand_r")
	var hand_mesh: MeshInstance3D = rig.meshes[&"hand_r"]
	var z := hand_mesh.mesh.get_aabb().position.z      # just behind the hand: the fist covers the grip
	for n in [_sword, _smear]:
		if n.get_parent():
			n.get_parent().remove_child(n)
	_sword.position = Vector3(0, -0.012, z - 0.025)
	hand.add_child(_sword)
	var torso: Node3D = rig.part(_rest[view].torso)
	_smear.position = (_rest[view].shoulder_r as Vector3) - rig.rig_transform(_rest[view].torso).origin
	torso.add_child(_smear)


## A crescent for the slash frames: the sweep of the sword tip around the
## shoulder, in the card plane, drawn over everything.
func _build_smear() -> MeshInstance3D:
	var st := MotionFlat3D.begin()
	var seg := 20
	var r_out := 0.36
	for i in seg:
		var a0 := deg_to_rad(lerpf(swing_arc[1], swing_arc[2], float(i) / seg))
		var a1 := deg_to_rad(lerpf(swing_arc[1], swing_arc[2], float(i + 1) / seg))
		var w0 := sin(PI * float(i) / seg)          # thick in the middle
		var w1 := sin(PI * float(i + 1) / seg)
		var p0o := Vector3(cos(a0), sin(a0), 0) * r_out
		var p1o := Vector3(cos(a1), sin(a1), 0) * r_out
		MotionFlat3D.quad(st, p0o * (1.0 - 0.45 * w0), p1o * (1.0 - 0.45 * w1), p1o, p0o, Vector3.BACK, Vector2.ZERO, Color("#fffbe8"))
	_smear_mat = StandardMaterial3D.new()
	_smear_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smear_mat.vertex_color_use_as_albedo = true
	_smear_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smear_mat.no_depth_test = true
	_smear_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_smear_mat.render_priority = 1
	var mi := MotionFlat3D.instance(st.commit(), _smear_mat)
	mi.visible = false
	return mi


# ------------------------------------------------------------------ input and movement

func _physics_process(delta: float) -> void:
	var t := PerfProbe.begin()
	var r := clock.rate()                     # 0 during this hero's hit-stop
	var d := delta * r
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_move.damping = accel_damping
	_move.stiffness = accel_stiffness
	_move.target = Vector3(input.x, 0.0, input.y) * speed
	var v := _move.step(d)
	if input.length() > 0.2:
		aim = Vector3(input.x, 0.0, input.y).normalized()
	velocity = v * r                          # frozen in place while stopped
	if r > 0.0:
		move_and_slide()
		velocity /= r
		_move.value = Vector3(velocity.x, 0.0, velocity.z)
	_update_hitbox()
	var tg := PerfProbe.begin()
	gait.step(d, global_position, velocity, _face_dir())
	PerfProbe.end(&"gait", tg)
	PerfProbe.end(&"hero", t)
	secondary.physics(delta, r)


func _face_dir() -> Vector3:
	var swinging := clock.frames_since(&"swing") < swing_keys[4]
	return clock.last_data(&"swing").get("aim", aim) if swinging else aim


func _on_planted(_foot: int, pos: Vector3) -> void:
	var spd := Vector2(velocity.x, velocity.z).length() / speed
	GameEvents.emit(&"step.grass", pos, clampf(0.35 + spd * 0.65, 0.0, 1.0), {source = self})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		swing()


## Start a swing (ignored while one is still slashing).
func swing() -> void:
	if clock.frames_since(&"swing") < swing_keys[3]:
		return
	_hit_this_swing.clear()
	clock.mark(&"swing", {aim = aim})
	GameEvents.emit(&"swing", global_position, 1.0, {source = self})


func _update_hitbox() -> void:
	var f := clock.frames_since(&"swing")
	_hitbox.position = aim * 0.62 + Vector3(0, 0.5, 0)
	if f < active_from or f > active_to:
		return
	for area in _hitbox.get_overlapping_areas():
		var target := area.get_parent() as Node3D
		if target == null or _hit_this_swing.has(target) or not target.has_method(&"take_hit"):
			continue
		_hit_this_swing[target] = true
		var dir: Vector3 = target.global_position - global_position
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.01 else aim
		var info := {dir = dir, power = 1.0, attacker = self, point = target.global_position + Vector3(0, 0.6, 0)}
		target.take_hit(info)
		hit_landed.emit(target, info)


# ------------------------------------------------------------------ pose (render rate)

func _process(delta: float) -> void:
	var t := PerfProbe.begin()
	clock.tick(delta)
	var dt := clock.dt
	var tune := Tune.get_or_default()

	# facing: the swing's aim while slashing, else where we move
	var f := clock.frames_since(&"swing")
	var swinging := f < swing_keys[4]
	var face_dir := _face_dir()
	cut.paper_turn = tune.paper_turn
	cut.face(Vector2(face_dir.x, face_dir.z))
	cut.lean(camera_pitch, card_lean_deg)
	cut.step(dt)

	var rig := cut.rig
	var rd: Dictionary = _rest[cut.view]
	var side := cut.view == &"side"
	var sx := -1.0 if cut.view == &"back" else 1.0     # back view: the sword arm is on screen left
	rig.reset_pose()

	# gait: world feet and body springs, read between physics steps
	var frac := Engine.get_physics_interpolation_fraction()
	var body_pos := get_global_transform_interpolated().origin
	var gb := gait.body if tune.bob else Vector3.ZERO
	var spd := Vector2(velocity.x, velocity.z).length()
	var breathe := sin(clock.time * TAU * 0.45) * (1.0 - clampf(spd / speed, 0.0, 1.0))
	var bob := gb.y + breathe * 0.002
	rig.pose(&"hips", 0.0, Vector2(0, bob))
	var fdir := Vector3(face_dir.x, 0, face_dir.z).normalized()
	var across := Vector3(-fdir.z, 0, fdir.x)
	var lean_world := fdir * gb.x + across * gb.z
	var mirror := -1.0 if cut.mirrored else 1.0
	for p: StringName in rd.lean_parts:
		rig.pose(p, -lean_world.x * mirror)

	# legs: IK to the planted / stepping feet
	var hips: Vector3 = rd.hips
	var feet := [rd.foot_l, rd.foot_r]
	var targets := []
	for i in 2:
		var off := gait.foot(i, frac) - body_pos
		var m := cut.ground_to_card(off)
		var rest_f: Vector3 = feet[i]
		targets.append(Vector3(m.x, rest_f.y + m.y, 0.0))
	rig.solve_limb(&"leg_l_upper", &"leg_l_lower", &"foot_l", targets[0], 1.0 if side else signf((rd.foot_l as Vector3).x - hips.x))
	rig.solve_limb(&"leg_r_upper", &"leg_r_lower", &"foot_r", targets[1], 1.0 if side else signf((rd.foot_r as Vector3).x - hips.x))

	# sword arm: rest by the side, or around the shoulder along the swing arc
	var w := MK.interp(f, _w_keys, [0.0, 1.0, 1.0, 0.0], MK.ease_in_out) if swinging else 0.0
	var phi := deg_to_rad(MK.interp(f, _keys_a, _arc_a, MK.ease_out)) if swinging else 0.0
	var sh: Vector3 = rig.rig_transform(rd.torso) * (rig.rest[&"arm_r_upper"] as Transform3D).origin
	var arc_hand := sh + Vector3(cos(phi) * sx, sin(phi), 0) * (rd.arm_len as float)
	var hand_rest: Vector3 = rd.hand_r + Vector3(0, bob, 0)
	var hand_t := hand_rest.lerp(arc_hand, w)
	var elbow_out := signf((rd.hand_r as Vector3).x - hips.x) if not side else -1.0
	rig.solve_limb(&"arm_r_upper", &"arm_r_lower", &"hand_r", hand_t, elbow_out if w < 0.5 else -elbow_out)
	var blade_rest := atan2(sin(deg_to_rad(-62.0)), cos(deg_to_rad(-62.0)) * sx)    # lowered, tip forward
	var blade_arc := atan2(sin(phi), cos(phi) * sx)
	var blade := lerp_angle(blade_rest, blade_arc, w)
	var hand_rot := rig.rig_transform(&"hand_r").basis.x
	_sword.rotation.z = blade - PI * 0.5 - atan2(hand_rot.y, hand_rot.x)

	# other arm: hangs and swings against the legs
	var swing_x := ((targets[1] as Vector3).x - (rd.foot_r as Vector3).x) * (0.7 if side else 0.2)
	var hl: Vector3 = rd.hand_l + Vector3(swing_x, bob, 0)
	rig.solve_limb(&"arm_l_upper", &"arm_l_lower", &"hand_l", hl, signf((rd.hand_l as Vector3).x - hips.x) if not side else -1.0)

	# head: look at the target with lag, eyes lead, blinks keep the hold alive
	var look_dir := Vector2.ZERO
	if look_target and is_instance_valid(look_target):
		var to := look_target.global_position - global_position
		if to.length() < 5.0:
			look_dir = Vector2(to.x, to.z).normalized()
	_head_aim.limit_min = deg_to_rad(-9.0)
	_head_aim.limit_max = deg_to_rad(9.0)
	_head_aim.target = -look_dir.x * mirror * deg_to_rad(7.0) * (0.0 if side else 1.0) - lean_world.x * mirror * 0.5
	rig.pose(&"head", _head_aim.step(dt))
	_eyes.target = Vector2(look_dir.x * mirror * (0.6 if side else 1.0), -look_dir.y * 0.5) * 0.012
	var eo := _eyes.step(dt)
	if rig.has_part(&"eyes"):
		var blink := 1.0 - 0.9 * MK.win(fmod(clock.time, 3.7) * 30.0, 0.0, 4.0, 1.5)
		rig.pose(&"eyes", 0.0, eo, Vector2(1.0, blink))

	# smear and lunge
	var smear_on := tune.smear and f >= swing_keys[1] and f < swing_keys[3] + 2.0
	_smear.visible = smear_on
	if smear_on:
		_smear.scale = Vector3(sx, 1, 1)
		_smear_mat.albedo_color = Color(1, 1, 1, 0.85 * (1.0 - MK.prog(f, swing_keys[2], 6.0)))
	var lunge := MK.interp(f, _lunge_keys, [0.0, 1.0, 0.0], MK.ease_out) if swinging else 0.0
	cut.position = face_dir * 0.08 * lunge
	PerfProbe.end(&"hero.pose", t)
	secondary.render(frac, f, swing_keys, clampf(spd / speed, 0.0, 1.0))
