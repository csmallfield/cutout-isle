# Knockback probe: hits the hero from the left once it has settled and
# prints how far it travels (CPU only, headless).
#   godot --headless --path . --fixed-fps 60 -s res://tools/debug/knock_probe.gd
extends SceneTree

var frames := 0
var hero: Node3D
var at := Vector3.ZERO


func _initialize() -> void:
	change_scene_to_file("res://game/main.tscn")


func _process(_d: float) -> bool:
	frames += 1
	if hero == null:
		hero = get_first_node_in_group(&"hero") as Node3D
		return false
	if frames == 60:
		at = hero.global_position
		hero.take_damage({dir = Vector3(1, 0, 0), power = 1.0})
	if frames in [70, 90, 120, 180]:
		print("KNOCK after %d frames: %.2f m" % [frames - 60, (hero.global_position - at).length()])
	if frames == 181:
		quit()
	return false
