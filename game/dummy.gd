# The training dummy: never dies, the juice testbed. A post with a straw
# sack and a head, built from flat-shaded faceted solids with outlines.
# Reactions (each switchable through Tune):
#   wobble  a tilt spring kicked along the hit (stateful MotionSpring2D,
#           stepped on the dummy's clock, so it waits out the hit-stop)
#   squash  volume-preserving squash from frames since the hit (pure)
#   flash   a small warm tint, at most 3 a second (photosensitivity)
#   ring    an impact ring running out on the ground
class_name Dummy
extends StaticBody3D

var clock: MotionClock
var look: Look

var _tilt := MotionSpring2D.new(Vector2.ZERO, 3.2, 70.0)
var _pivot: Node3D
var _body: MeshInstance3D
var _ring: MeshInstance3D
var _flash_ok := true


func setup(p_look: Look, world: MotionClock) -> void:
	look = p_look
	clock = MotionClock.new(world)
	_build()


func _build() -> void:
	collision_layer = 1
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = 1.4
	cs.shape = cyl
	cs.position.y = 0.7
	add_child(cs)

	var hurt := Area3D.new()
	hurt.name = "Hurtbox"
	hurt.collision_layer = 1 << 4
	hurt.collision_mask = 0
	hurt.monitoring = false
	var hs := CollisionShape3D.new()
	var hc := CylinderShape3D.new()
	hc.radius = 0.38
	hc.height = 1.5
	hs.shape = hc
	hs.position.y = 0.75
	hurt.add_child(hs)
	add_child(hurt)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_pivot)

	var st := MotionFlat3D.begin()
	var edges := MotionEdges3D.new()
	MotionFlat3D.cylinder(st, Vector3(0, 0, 0), 0.06, 0.55, Vector2.ZERO, Look.WOOD, edges, 8)
	MotionFlat3D.cylinder(st, Vector3(0, 0.5, 0), 0.27, 0.62, Vector2.ZERO, Look.STRAW, edges, 10)
	MotionFlat3D.box(st, Vector3(-0.42, 0.86, -0.04), Vector3(0.84, 0.09, 0.08), Vector2.ZERO, Look.WOOD, edges, true)
	MotionFlat3D.cylinder(st, Vector3(0, 1.14, 0), 0.19, 0.3, Vector2.ZERO, Look.STRAW.lightened(0.1), edges, 10)
	MotionFlat3D.cylinder(st, Vector3(0, 0.66, 0), 0.275, 0.05, Vector2.ZERO, Color("#a0603c"), null, 10)
	_body = MotionFlat3D.instance(st.commit(), look.white_instanced)
	_pivot.add_child(_body)
	_pivot.add_child(MotionFlat3D.instance(edges.commit(), look.edges))

	var shadow := look.ground_decal(look.blob_uv, Vector2(0.42, 0.3), Color(0.1, 0.12, 0.2, 0.55))
	shadow.position.y = 0.01
	add_child(shadow)
	_ring = look.ground_ring(0.86)
	_ring.position.y = 0.02
	_ring.visible = false
	add_child(_ring)


## Called by a hitbox: info = {dir, power, attacker, point}.
func take_hit(info: Dictionary) -> void:
	var dir: Vector3 = info.dir
	var power: float = info.get("power", 1.0)
	_flash_ok = clock.count(&"hit", 1.0) < 3        # this hit makes at most the 3rd in a second
	clock.mark(&"hit", info)
	if Tune.get_or_default().wobble:
		_tilt.impulse(Vector2(dir.x, dir.z) * 5.5 * power)
	GameEvents.emit(&"hit.wood", info.get("point", global_position), power, {target = self, dir = dir})


func _process(delta: float) -> void:
	var t := PerfProbe.begin()
	clock.tick(delta)
	var tune := Tune.get_or_default()
	_tilt.step(clock.dt)
	var tilt := _tilt.value if tune.wobble else Vector2.ZERO
	var f := clock.frames_since(&"hit")
	# squash: 1 at the hit, settling with a little overshoot (pure in f)
	var s := (1.0 - MK.spring(f, 0.0, 7.0, 320.0)) * 0.16 if tune.squash else 0.0
	var sy := 1.0 - s
	var sxz := 1.0 / sqrt(maxf(sy, 0.2))
	_pivot.basis = Basis.from_euler(Vector3(tilt.y * 0.22, 0.0, -tilt.x * 0.22)) * Basis.from_scale(Vector3(sxz, sy, sxz))
	# flash: short, small, rate-limited
	var fl := 0.0
	if tune.flash and _flash_ok and f < 6.0:
		fl = 0.75 * exp(-f / 1.6)
	MotionFlat3D.set_flash(_body, Color("#fff4d8"), fl)
	# impact ring
	var age := clock.since(&"hit")
	var ring_on := tune.rings and age < 0.32
	_ring.visible = ring_on
	if ring_on:
		var u := age / 0.32
		var r := lerpf(0.35, 1.5, 1.0 - pow(1.0 - u, 3.0))
		_ring.scale = Vector3(r, 1, r)
		(_ring.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, 0.9 * (1.0 - u))
	PerfProbe.end(&"dummy", t)
