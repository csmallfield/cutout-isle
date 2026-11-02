# Counts geometry instances whose material uses instance uniforms, by owner,
# against the Compatibility renderer's 4096-slot limit.
extends SceneTree
var frames := 0
func _initialize() -> void:
	change_scene_to_file("res://game/main.tscn")
func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		var by := {}
		var total := 0
		var stack: Array[Node] = [current_scene]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children(true))
			if n is GeometryInstance3D:
				var m := (n as GeometryInstance3D).material_override as ShaderMaterial
				if m and m.shader and (m.shader.code.contains("instance uniform") or m.shader.code.contains("MK_INSTANCED")):
					var top := n
					while top.get_parent() != current_scene and top.get_parent() != null:
						top = top.get_parent()
					var k := top.get_class() + ":" + String(top.name).left(12) + " " + m.shader.resource_path.get_file()
					by[k] = int(by.get(k, 0)) + 1
					total += 1
		var keys := by.keys()
		keys.sort_custom(func(a, b): return by[a] > by[b])
		for k in keys.slice(0, 14):
			print("%5d  %s" % [by[k], k])
		print("TOTAL ", total)
		quit()
	return false
