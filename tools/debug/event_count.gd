# Counts GameEvents over a scripted run (CPU only, headless).
#   godot --headless --path . --fixed-fps 60 -s res://tools/debug/event_count.gd -- --autoplay
extends SceneTree

var counts := {}
var frames := 0


func _initialize() -> void:
	change_scene_to_file("res://game/main.tscn")
	_hook.call_deferred()


func _hook() -> void:
	(root.get_node("GameEvents")).event.connect(func(n: StringName, _p: Vector3, _i: float, _d: Dictionary) -> void:
		counts[n] = int(counts.get(n, 0)) + 1)


func _process(_d: float) -> bool:
	frames += 1
	if frames >= 1020:
		var keys := counts.keys()
		keys.sort()
		for k in keys:
			print("  %-14s %d" % [k, counts[k]])
		return true
	return false
