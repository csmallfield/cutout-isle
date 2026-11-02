# The hero: 8-way analogue movement, a sword swing with a hitbox, and a
# cutout rig in four views with a paper turn between them (MotionCutout /
# MotionCutoutRig from the motion kit). Nothing is plainly mirrored, so the
# sword stays in the right hand: front and back are drawn right-handed and
# never flip, and facing left uses the side drawing mirrored with left and
# right parts swapped (MotionSvgData.mirrored), which makes the sword arm
# the far arm, behind the body.
# Procedural layers on the rig, in order (each switchable through Tune):
#   gait (MotionGait: planted feet in world space, stepping when the body
#   passes a stride; body dip, rise and lean) -> hips -> legs by IK to the
#   feet -> arms by IK (sword arm follows the move's arc, the other swings
#   against the legs) -> head look-at and eyes on springs, blinks.
# Attacks are authored MotionPoseCurve resources (moves/): a 3-hit combo
# (press again from a move's "buffer" frame, it chains at "cancel") and a
# charged swing (hold through a swing, release when charged). Each move
# has channels per view (arc.front, arc.back) and its own power and reach.
# Time: everything reads `clock` (a MotionClock under the world clock), so a
# hit-stop on the hero freezes its pose, its smear and its movement.
class_name Hero
extends CharacterBody3D

signal hit_landed(target: Node, info: Dictionary)

const VIEWS := {&"front": "res://art/hero_front.svg", &"back": "res://art/hero_back.svg",
	&"side": "res://art/hero_side.svg", &"side_left": "res://art/hero_side.svg"}
## How each view poses and turns:
##   facing  MotionCutout side: EITHER never flips, RIGHT / LEFT one way only
##   side    0 straight on, 1 side on (legs bend forward, the head turns less)
##   fx      which way a side view faces on the card (+1 right, -1 left)
##   sx      -1 where the sword arm's arcs mirror on the card
##   behind  the sword arm is behind the body (the smear goes behind it too)
## side_left is the side drawing mirrored with left and right swapped
## (view_data); its moves use the side arcs mirrored (sx -1).
const VIEW_STYLE := {
	&"front": {facing = MotionCutout.EITHER, side = 0.0, fx = 1.0, sx = -1.0, behind = false},
	&"back": {facing = MotionCutout.EITHER, side = 0.0, fx = 1.0, sx = 1.0, behind = true},
	&"side": {facing = MotionCutout.RIGHT, side = 1.0, fx = 1.0, sx = 1.0, behind = false},
	&"side_left": {facing = MotionCutout.LEFT, side = 1.0, fx = -1.0, sx = -1.0, behind = true},
}
const SWORD := "res://art/sword.svg"
const WIDTH := 0.8                    # card width in metres (220 SVG units)
const ORIGIN := Vector2(110, 318)     # the feet, in SVG units

@export var speed := 4.2
@export var accel_damping := 16.0
@export var accel_stiffness := 140.0
## How far the cards lean back from vertical toward the camera (degrees).
@export var card_lean_deg := 20.0
## The combo, in order, and the charged swing.
@export var combo: Array[MotionPoseCurve] = [preload("res://moves/swing_1.tres"), preload("res://moves/swing_2.tres"), preload("res://moves/swing_3.tres")]
@export var charge_move: MotionPoseCurve = preload("res://moves/swing_charge.tres")
## Seconds of holding to charge, and how fast the hero walks while charging.
@export var charge_time := 0.55
@export var charge_speed_scale := 0.35
## Dash: speed, how long it lasts, and the wait before the next one.
@export var dash_speed := 11.0
@export var dash_time := 0.16
@export var dash_cooldown := 0.45
@export var max_hp := 5
## The walk: stride, step time, lift, body dip and lean.
@export var gait_settings: MotionGaitSettings = preload("res://game/hero_gait.tres")

var clock: MotionClock
var look: Look
var camera_pitch := 50.0
var aim := Vector3(1, 0, 0)       # last move direction, for the hitbox and facing
var look_target: Node3D
var island: Node                  # for the ground surface under the feet
var hp := 5

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
var _queued := false              # the next combo hit is buffered
var _charging := false
var _charge_t := 0.0
var _smear_key := ""              # which move / view the smear mesh was built for
var _dash_dir := Vector3.ZERO
var _knock := Vector3.ZERO
var _spawn := Vector3.ZERO
## Seconds of invulnerability after being hit.
var invulnerable_time := 0.9


func setup(p_look: Look, world: MotionClock, pitch_deg: float) -> void:
	add_to_group(&"hero")
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
	var mat := look.flat.actor()       # one material for every part and view (no instance uniforms)
	for v: StringName in VIEWS:
		var rig := MotionCutoutRig.build(view_data(v), WIDTH, mat, look.card_edges, {origin = ORIGIN})
		rig.name = String(v)
		cut.add_view(v, rig, NAN, VIEW_STYLE[v].facing)
		_rest[v] = _rest_data(rig)
	cut.lean(camera_pitch, card_lean_deg)
	gait = MotionGait.new(gait_settings, 2)
	gait.planted.connect(_on_planted)

	# the sword: a card held in hand_r, moved to whichever view is showing
	_sword = MotionCutoutRig.card(MotionSvgData.load_any(SWORD), 0.13, look.cutout, look.card_edges, Vector2(0.5, 136.0 / 160.0))
	_smear = _build_smear()
	cut.view_changed.connect(_attach)
	_attach(cut.view, cut.mirrored)

	secondary = HeroSecondary.new()
	secondary.name = "Secondary"
	add_child(secondary)
	secondary.setup(self)

	var hurt := Area3D.new()
	hurt.name = "Hurtbox"
	hurt.collision_layer = 1 << 6
	hurt.collision_mask = 0
	hurt.monitoring = false
	var hcs := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 0.28
	hcap.height = 1.0
	hcs.shape = hcap
	hcs.position.y = 0.5
	hurt.add_child(hcs)
	add_child(hurt)

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


static var _data := {}


## The drawing for a view: side_left is the side drawing mirrored about the
## feet with left and right parts swapped (the partial mirror).
static func view_data(v: StringName) -> MotionSvgData:
	if not _data.has(v):
		var d := MotionSvgData.load_any(VIEWS[v])
		_data[v] = d.mirrored(ORIGIN.x) if v == &"side_left" else d
	return _data[v]


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
	var head_z: float = (rig.meshes[&"head"] as MeshInstance3D).mesh.get_aabb().position.z if rig.meshes.has(&"head") else 0.1
	var arm_z: float = (rig.meshes[&"arm_r_upper"] as MeshInstance3D).mesh.get_aabb().position.z if rig.meshes.has(&"arm_r_upper") else 0.0
	var p: Vector3 = (_rest[view].shoulder_r as Vector3) - rig.rig_transform(_rest[view].torso).origin
	# in the body's stack: behind the head, or behind the body with an arm that is
	var smear_z := arm_z - 0.003 if VIEW_STYLE[view].behind else head_z - 0.003
	_smear.position = Vector3(p.x, p.y, smear_z)
	torso.add_child(_smear)
	_smear_key = ""


## The smear: an empty mesh rebuilt per move and view (_rebuild_smear), with
## a depth-tested alpha material, so it sits behind the head and over the
## torso instead of across the face.
func _build_smear() -> MeshInstance3D:
	_smear_mat = StandardMaterial3D.new()
	_smear_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smear_mat.vertex_color_use_as_albedo = true
	_smear_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smear_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.material_override = _smear_mat
	mi.visible = false
	return mi


## A crescent along the move's arc over its active frames (shoulder space).
func _rebuild_smear(move: MotionPoseCurve, view: StringName, sx: float) -> void:
	var key := "%s|%s" % [move.resource_path, view]
	if key == _smear_key:
		return
	_smear_key = key
	var a_from := float(move.sample(&"arc", move.marker(&"active_from") - 1.0, view))
	var a_to := float(move.sample(&"arc", move.marker(&"active_to"), view))
	var st := MotionFlat3D.begin()
	var seg := 22
	var r_out := float(_rest[view].arm_len) + 0.17
	for i in seg:
		var a0 := deg_to_rad(lerpf(a_from, a_to, float(i) / seg))
		var a1 := deg_to_rad(lerpf(a_from, a_to, float(i + 1) / seg))
		var w0 := sin(PI * float(i) / seg)          # thick in the middle
		var w1 := sin(PI * float(i + 1) / seg)
		var p0o := Vector3(cos(a0) * sx, sin(a0), 0) * r_out
		var p1o := Vector3(cos(a1) * sx, sin(a1), 0) * r_out
		MotionFlat3D.quad(st, p0o * (1.0 - 0.5 * w0), p1o * (1.0 - 0.5 * w1), p1o, p0o, Vector3.BACK, Vector2.ZERO, Color("#fffbe8"))
	_smear.mesh = st.commit()


# ------------------------------------------------------------------ input and movement

func _physics_process(delta: float) -> void:
	var t := MotionPerfProbe.begin()
	var r := clock.rate()                     # 0 during this hero's hit-stop
	var d := delta * r
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_move.damping = accel_damping
	_move.stiffness = accel_stiffness
	_move.target = Vector3(input.x, 0.0, input.y) * speed * (charge_speed_scale if _charging else 1.0)
	var v := _move.step(d)
	if input.length() > 0.2:
		aim = Vector3(input.x, 0.0, input.y).normalized()
	if clock.since(&"dash") < dash_time:
		var u := clock.since(&"dash") / dash_time
		v = _dash_dir * dash_speed * (1.0 - u * u * 0.6)      # a burst that eases off at the end
		_move.value = v
	_knock = _knock.lerp(Vector3.ZERO, 1.0 - exp(-d * 8.0))
	if hp <= 0:
		v = Vector3.ZERO
	velocity = (v + _knock) * r                # frozen in place while stopped
	if r > 0.0:
		move_and_slide()
		velocity /= r
		_move.value = Vector3(velocity.x, 0.0, velocity.z)
	_update_hitbox()
	var tg := MotionPerfProbe.begin()
	gait.step(d, global_position, velocity, _face_dir())
	MotionPerfProbe.end(&"gait", tg)
	MotionPerfProbe.end(&"hero", t)
	secondary.physics(delta, r)


func _face_dir() -> Vector3:
	return clock.last_data(&"swing").get("aim", aim) if current_move() else aim


## The move playing now (null when none), and frames into it.
func current_move() -> MotionPoseCurve:
	var m: MotionPoseCurve = clock.last_data(&"swing").get("move")
	return m if m and move_frame() < m.length else null


func move_frame() -> float:
	return clock.frames_since(&"swing") + float(clock.last_data(&"swing").get("start", 0.0))


func _on_planted(_foot: int, pos: Vector3) -> void:
	var spd := Vector2(velocity.x, velocity.z).length() / speed
	var surface: StringName = island.surface_at(pos) if island and island.has_method(&"surface_at") else &"grass"
	GameEvents.emit(StringName("step." + String(surface)), pos, clampf(0.35 + spd * 0.65, 0.0, 1.0), {source = self, surface = surface})


## Look at the nearest enemy (or the dummy) within reach.
func _pick_look_target() -> void:
	var best: Node3D = null
	var bd := 5.0
	for n in get_tree().get_nodes_in_group(&"lookable"):
		var e := n as Node3D
		if e == null or (e.has_method(&"is_alive") and not e.is_alive()):
			continue
		var d := e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	look_target = best


## 0..1 while charging (the riser's pitch and level follow it).
func charge_ratio() -> float:
	return clampf(_charge_t / charge_time, 0.0, 1.0) if _charging else 0.0


## Lose `n` hit points (F5 / F6 in the overlay test it without enemies).
func damage(n := 1) -> void:
	hp = clampi(hp - n, 0, max_hp)
	GameEvents.emit(&"hero.hurt", global_position, 1.0, {source = self})
	if hp == 0:
		clock.mark(&"down")


func heal(n := 1) -> void:
	hp = clampi(hp + n, 0, max_hp)
	GameEvents.emit(&"hero.heal", global_position, 1.0, {source = self})


## Hit by an enemy: info = {dir, power, attacker}. Knockback, a short
## hit-stop on both (Juice), a blinking spell of invulnerability.
func take_damage(info: Dictionary) -> bool:
	if hp <= 0 or clock.since(&"hurt") < invulnerable_time:
		return false
	var dir: Vector3 = info.get("dir", Vector3.BACK)
	clock.mark(&"hurt", info)
	_knock = dir * 5.5
	_charging = false
	if current_move():
		clock.mark(&"swing", {})
	damage(1)
	GameEvents.emit(&"hit.flesh", global_position + Vector3(0, 0.6, 0), 0.9, {target = self, dir = dir, attacker = info.get("attacker")})
	return true


func is_down() -> bool:
	return hp <= 0


func _unhandled_input(event: InputEvent) -> void:
	if hp <= 0:
		return
	if event.is_action_pressed(&"attack"):
		attack()
	elif event.is_action_pressed(&"dash"):
		dash()
	elif event.is_action_released(&"attack") and _charging:
		_release_charge()


## Let go of a charge: the charged swing if it was full, else nothing.
func _release_charge() -> void:
	_charging = false
	if _charge_t >= charge_time:
		_start(charge_move, -1, charge_move.marker(&"hold", 0.0))
	_charge_t = 0.0


## A short burst along the stick (or the facing). Cancels a swing after its
## active frames, not during them.
func dash() -> void:
	if clock.since(&"dash") < dash_cooldown:
		return
	var m := current_move()
	if m and move_frame() < m.marker(&"active_to", 0.0):
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_dash_dir = Vector3(input.x, 0, input.y).normalized() if input.length() > 0.2 else _face_dir()
	aim = _dash_dir
	if m:
		clock.mark(&"swing", {})                  # end the move
	_charging = false
	clock.mark(&"dash", {dir = _dash_dir})
	secondary.squash.impulse(3.0)
	GameEvents.emit(&"dash", global_position, 1.0, {source = self})


## Attack pressed: start the combo, or buffer its next hit.
func attack() -> void:
	var m := current_move()
	if m == null:
		_start(combo[0], 0)
		return
	var step: int = clock.last_data(&"swing").get("step", -1)
	if step >= 0 and step < combo.size() - 1 and move_frame() >= m.marker(&"buffer", 0.0):
		_queued = true


func _start(move: MotionPoseCurve, step: int, start := 0.0) -> void:
	_queued = false
	_hit_this_swing.clear()
	clock.mark(&"swing", {aim = aim, move = move, step = step, start = start})
	GameEvents.emit(&"swing.charge" if step < 0 else &"swing", global_position, float(move.data.get("intensity", 1.0)), {source = self, step = step})


## Combo chaining and charging, once per rendered frame.
func _update_moves(dt: float) -> void:
	var m: MotionPoseCurve = clock.last_data(&"swing").get("move")
	var f := move_frame()
	var step: int = clock.last_data(&"swing").get("step", -1)
	if m and _queued and f >= m.marker(&"cancel", INF):
		_start(combo[step + 1], step + 1)
		return
	var done := m == null or f >= m.length
	var held := Input.is_action_pressed(&"attack")
	# holding through the end of a swing starts a charge
	if not _charging and held and m and step >= 0 and f >= m.marker(&"cancel", m.length) and not _queued:
		_charging = true
		_charge_t = 0.0
	if _charging:
		if not held:
			_release_charge()
			return
		else:
			var was := _charge_t
			_charge_t += dt
			if was < charge_time and _charge_t >= charge_time:
				GameEvents.emit(&"charge.full", global_position, 1.0, {source = self})
	if done and not _charging:
		_queued = false


func _update_hitbox() -> void:
	var m := current_move()
	var reach := float(m.data.get("reach", 0.62)) if m else 0.62
	_hitbox.position = _face_dir() * reach + Vector3(0, 0.5, 0)
	if m == null or not m.between(move_frame(), &"active_from", &"active_to"):
		return
	for area in _hitbox.get_overlapping_areas():
		var target := area.get_parent() as Node3D
		if target == null or _hit_this_swing.has(target) or not target.has_method(&"take_hit"):
			continue
		_hit_this_swing[target] = true
		var dir: Vector3 = target.global_position - global_position
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.01 else aim
		var info := {dir = dir, power = float(m.data.get("power", 1.0)), attacker = self, move = m,
			point = target.global_position + Vector3(0, 0.6, 0) - dir * 0.25}
		target.take_hit(info)
		hit_landed.emit(target, info)


# ------------------------------------------------------------------ pose (render rate)

func _process(delta: float) -> void:
	var t := MotionPerfProbe.begin()
	clock.tick(delta)
	var dt := clock.dt
	var tune := Tune.get_or_default()

	if hp <= 0 and clock.since(&"down") > 2.2:
		hp = max_hp
		global_position = _spawn
		reset_physics_interpolation()
		GameEvents.emit(&"hero.heal", global_position, 1.0, {source = self})
	_pick_look_target()
	# moves first (a chained hit starts this frame), then facing
	_update_moves(dt)
	var move := current_move()
	var f := move_frame()
	var face_dir := _face_dir()
	cut.paper_turn = tune.paper_turn
	cut.face(Vector2(face_dir.x, face_dir.z))
	cut.lean(camera_pitch, card_lean_deg)
	cut.step(dt)

	var rig := cut.rig
	var rd: Dictionary = _rest[cut.view]
	var style: Dictionary = VIEW_STYLE[cut.view]
	var sideness: float = style.side
	var side := sideness > 0.5
	var sx: float = style.sx     # arcs mirror on the card where the drawing does
	var fx: float = style.fx     # a side view facing right (+1) or left (-1)
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
	var view := cut.view
	var torso_deg := float(move.sample(&"torso", f, view)) if move else (6.0 if _charging else 0.0)
	for p: StringName in rd.lean_parts:
		rig.pose(p, -lean_world.x * mirror + deg_to_rad(torso_deg) * sx)

	# legs: IK to the planted / stepping feet
	var hips: Vector3 = rd.hips
	var feet := [rd.foot_l, rd.foot_r]
	var targets := []
	for i in 2:
		var off := gait.foot(i, frac) - body_pos
		var m := cut.ground_to_card(off)
		var rest_f: Vector3 = feet[i]
		targets.append(Vector3(m.x, rest_f.y + m.y, 0.0))
	rig.solve_limb(&"leg_l_upper", &"leg_l_lower", &"foot_l", targets[0], fx if side else signf((rd.foot_l as Vector3).x - hips.x))
	rig.solve_limb(&"leg_r_upper", &"leg_r_lower", &"foot_r", targets[1], fx if side else signf((rd.foot_r as Vector3).x - hips.x))

	# sword arm: rest by the side, around the shoulder along the move's arc,
	# or held back while charging
	var w := 0.0
	var phi := 0.0
	var blade_off := 0.0
	if move:
		w = float(move.sample(&"weight", f, view))
		phi = move.sample_deg(&"arc", f, view)
		blade_off = move.sample_deg(&"blade", f, view)
	elif _charging:
		var hold := charge_move.marker(&"hold", 0.0)
		w = clampf(_charge_t / 0.12, 0.0, 1.0)
		phi = charge_move.sample_deg(&"arc", hold, view)
	var sh: Vector3 = rig.rig_transform(rd.torso) * (rig.rest[&"arm_r_upper"] as Transform3D).origin
	var arc_hand := sh + Vector3(cos(phi) * sx, sin(phi), 0) * (rd.arm_len as float)
	var hand_rest: Vector3 = rd.hand_r + Vector3(0, bob, 0)
	var hand_t := hand_rest.lerp(arc_hand, w)
	var elbow_out := signf((rd.hand_r as Vector3).x - hips.x) if not side else -fx
	rig.solve_limb(&"arm_r_upper", &"arm_r_lower", &"hand_r", hand_t, elbow_out if w < 0.5 else -elbow_out)
	var blade_rest := atan2(sin(deg_to_rad(-62.0)), cos(deg_to_rad(-62.0)) * sx)    # lowered, tip forward
	var blade_arc := atan2(sin(phi + blade_off), cos(phi + blade_off) * sx)
	var blade := lerp_angle(blade_rest, blade_arc, w)
	var hand_rot := rig.rig_transform(&"hand_r").basis.x
	_sword.rotation.z = blade - PI * 0.5 - atan2(hand_rot.y, hand_rot.x)
	# charge glow on the blade: a small, slow pulse (photosensitivity: under 3 a second)
	var glow := 0.0
	if _charging:
		var full := _charge_t >= charge_time
		glow = (0.35 + 0.35 * sin(clock.time * TAU * (2.5 if full else 1.2))) * clampf(_charge_t / charge_time, 0.0, 1.0)
	MotionFlat3D.set_flash(_sword, Color("#ffe9a8"), glow)

	# other arm: hangs and swings against the legs
	var swing_x := ((targets[1] as Vector3).x - (rd.foot_r as Vector3).x) * lerpf(0.2, 0.7, sideness)
	var hl: Vector3 = rd.hand_l + Vector3(swing_x, bob, 0)
	rig.solve_limb(&"arm_l_upper", &"arm_l_lower", &"hand_l", hl, signf((rd.hand_l as Vector3).x - hips.x) if not side else -fx)

	# head: look at the target with lag, eyes lead, blinks keep the hold alive
	var look_dir := Vector2.ZERO
	if look_target and is_instance_valid(look_target):
		var to := look_target.global_position - global_position
		if to.length() < 5.0:
			look_dir = Vector2(to.x, to.z).normalized()
	_head_aim.limit_min = deg_to_rad(-9.0)
	_head_aim.limit_max = deg_to_rad(9.0)
	_head_aim.target = -look_dir.x * mirror * deg_to_rad(7.0) * (1.0 - sideness) - lean_world.x * mirror * 0.5
	var head_deg := float(move.sample(&"head", f, view)) if move else 0.0
	rig.pose(&"head", _head_aim.step(dt) + deg_to_rad(head_deg) * sx)
	_eyes.target = Vector2(look_dir.x * mirror * lerpf(1.0, 0.6, sideness), -look_dir.y * 0.5) * 0.012
	var eo := _eyes.step(dt)
	if rig.has_part(&"eyes"):
		var blink := 1.0 - 0.9 * MK.win(fmod(clock.time, 3.7) * 30.0, 0.0, 4.0, 1.5)
		rig.pose(&"eyes", 0.0, eo, Vector2(1.0, blink))

	# smear over the active frames, lunge
	var smear_on := false
	if move and tune.smear:
		var a0 := move.marker(&"active_from") - 1.0
		var a1 := move.marker(&"active_to") + 3.0
		smear_on = f >= a0 and f < a1
		if smear_on:
			_rebuild_smear(move, view, sx)
			_smear_mat.albedo_color = Color(1, 1, 1, 0.9 * (1.0 - MK.prog(f, a1 - 4.0, 4.0)))
	_smear.visible = smear_on
	var lunge := float(move.sample(&"lunge", f, view)) if move else 0.0
	cut.position = face_dir * lunge
	# hurt: a blink (2.5 a second, small: photosensitivity), and down: fall flat
	var blink := 0.0
	if clock.since(&"hurt") < invulnerable_time:
		blink = 0.55 if fmod(clock.since(&"hurt") * 2.5, 1.0) < 0.5 else 0.0
	cut.rig.set_flash(Color("#ffffff"), blink)
	cut.rotation = Vector3(-minf(clock.since(&"down") * 6.0, 1.45), 0, 0) if hp <= 0 else Vector3.ZERO
	MotionPerfProbe.end(&"hero.pose", t)
	var squash := float(move.sample(&"squash", f, view)) if move else (-0.07 if _charging else 0.0)
	secondary.render(frac, squash, clampf(spd / speed, 0.0, 1.0))
