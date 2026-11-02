# Orthographic follow camera through MotionLens3D (the kit's lens outside a
# MotionStage3D): a fixed pitch, a spring-followed target with look-ahead,
# and trauma shake (translation in screen pixels plus roll) with
# directional kicks. Runs on real time, so it keeps shaking through a
# per-entity hit-stop; a global hit-stop freezes the world clock, not this.
class_name CameraRig
extends Node3D

@export var pitch := 50.0
## World metres across the screen height.
@export var frame_h := 7.5
@export var look_ahead := 0.32      # seconds of velocity
@export var follow_damping := 13.0
@export var follow_stiffness := 70.0

var camera: Camera3D
## The ear sits on the framed target, not the camera: an orthographic camera
## is ~60 m away, which would put every sound at the edge of its range.
var listener: AudioListener3D
var lens: MotionLens3D
var trauma := MotionTrauma.new(11.0)
var target_node: Node3D
var _follow := MotionSpring3D.new(Vector3.ZERO, 13.0, 70.0)
## Perspective strength (0 = orthographic): the cave's lens moment.
var persp := MotionSpring.new(0.0, 9.0, 40.0)
var look: Look
var env: Environment
const SKY := Color(0.2, 0.55, 0.68)
const CAVE_BG := Color("#120f17")


func _ready() -> void:
	camera = Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	camera.make_current()
	listener = AudioListener3D.new()
	add_child(listener)
	listener.make_current()
	lens = MotionLens3D.extrude(0.0, pitch, 1080.0 / frame_h, Vector3.ZERO)
	trauma.max_offset = Vector2(18, 14)
	trauma.max_roll = deg_to_rad(1.6)


func snap_to(p: Vector3) -> void:
	_follow.snap(p)


## In the cave the lens eases into a narrow perspective (a dolly zoom: the
## hero keeps its size while depth opens up), with dark fog and background.
func set_cave(on: bool) -> void:
	persp.target = 0.42 if on else 0.0
	if env:
		env.background_color = CAVE_BG if on else SKY


func hit(screen_dir: Vector2, amount: float) -> void:
	var tune := Tune.get_or_default()
	if tune.shake:
		trauma.add(amount)
	if tune.kick:
		trauma.kick(screen_dir, 9.0 * amount / 0.3)


## Screen direction (pixels, +y down) of a world direction at `at`.
func screen_dir(at: Vector3, dir: Vector3) -> Vector2:
	return camera.unproject_position(at + dir) - camera.unproject_position(at)


func _process(delta: float) -> void:
	var t := MotionPerfProbe.begin()
	if target_node:
		var p := target_node.get_global_transform_interpolated().origin
		var v: Vector3 = target_node.velocity if "velocity" in target_node else Vector3.ZERO
		_follow.damping = follow_damping
		_follow.stiffness = follow_stiffness
		_follow.target = p + Vector3(v.x, 0.0, v.z) * look_ahead + Vector3(0, 0.5, 0)
	var real_dt := delta / maxf(Engine.time_scale, 1e-4)   # camera ignores slow-mo
	_follow.step(real_dt)
	trauma.step(real_dt)
	lens.target = _follow.value
	lens.frame_h = frame_h
	lens.basis = MotionLens3D.extrude_basis(0.0, pitch) * Basis(Vector3.BACK, trauma.roll())
	lens.offset = trauma.offset()
	lens.fov = 50.0
	lens.persp = maxf(persp.step(real_dt), 0.0)
	lens.apply(camera)
	if look:
		var k := clampf(persp.value / 0.42, 0.0, 1.0)
		look.flat.fog_for(lens, CAVE_BG, -1.5, 9.0, 0.85 * k)
	listener.global_transform = Transform3D(camera.global_basis, _follow.value)
	MotionPerfProbe.end(&"camera", t)
