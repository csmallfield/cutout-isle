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
	else:
		var a := t * 1.4
		if cos(a) < -0.3: Input.action_press(&"move_left")
		if cos(a) > 0.3: Input.action_press(&"move_right")
		if sin(a) < -0.3: Input.action_press(&"move_up")
		if sin(a) > 0.3: Input.action_press(&"move_down")
		if fmod(t, 0.7) < 0.02:
			_tap()


func _tap() -> void:
	var e := InputEventAction.new()
	e.action = &"attack"
	e.pressed = true
	Input.parse_input_event(e)


func _untap() -> void:
	var e := InputEventAction.new()
	e.action = &"attack"
	e.pressed = false
	Input.action_release(&"attack")
	Input.parse_input_event(e)


func _release() -> void:
	for a in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(a)
