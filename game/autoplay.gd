# Scripted input for captures and the CPU-cost bench (run with
# `-- --autoplay`): walks to the dummy, swings on a rhythm, walks around it
# and swings from the other side, then circles. Deterministic per frame.
extends Node

var _f := 0


func _physics_process(_delta: float) -> void:
	_f += 1
	var t := _f / 60.0
	_release()
	if t < 0.3:
		Input.action_press(&"move_right")
	elif t < 2.2:
		if fmod(t, 0.22) < 0.02:       # mash: the 3-hit combo
			_tap()
	elif t < 2.6:
		pass
	elif t < 4.0:                      # press and hold: a swing, then charge and release
		if t < 2.62:
			_tap()
		if t < 3.7:
			Input.action_press(&"attack")
		elif t < 3.72:
			_untap()
	elif t < 5.4:
		Input.action_press(&"move_down")
		if t > 4.5:
			Input.action_press(&"move_right")
	elif t < 6.4:
		Input.action_press(&"move_up")
	elif t < 9.0:
		Input.action_press(&"move_left")
		if fmod(t, 0.5) < 0.02:
			_tap()
	elif t < 11.0:                      # the stone path, then into the sand (placed there: a test drive)
		if absf(t - 9.02) < 0.01:
			_place(Vector3(-1.5, 0, 2.6))
		Input.action_press(&"move_left")
		if t > 10.2:
			Input.action_press(&"move_down")
	elif t < 13.8:                      # a dash, then across the wooden deck
		if absf(t - 11.02) < 0.01:
			_place(Vector3(2.4, 0, -0.4))
		Input.action_press(&"move_right")
		if absf(t - 11.3) < 0.01 or absf(t - 12.6) < 0.01:
			_tap(&"dash")
	else:
		var a := t * 1.4
		if cos(a) < -0.3: Input.action_press(&"move_left")
		if cos(a) > 0.3: Input.action_press(&"move_right")
		if sin(a) < -0.3: Input.action_press(&"move_up")
		if sin(a) > 0.3: Input.action_press(&"move_down")
		if fmod(t, 0.7) < 0.02:
			_tap()


func _tap(action := &"attack") -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _place(p: Vector3) -> void:
	var hero := get_parent().get_node_or_null("Hero") as Node3D
	if hero:
		hero.global_position = p
		hero.reset_physics_interpolation()


func _untap() -> void:
	var e := InputEventAction.new()
	e.action = &"attack"
	e.pressed = false
	Input.action_release(&"attack")
	Input.parse_input_event(e)


func _release() -> void:
	for a in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(a)
