# Combat feedback in one place, driven by GameEvents: hit-stop (per entity
# or global, from Tune), camera trauma and a kick along the blow. Reactions
# that belong to an actor (wobble, squash, flash, ring) live on the actor;
# this only does what spans actors.
class_name Juice
extends Node

var world: MotionClock
var rig: CameraRig
var look: Look
var _stars: Array[Dictionary] = []      # {node, mat, age, angle}
var _rings: Array[Dictionary] = []      # {node, age}


func setup(p_world: MotionClock, p_rig: CameraRig, p_look: Look) -> void:
	world = p_world
	rig = p_rig
	look = p_look
	for i in 4:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.render_priority = 2
		var n := MotionFlat3D.instance(_star_mesh(), mat)
		n.visible = false
		add_child(n)
		_stars.append({node = n, mat = mat, age = 9.0, angle = 0.0, size = 1.0})
	for i in 2:
		var r := look.ground_ring(0.8)
		r.visible = false
		add_child(r)
		_rings.append({node = r, age = 9.0})
	GameEvents.event.connect(_on_event)


## An impact star: four long rays and four short ones, pointing out from the
## centre (card plane, +Z facing).
static func _star_mesh() -> ArrayMesh:
	var st := MotionFlat3D.begin()
	for i in 8:
		var a := TAU * i / 8.0
		var l := 0.42 if i % 2 == 0 else 0.22
		var w := 0.05 if i % 2 == 0 else 0.035
		var d := Vector3(cos(a), sin(a), 0.0)
		var nrm := Vector3(-d.y, d.x, 0.0)
		var p0 := d * 0.08
		MotionFlat3D.quad(st, p0 - nrm * w, d * l, d * l, p0 + nrm * w, Vector3.BACK, Vector2.ZERO, Color("#fffbe8"))
	return st.commit()


func _on_event(name: StringName, pos: Vector3, intensity: float, data: Dictionary) -> void:
	if name == &"charge.full":
		_spawn_ring(pos)
		return
	if not String(name).begins_with("hit."):
		return
	var tune := Tune.get_or_default()
	var target: Node = data.get("target")
	var dir: Vector3 = data.get("dir", Vector3.ZERO)
	if tune.hitstop:
		var hold := tune.hitstop_hold * pow(maxf(intensity, 0.3), 0.6)
		if tune.per_entity:
			for n in [target, _attacker_of(target)]:
				if n and "clock" in n and n.clock:
					(n.clock as MotionClock).freeze(hold, tune.hitstop_ease)
		else:
			world.freeze(hold, tune.hitstop_ease)
	rig.hit(rig.screen_dir(pos, dir), 0.22 * intensity)
	if tune.rings:
		_spawn_star(pos, rig.screen_dir(pos, dir), intensity)


func _spawn_star(pos: Vector3, screen_dir: Vector2, power: float) -> void:
	var s: Dictionary = _stars[0]
	for c in _stars:
		if float(c.age) > float(s.age):
			s = c
	s.age = 0.0
	s.angle = atan2(-screen_dir.y, screen_dir.x) + PI * 0.125
	s.size = 0.6 + 0.35 * power
	(s.node as Node3D).global_position = pos
	(s.node as Node3D).visible = true


func _spawn_ring(pos: Vector3) -> void:
	var r: Dictionary = _rings[0] if float(_rings[0].age) > float(_rings[1].age) else _rings[1]
	r.age = 0.0
	(r.node as Node3D).global_position = Vector3(pos.x, 0.02, pos.z)
	(r.node as Node3D).visible = true


## Effects run on real time, so they play through a hit-stop.
func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 1e-4)
	var cam := get_viewport().get_camera_3d()
	for s in _stars:
		if float(s.age) > 1.0:
			continue
		s.age = float(s.age) + real
		var u := float(s.age) / 0.17
		var n: Node3D = s.node
		n.visible = u < 1.0
		if u < 1.0 and cam:
			var k := float(s.size) * (0.35 + 0.75 * (1.0 - pow(1.0 - u, 3.0)))
			n.global_basis = cam.global_basis * Basis(Vector3.BACK, float(s.angle)) * Basis.from_scale(Vector3(k, k, k))
			(s.mat as StandardMaterial3D).albedo_color = Color(1, 1, 1, 1.0 - u * u)
	for r in _rings:
		if float(r.age) > 1.0:
			continue
		r.age = float(r.age) + real
		var u := float(r.age) / 0.3
		var n: Node3D = r.node
		n.visible = u < 1.0
		if u < 1.0:
			var rad := lerpf(0.3, 1.1, 1.0 - pow(1.0 - u, 3.0))
			n.scale = Vector3(rad, 1, rad)
			((n as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(1, 0.93, 0.7, 0.9 * (1.0 - u))


func _attacker_of(target: Node) -> Node:
	if target and "clock" in target:
		var info: Dictionary = (target.clock as MotionClock).last_data(&"hit")
		return info.get("attacker")
	return null
