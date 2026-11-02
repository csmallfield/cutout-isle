# One small island chunk for the look spike: a grass plateau with earth
# cliffs and a lower ledge, sea around it, and props to walk behind (rocks,
# crates, trees, a fence). Everything is merged by material: terrain, props
# and outlines are three meshes, three draw calls, plus colliders.
class_name Island
extends Node3D

var look: Look


func setup(p_look: Look) -> void:
	look = p_look
	_build()


func _build() -> void:
	var terrain := MotionFlat3D.begin()
	var props := MotionFlat3D.begin()
	var edges := MotionEdges3D.new()

	# plateau and a lower ledge to the south-east
	MotionFlat3D.box(terrain, Vector3(-8, -1.6, -7), Vector3(16, 1.6, 13), Vector2.ZERO, Color.WHITE, edges)
	MotionFlat3D.box(terrain, Vector3(1, -1.6, 6), Vector3(6, 1.2, 3), Vector2.ZERO, Color.WHITE, edges)
	_wall(Vector3(-8, -1.6, -7), Vector3(16, 1.6, 13))
	_wall(Vector3(1, -1.6, 6), Vector3(6, 1.2, 3))
	# the island's edge: invisible walls so the hero stays on top
	for r in [Rect2(-8.5, -7.5, 17, 0.5), Rect2(-8.5, 6, 17, 0.5), Rect2(-8.5, -7.5, 0.5, 14), Rect2(8, -7.5, 0.5, 14)]:
		_wall(Vector3(r.position.x, -1, r.position.y), Vector3(r.size.x, 3, r.size.y), true)

	# rocks
	for p in [Vector3(-5.5, 0, -4.5), Vector3(-6.2, 0, -3.6), Vector3(5.2, 0, 3.4), Vector3(3.0, -0.4, 7.4)]:
		var r := 0.35 + MK.rand(p.x * 3.1 + p.z) * 0.3
		MotionFlat3D.cylinder(props, p, r, r * 0.9, Vector2.ZERO, Look.STONE, edges, 6)
		_post(p, r, r * 0.9)
	# crates
	for p in [Vector3(4.2, 0, -3.2), Vector3(4.95, 0, -3.15), Vector3(4.5, 0.72, -3.2)]:
		MotionFlat3D.box(props, p, Vector3(0.7, 0.7, 0.7), Vector2.ZERO, Look.WOOD, edges)
		if p.y == 0.0:
			_wall(p, Vector3(0.7, 1.4, 0.7))
	# trees: a trunk and two stacked canopies
	for p in [Vector3(-3.0, 0, -5.2), Vector3(1.6, 0, -5.6), Vector3(-6.4, 0, 2.6), Vector3(6.0, 0, -0.4)]:
		MotionFlat3D.cylinder(props, p, 0.16, 1.1, Vector2.ZERO, Look.WOOD.darkened(0.15), edges, 7)
		MotionFlat3D.cylinder(props, p + Vector3(0, 1.0, 0), 0.95, 0.75, Vector2.ZERO, Look.LEAF, edges, 8)
		MotionFlat3D.cylinder(props, p + Vector3(0, 1.75, 0), 0.62, 0.6, Vector2.ZERO, Look.LEAF.lightened(0.12), edges, 8)
		_post(p, 0.25, 1.0)
	# a fence along the north-west
	for i in 7:
		var p := Vector3(-7.4 + i * 0.9, 0, -1.2)
		MotionFlat3D.box(props, p + Vector3(-0.07, 0, -0.07), Vector3(0.14, 0.7, 0.14), Vector2.ZERO, Look.WOOD, edges)
	MotionFlat3D.box(props, Vector3(-7.45, 0.42, -1.24), Vector3(5.5, 0.1, 0.08), Vector2.ZERO, Look.WOOD.lightened(0.1), edges, true)
	_wall(Vector3(-7.5, 0, -1.3), Vector3(5.6, 0.8, 0.2))

	add_child(MotionFlat3D.instance(terrain.commit(), look.earth))
	add_child(MotionFlat3D.instance(props.commit(), look.white))
	add_child(MotionFlat3D.instance(edges.commit(), look.edges))

	# sea
	var sea := MotionFlat3D.begin()
	MotionFlat3D.quad(sea, Vector3(-80, -1.3, 80), Vector3(80, -1.3, 80), Vector3(80, -1.3, -80), Vector3(-80, -1.3, -80), Vector3.UP, Vector2.ZERO, Look.SEA)
	var sea_mat := look.flat.material(Look.SEA, Look.SEA, Look.SEA, Color(0, 0, 0, 0), 0.0, false)
	add_child(MotionFlat3D.instance(sea.commit(), sea_mat))


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
