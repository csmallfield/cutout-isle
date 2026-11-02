# Debug still: the three hero views side by side, big, straight on.
#   godot --path . --write-movie out/rig/f.png --fixed-fps 30 --quit-after 2 res://tools/debug/rig_still.tscn
extends Node3D


func _ready() -> void:
	var look := Look.new(self)
	var x := -1.0
	for v in [&"front", &"side", &"back"]:
		var rig := MotionCutoutRig.build(MotionSvgData.load_any(Hero.VIEWS[v]), Hero.WIDTH, look.cutout, look.card_edges, {origin = Hero.ORIGIN})
		add_child(rig)
		rig.position = Vector3(x, 0, 0)
		x += 1.0
	for pair in [["res://art/pouch.svg", 0.3, Vector3(1.55, 0.9, 0)], ["res://art/tag.svg", 0.4, Vector3(1.55, 0.4, 0)], ["res://art/sword.svg", 0.12, Vector3(-1.6, 0.3, 0)]]:
		var c := MotionCutoutRig.card(MotionSvgData.load_any(pair[0]), pair[1], look.cutout, look.card_edges, Vector2(0.5, 0.5))
		c.position = pair[2]
		add_child(c)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.6
	cam.position = Vector3(0, 0.6, 5)
	add_child(cam)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#8fcf6a")
	add_child(env)


func _process(_d: float) -> void:
	pass
