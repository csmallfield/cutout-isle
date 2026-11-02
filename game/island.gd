# The island chunk, about 3 x 3 screens: a training yard by the start, a
# meadow to the west (blobs), a beach along the south, a jetty to the east,
# rocks and trees, a stepping-stone path north to a cliff with a cave mouth,
# and the cave itself (a small room far to the north, reached through a
# transition; its own reverb zone). Grass tufts everywhere the ground is
# grass, rippling from hits and footsteps (MotionGrass3D + MotionRipples).
# Terrain, props and outlines are merged by material: a handful of draw
# calls for the whole chunk, plus one for the grass.
class_name Island
extends Node3D

## Where the cave room sits (far from the island: reached by transition).
const CAVE := Vector3(0.0, 0.0, -70.0)
const CAVE_MOUTH := Vector3(1.0, 0.0, -10.6)
const CAVE_SPAWN := Vector3(0.0, 0.0, -70.0 + 4.0)
const MOUTH_SPAWN := Vector3(1.0, 0.0, -9.2)

## Ground surfaces for footsteps: [Rect2 on x, z, surface name], first match
## wins; everything else is grass. The cave floor is stone.
const SURFACES := [
	[Rect2(11.0, -3.0, 5.5, 2.4), &"wood"],       # jetty
	[Rect2(16.0, -2.4, 6.0, 1.2), &"wood"],
	[Rect2(-16.0, 6.2, 32.0, 3.8), &"sand"],      # beach
	[Rect2(-7.0, -80.0, 14.0, 20.0), &"stone"],   # cave
]

var look: Look
var ripples := MotionRipples.new()
var grass: MultiMeshInstance3D
var path_points: Array[Vector2] = []      # stepping stones (x, z)
var _props_xz: Array[Vector3] = []        # (x, z, radius) kept clear of grass


## The surface at a world position (for footsteps).
func surface_at(p: Vector3) -> StringName:
	for s in SURFACES:
		if (s[0] as Rect2).has_point(Vector2(p.x, p.z)):
			return s[1]
	for q in path_points:
		if Vector2(p.x, p.z).distance_to(q) < 0.42:
			return &"stone"
	return &"grass"


func setup(p_look: Look) -> void:
	add_to_group(&"island")
	look = p_look
	_build()
	_build_cave()
	_build_grass()
	GameEvents.event.connect(_on_event)


func _on_event(name: StringName, pos: Vector3, intensity: float, _data: Dictionary) -> void:
	var n := String(name)
	if n.begins_with("hit."):
		ripples.add(pos, 0.9 + 0.4 * intensity)
	elif n == "step.grass":
		ripples.add(pos, 0.25 * intensity)
	elif n in ["dash", "land", "swing.charge", "enemy.ko"]:
		ripples.add(pos, 0.7)


func _process(delta: float) -> void:
	var t := MotionPerfProbe.begin()
	ripples.step(delta)
	ripples.apply()
	MotionGrass3D.tick(grass, ripples.time)
	MotionPerfProbe.end(&"world", t)


func _build() -> void:
	var terrain := MotionFlat3D.begin()
	var props := MotionFlat3D.begin()
	var edges := MotionEdges3D.new()

	# the plateau, a lower ledge, and the cliff along the north
	MotionFlat3D.box(terrain, Vector3(-16, -1.6, -12), Vector3(32, 1.6, 22), Vector2.ZERO, Color.WHITE, edges)
	MotionFlat3D.box(terrain, Vector3(4, -1.6, 10), Vector3(9, 1.2, 3), Vector2.ZERO, Color.WHITE, edges)
	_wall(Vector3(-16, -1.6, -12), Vector3(32, 1.6, 22))
	for r in [Rect2(-16.5, -12.5, 33, 0.5), Rect2(-16.5, 10, 33, 0.5), Rect2(-16.5, -12.5, 0.5, 23), Rect2(16, -12.5, 0.5, 23)]:
		_wall(Vector3(r.position.x, -1, r.position.y), Vector3(r.size.x, 3, r.size.y), true)
	var cliff := Color("#a39a8a")
	var x := -16.0
	var i := 0
	while x < 16.0:
		var w := 1.6 + MK.rand(i * 2.3) * 1.4
		var h := 2.2 + MK.rand(i * 4.1) * 1.2
		var d := 1.6 + MK.rand(i * 6.7) * 0.8
		if x + w > 0.0 and x < 2.0:          # the cave mouth: a lintel over a gap
			MotionFlat3D.box(props, Vector3(-0.2, 1.7, -12.0), Vector3(2.4, 1.2, 1.5), Vector2.ZERO, cliff.darkened(0.08), edges)
			x = 2.2
			i += 1
			continue
		MotionFlat3D.box(props, Vector3(x, 0.0, -12.0), Vector3(w, h, d), Vector2.ZERO, cliff.darkened(MK.rand(i * 9.3) * 0.12), edges)
		_wall(Vector3(x, 0, -12), Vector3(w, h, d))
		_props_xz.append(Vector3(x + w * 0.5, -12.0 + d * 0.5, maxf(w, d)))
		x += w
		i += 1
	# the dark inside of the mouth
	var dark := MotionFlat3D.begin()
	MotionFlat3D.quad(dark, Vector3(-0.2, 0.0, -11.2), Vector3(2.2, 0.0, -11.2), Vector3(2.2, 1.75, -11.2), Vector3(-0.2, 1.75, -11.2), Vector3.BACK, Vector2.ZERO, Color("#16131c"))
	add_child(MotionFlat3D.instance(dark.commit(), look.flat.material(Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, 0.0, false, true)))
	_wall(Vector3(-0.2, 0, -12.2), Vector3(2.4, 2, 0.8))

	# beach: sand down to the sea along the south
	MotionFlat3D.box(props, Vector3(-16, -0.04, 6.2), Vector3(32, 0.046, 3.8), Vector2.ZERO, Color("#ecd9a0"), null)
	# jetty to the east, out over the sea
	var plank := Color("#a9773f")
	for k in 6:
		MotionFlat3D.box(props, Vector3(11.0, -0.04, -3.0 + k * 0.4), Vector3(5.5, 0.046, 0.36), Vector2.ZERO, plank if k % 2 == 0 else plank.lightened(0.08), edges)
	for k in 15:
		MotionFlat3D.box(props, Vector3(16.0 + k * 0.4, -0.04, -2.4), Vector3(0.36, 0.046, 1.2), Vector2.ZERO, plank if k % 2 == 0 else plank.lightened(0.08), edges)
	for px in [16.6, 19.0, 21.6]:
		for pz in [-2.5, -1.15]:
			MotionFlat3D.cylinder(props, Vector3(px, -1.3, pz), 0.09, 1.45, Vector2.ZERO, plank.darkened(0.25), edges, 6)
	_wall(Vector3(16.0, -1, -2.5), Vector3(6, 3, 0.1), true)
	_wall(Vector3(16.0, -1, -1.2), Vector3(6, 3, 0.1), true)
	_wall(Vector3(22.0, -1, -2.5), Vector3(0.1, 3, 1.4), true)
	_wall(Vector3(15.9, -1, -1.2), Vector3(0.1, 3, 0.1), true)

	# the stepping-stone path from the beach up to the cave mouth
	var curve := Curve2D.new()
	for q in [Vector2(-3.0, 7.0), Vector2(-1.5, 3.5), Vector2(1.8, 0.5), Vector2(0.4, -3.5), Vector2(1.6, -7.0), Vector2(1.0, -10.4)]:
		curve.add_point(q)
	var length := curve.get_baked_length()
	var s := 0.0
	var j := 0
	while s < length:
		var q := curve.sample_baked(s) + Vector2(MK.rand(j * 1.7) - 0.5, MK.rand(j * 3.1) - 0.5) * 0.18
		var w := 0.55 + MK.rand(j * 5.3) * 0.14
		MotionFlat3D.box(props, Vector3(q.x - w * 0.5, -0.04, q.y - 0.3), Vector3(w, 0.046, 0.6), Vector2.ZERO, Look.STONE.darkened(MK.rand(j * 7.7) * 0.12), edges)
		path_points.append(q)
		s += 0.78
		j += 1

	# training yard: a fence pen around the start (the dummy stands in it)
	for k in 9:
		var p := Vector3(-6.0 + k * 0.9, 0, 1.6)
		MotionFlat3D.box(props, p + Vector3(-0.07, 0, -0.07), Vector3(0.14, 0.7, 0.14), Vector2.ZERO, Look.WOOD, edges)
	MotionFlat3D.box(props, Vector3(-6.05, 0.42, 1.56), Vector3(7.3, 0.1, 0.08), Vector2.ZERO, Look.WOOD.lightened(0.1), edges, true)
	_wall(Vector3(-6.1, 0, 1.5), Vector3(7.4, 0.8, 0.2))
	# crates by the jetty
	for p in [Vector3(9.2, 0, -3.6), Vector3(9.95, 0, -3.55), Vector3(9.5, 0.72, -3.6), Vector3(9.0, 0, -2.7)]:
		MotionFlat3D.box(props, p, Vector3(0.7, 0.7, 0.7), Vector2.ZERO, Look.WOOD, edges)
		if p.y == 0.0:
			_wall(p, Vector3(0.7, 1.4, 0.7))
			_props_xz.append(Vector3(p.x + 0.35, p.z + 0.35, 0.6))
	# rocks
	for k in 14:
		var p := Vector3(-15.0 + MK.rand(k * 3.3) * 30.0, 0.0, -9.5 + MK.rand(k * 5.1) * 15.0)
		if _near_path(Vector2(p.x, p.z), 1.4) or Vector2(p.x, p.z).distance_to(Vector2(-1.0, 0.5)) < 4.0:
			continue
		var r := 0.3 + MK.rand(k * 7.9) * 0.4
		MotionFlat3D.cylinder(props, p, r, r * 0.9, Vector2.ZERO, Look.STONE, edges, 6)
		_post(p, r, r * 0.9)
		_props_xz.append(Vector3(p.x, p.z, r + 0.15))
	# trees
	var trees := [Vector3(-10.0, 0, -6.0), Vector3(-12.5, 0, -2.0), Vector3(-8.5, 0, 3.6), Vector3(-13.6, 0, 4.2), Vector3(5.0, 0, -6.4),
		Vector3(7.8, 0, -8.6), Vector3(12.6, 0, -7.0), Vector3(6.2, 0, 3.4), Vector3(13.5, 0, 3.0), Vector3(-4.6, 0, -8.0)]
	for k in trees.size():
		var p: Vector3 = trees[k]
		var sc := 0.85 + MK.rand(k * 2.9) * 0.4
		MotionFlat3D.cylinder(props, p, 0.16 * sc, 1.1 * sc, Vector2.ZERO, Look.WOOD.darkened(0.15), edges, 7)
		MotionFlat3D.cylinder(props, p + Vector3(0, 1.0 * sc, 0), 0.95 * sc, 0.75 * sc, Vector2.ZERO, Look.LEAF, edges, 8)
		MotionFlat3D.cylinder(props, p + Vector3(0, 1.75 * sc, 0), 0.62 * sc, 0.6 * sc, Vector2.ZERO, Look.LEAF.lightened(0.12), edges, 8)
		_post(p, 0.25, 1.0)
		_props_xz.append(Vector3(p.x, p.z, 0.5))

	add_child(MotionFlat3D.instance(terrain.commit(), look.earth))
	add_child(MotionFlat3D.instance(props.commit(), look.white))
	add_child(MotionFlat3D.instance(edges.commit(), look.edges))

	var sea := MotionFlat3D.begin()
	MotionFlat3D.quad(sea, Vector3(-120, -1.3, 120), Vector3(120, -1.3, 120), Vector3(120, -1.3, -120), Vector3(-120, -1.3, -120), Vector3.UP, Vector2.ZERO, Look.SEA)
	var sea_mat := look.flat.material(Look.SEA, Look.SEA, Look.SEA, Color(0, 0, 0, 0), 0.0, false)
	add_child(MotionFlat3D.instance(sea.commit(), sea_mat))


## The cave: a room of dark rock, a stone floor, a few crystals, an exit
## back to the mouth, and a reverb zone for the audio kit.
func _build_cave() -> void:
	var floor := MotionFlat3D.begin()
	var rock := MotionFlat3D.begin()
	var edges := MotionEdges3D.new()
	var o := CAVE
	MotionFlat3D.box(floor, o + Vector3(-7, -1.0, -10), Vector3(14, 1.0, 16), Vector2.ZERO, Color.WHITE, edges)
	_wall(o + Vector3(-7, -1.0, -10), Vector3(14, 1.0, 16))
	var wall_col := Color("#5d5566")
	var k := 0
	for side in [[Vector3(-7.8, 0, -10.8), Vector3(15.6, 0, 0), 0.9], [Vector3(-7.8, 0, -10.8), Vector3(0, 0, 16.8), 0.9],
			[Vector3(7.0, 0, -10.8), Vector3(0, 0, 16.8), 0.9]]:
		var start: Vector3 = side[0]
		var span: Vector3 = side[1]
		var n := int(span.length() / 1.4)
		for m in n:
			var p: Vector3 = o + start + span * (float(m) / n)
			var h := 2.4 + MK.rand(k * 3.7) * 1.4
			MotionFlat3D.box(rock, p, Vector3(1.5, h, 1.5) if span.x > 0.0 else Vector3(0.9, h, 1.5), Vector2.ZERO, wall_col.darkened(MK.rand(k * 5.9) * 0.15), edges)
			k += 1
	_wall(o + Vector3(-7.8, 0, -10.8), Vector3(15.6, 3, 0.8))
	_wall(o + Vector3(-7.8, 0, -10.8), Vector3(0.8, 3, 16.8))
	_wall(o + Vector3(7.0, 0, -10.8), Vector3(0.8, 3, 16.8))
	_wall(o + Vector3(-7.8, 0, 6.0), Vector3(15.6, 3, 0.5), true)
	for c in 9:
		var p := o + Vector3(-6.0 + MK.rand(c * 2.2) * 12.0, 0.0, -9.5 + MK.rand(c * 4.4) * 4.0)
		var h := 0.5 + MK.rand(c * 6.6) * 0.9
		MotionFlat3D.cylinder(rock, p, 0.12 + MK.rand(c * 8.8) * 0.1, h, Vector2.ZERO, Color("#7fd3e0"), edges, 5)
	var stone := look.flat.material(Color("#8d8794"), Color("#6f6977"), Color("#56505d"), Color(0, 0, 0, 0), 0.0, false)
	add_child(MotionFlat3D.instance(floor.commit(), stone))
	add_child(MotionFlat3D.instance(rock.commit(), look.white))
	add_child(MotionFlat3D.instance(edges.commit(), look.edges))

	var zone := AKReverbZone3D.new()
	zone.name = "CaveReverb"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(16, 6, 18)
	cs.shape = bs
	zone.add_child(cs)
	zone.position = o + Vector3(0, 1, -2)
	zone.room = 0.88
	zone.damp = 0.3
	zone.return_db = 3.0
	zone.glide_s = 0.6
	add_child(zone)


func _build_grass() -> void:
	grass = MotionGrass3D.field(Rect2(-15.8, -10.0, 31.6, 16.0), 2.4, Color("#6cb853"), 7, func(p: Vector2) -> bool:
		if surface_at(Vector3(p.x, 0, p.y)) != &"grass" or _near_path(p, 0.55):
			return false
		if p.distance_to(Vector2(-1.0, 0.5)) < 1.2:   # the dummy's spot
			return false
		for q in _props_xz:
			if p.distance_to(Vector2(q.x, q.y)) < q.z:
				return false
		return true, {lean_deg = 28.0, height = 0.24})
	grass.name = "Grass"
	add_child(grass)
	ripples.register(grass.material_override as ShaderMaterial)
	look.flat.register(grass.material_override as ShaderMaterial, false)


func _near_path(p: Vector2, r: float) -> bool:
	for q in path_points:
		if p.distance_to(q) < r:
			return true
	return false


func _wall(p: Vector3, size: Vector3, invisible := false) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = p + size * 0.5
	body.add_child(cs)
	add_child(body)
	if invisible:
		body.name = "Edge"


func _post(base: Vector3, r: float, h: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	cs.shape = c
	cs.position = base + Vector3(0, h * 0.5, 0)
	body.add_child(cs)
	add_child(body)
