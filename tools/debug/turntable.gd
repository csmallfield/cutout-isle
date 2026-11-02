# Turntable: the hero walks a short way in each of the 8 directions in turn,
# stops and swings, so every view and every turn between views shows up in
# one capture. V in the overlay (Tune.eight_dir) compares 4 directions.
#   godot --path . --write-movie out/tt/f.png --fixed-fps 60 --quit-after 900 -s res://tools/debug/turntable.gd -- --turntable
#   add --four for 4 directions
extends SceneTree

const DIRS := [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1)]
const WALK := 32
const SLOT := 90

var frames := 0


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--four"):
		Tune.get_or_default().eight_dir = false
	change_scene_to_file("res://game/main.tscn")


func _process(_d: float) -> bool:
	if not InputMap.has_action(&"attack"):
		return false                   # the game registers its actions on load
	frames += 1
	var slot := frames / SLOT
	var f := frames % SLOT
	for a in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(a)
	if slot < 1:
		return false                   # settle
	var d: Vector2 = DIRS[(slot - 1) % DIRS.size()].normalized()
	if f < WALK:
		if d.x > 0.01: Input.action_press(&"move_right", d.x)
		if d.x < -0.01: Input.action_press(&"move_left", -d.x)
		if d.y > 0.01: Input.action_press(&"move_down", d.y)
		if d.y < -0.01: Input.action_press(&"move_up", -d.y)
	elif f == WALK + 14:
		for pressed in [true, false]:      # a tap, as an event (the hero listens for events)
			var e := InputEventAction.new()
			e.action = &"attack"
			e.pressed = pressed
			Input.parse_input_event(e)
	return false
