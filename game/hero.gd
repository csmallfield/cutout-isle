# The hero for the look spike: 8-way analogue movement, a single sword
# swing with a hitbox, and a cutout body + head + sword built from SVG cards.
# Procedural layers (each switchable from the debug overlay through Tune):
#   breathe / walk bob (pre-gait placeholder), paper-turn flip on facing
#   change, swing pose from time since the swing (frame-pure), the slash
#   smear. Phase 2 replaces the bob with gait and IK.
# Time: everything reads `clock` (a MotionClock under the world clock), so a
# hit-stop on the hero freezes its pose, its smear and its movement.
class_name Hero
extends CharacterBody3D

signal hit_landed(target: Node, info: Dictionary)

const HEAD := "res://art/hero_head.svg"
const BODY := "res://art/hero_body.svg"
const SWORD := "res://art/sword.svg"

@export var speed := 4.2
@export var accel_damping := 16.0
@export var accel_stiffness := 140.0
## How far the cards lean back from vertical toward the camera (degrees).
## 0 = upright (exact occlusion against props behind, most stretch); the
## camera pitch = facing the camera (no stretch, cards can dip into props
## behind). Height is compensated so the art keeps its drawn proportions.
@export var card_lean_deg := 20.0
## Swing timing in frames at 30 fps: windup, slash, settle, recover.
@export var swing_keys := PackedFloat64Array([0.0, 3.0, 6.0, 10.0, 18.0])
## Sword angle (degrees, in the card plane, + is counter-clockwise) at those keys.
@export var swing_angles := PackedFloat64Array([-25.0, 60.0, -120.0, -110.0, -25.0])
## Frames of the swing when the hitbox is live.
@export var active_from := 3.0
@export var active_to := 7.0

var clock: MotionClock
var look: Look
var camera_pitch := 50.0
var aim := Vector3(1, 0, 0)       # last move direction, for the hitbox
var facing := 1.0                 # +1 right, -1 left (paper turn target)

var _move := MotionSpring3D.new(Vector3.ZERO, 16.0, 140.0)
var _flip := MotionSpring.new(1.0, 14.0, 260.0)
var _visual: Node3D
var _card: Node3D
var _flipper: Node3D
var _body: MeshInstance3D
var _head: MeshInstance3D
var _head_pivot: Node3D
var _sword_pivot: Node3D
var _smear: MeshInstance3D
var _smear_mat: StandardMaterial3D
var _shadow: MeshInstance3D
var _hitbox: Area3D
var _hit_this_swing := {}
var _swing_id := 0
var _walk_phase := 0.0


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

	# Everything below is posed in _process: interpolation off, it follows
	# the body's interpolated transform.
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_visual)
	_card = Node3D.new()
	_card.name = "Card"
	_visual.add_child(_card)
	_flipper = Node3D.new()
	_flipper.name = "Flip"
	_card.add_child(_flipper)

	const BODY_W := 0.62
	_body = Cutout.card(look, BODY, BODY_W, Vector2(0.5, 1.0),
			PackedStringArray(["leg_l", "leg_r", "boot_l", "boot_r", "arm_l", "arm_r", "hand_l", "hand_r", "tunic", "belt"]))
	_flipper.add_child(_body)
	var neck := Cutout.point(BODY, Vector2(80, 14), BODY_W)
	_head_pivot = Node3D.new()
	_head_pivot.position = neck + Vector3(0, 0, 0.09)
	_flipper.add_child(_head_pivot)
	_head = Cutout.card(look, HEAD, 0.74, Vector2(0.5, 0.86),
			PackedStringArray(["hair_back", "ear_l", "ear_r", "face", "fringe", "tuft"]))
	_head_pivot.add_child(_head)

	# Sword in the right hand (art right), behind the hand, in front of the tunic.
	_sword_pivot = Node3D.new()
	_sword_pivot.position = Cutout.point(BODY, Vector2(132, 96), BODY_W) + Vector3(0, 0, 0.05)
	_flipper.add_child(_sword_pivot)
	var sword := Cutout.card(look, SWORD, 0.15, Vector2(0.5, 136.0 / 160.0))
	_sword_pivot.add_child(sword)
	_smear = _build_smear()
	_sword_pivot.add_child(_smear)

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


## A crescent behind the blade for the slash frames (in the card plane).
func _build_smear() -> MeshInstance3D:
	var st := MotionFlat3D.begin()
	var seg := 18
	for i in seg:
		# the blade's sweep: tip from 150 degrees (windup) to -30 (slash end)
		var a0 := deg_to_rad(lerpf(150.0, -30.0, float(i) / seg))
		var a1 := deg_to_rad(lerpf(150.0, -30.0, float(i + 1) / seg))
		var w0 := sin(PI * float(i) / seg)          # thick in the middle
		var w1 := sin(PI * float(i + 1) / seg)
		var r_out := 0.5
		var p0o := Vector3(cos(a0), sin(a0), 0) * r_out
		var p1o := Vector3(cos(a1), sin(a1), 0) * r_out
		var p0i := p0o * (1.0 - 0.38 * w0)
		var p1i := p1o * (1.0 - 0.38 * w1)
		MotionFlat3D.quad(st, p0i, p1i, p1o, p0o, Vector3.BACK, Vector2.ZERO, Color("#fffbe8"))
	# Drawn over everything (no depth test): a smear is an effect on the
	# picture, and a card's arc would otherwise dip under the ground.
	_smear_mat = StandardMaterial3D.new()
	_smear_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smear_mat.vertex_color_use_as_albedo = true
	_smear_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smear_mat.no_depth_test = true
	_smear_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_smear_mat.render_priority = 1
	var mi := MotionFlat3D.instance(st.commit(), _smear_mat)
	mi.position.z = -0.01
	mi.visible = false
	return mi


# ------------------------------------------------------------------ input and movement

func _physics_process(delta: float) -> void:
	var t := PerfProbe.begin()
	var r := clock.rate()                     # 0 during this hero's hit-stop
	var d := delta * r
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var want := Vector3(input.x, 0.0, input.y) * speed
	_move.damping = accel_damping
	_move.stiffness = accel_stiffness
	_move.target = want
	var v := _move.step(d)
	if input.length() > 0.2:
		aim = Vector3(input.x, 0.0, input.y).normalized()
		if absf(input.x) > 0.25:
			facing = signf(input.x)
	velocity = v * r                          # frozen in place while stopped
	if r > 0.0:
		move_and_slide()
		velocity /= r
		_move.value = Vector3(velocity.x, 0.0, velocity.z)
	_update_hitbox()
	PerfProbe.end(&"hero", t)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		swing()


## Start a swing (ignored while one is still slashing).
func swing() -> void:
	var f := clock.frames_since(&"swing")
	if f < swing_keys[3]:
		return
	_swing_id += 1
	_hit_this_swing.clear()
	clock.mark(&"swing", {aim = aim})
	GameEvents.emit(&"swing", global_position, 1.0, {source = self})


func _update_hitbox() -> void:
	var f := clock.frames_since(&"swing")
	var live := f >= active_from and f <= active_to
	_hitbox.position = aim * 0.62 + Vector3(0, 0.5, 0)
	if not live:
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
	var d := clock.dt
	var tune := Tune.get_or_default()

	# Cards: lean toward the camera, stretched so the art keeps its proportions.
	var lean := deg_to_rad(card_lean_deg)
	_card.rotation = Vector3(-lean, 0, 0)
	_card.scale = Vector3(1, 1.0 / cos(deg_to_rad(camera_pitch) - lean), 1)

	# Paper turn: the flip passes through zero when facing changes.
	_flip.target = facing
	var fx := _flip.step(d) if tune.paper_turn else facing
	_flipper.scale = Vector3(fx, 1, 1)

	# Breathing and a walk bob (placeholder for phase 2's gait).
	var spd := Vector2(velocity.x, velocity.z).length()
	var walk := clampf(spd / speed, 0.0, 1.0)
	_walk_phase += d * lerpf(0.0, 9.0, walk)
	var breathe := sin(clock.time * TAU * 0.45) * 0.012 * (1.0 - walk)
	var bob := absf(sin(_walk_phase)) * 0.045 * walk if tune.bob else 0.0
	_visual.scale = Vector3(1.0 - breathe * 0.5, 1.0 + breathe, 1.0) if tune.bob else Vector3.ONE
	_head_pivot.rotation.z = (sin(_walk_phase) * 0.06 * walk if tune.bob else 0.0)

	# Swing: a pure function of frames since the swing on the hero's clock.
	var f := clock.frames_since(&"swing")
	var ang := MK.interp(f, Array(swing_keys), Array(swing_angles), MK.ease_out)
	_sword_pivot.rotation.z = deg_to_rad(ang)
	var smear_on := tune.smear and f >= swing_keys[1] and f < swing_keys[3] + 2.0
	_smear.visible = smear_on
	if smear_on:
		# drawn relative to the blade: counter the pivot so the arc stays put
		_smear.rotation.z = -deg_to_rad(ang)
		var o := 1.0 - MK.prog(f, swing_keys[2], 6.0)
		_smear_mat.albedo_color = Color(1, 1, 1, 0.85 * o)
	# a small lunge into the slash
	var lunge := MK.interp(f, [swing_keys[1], swing_keys[2], swing_keys[4]], [0.0, 1.0, 0.0], MK.ease_out)
	_visual.position = Vector3(0, bob, 0) + aim * 0.08 * lunge
	PerfProbe.end(&"hero.pose", t)
