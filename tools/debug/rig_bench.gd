# Times the rig operations one hero frame uses (CPU script cost only).
#   godot --headless --path . --script res://tools/debug/rig_bench.gd
extends SceneTree


func _initialize() -> void:
	var flat := MotionFlat3D.new()
	var rig := MotionCutoutRig.build(MotionSvgData.load_any("res://art/hero_side.svg"), 0.8, flat.cutout(), flat.edges(), {origin = Vector2(110, 318)})
	root.add_child(rig)
	var n := 2000
	var fl := rig.rest_pivot(&"foot_l")
	var t := Time.get_ticks_usec()
	for i in n:
		rig.reset_pose()
	var t_reset := float(Time.get_ticks_usec() - t) / n
	t = Time.get_ticks_usec()
	for i in n:
		rig.solve_limb(&"leg_l_upper", &"leg_l_lower", &"foot_l", fl + Vector3(0.01, 0.01, 0), 1.0)
	var t_solve := float(Time.get_ticks_usec() - t) / n
	t = Time.get_ticks_usec()
	for i in n:
		rig.pose(&"head", 0.05, Vector2(0, 0.01))
	var t_pose := float(Time.get_ticks_usec() - t) / n
	t = Time.get_ticks_usec()
	for i in n:
		rig.rig_transform(&"hand_r")
	var t_xf := float(Time.get_ticks_usec() - t) / n
	print("parts %d  reset %.1f us  solve_limb %.1f us  pose %.1f us  rig_transform %.1f us" % [rig.parts.size(), t_reset, t_solve, t_pose, t_xf])
	quit()
