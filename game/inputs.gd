# Input actions, registered in code so the project file stays readable.
# Keyboard (WASD / arrows, J or Space to attack, K or Shift to dash) and
# gamepad (left stick, X / Square to attack, A / Cross to dash).
class_name Inputs
extends RefCounted


static func ensure() -> void:
	_action(&"move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_action(&"move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_action(&"move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action(&"move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action(&"attack", [_key(KEY_J), _key(KEY_SPACE), _button(JOY_BUTTON_X)])
	_action(&"dash", [_key(KEY_K), _key(KEY_SHIFT), _button(JOY_BUTTON_A)])


static func _action(name: StringName, events: Array) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name, 0.2)
	for e in events:
		InputMap.action_add_event(name, e)


static func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e


static func _axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	return e


static func _button(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e
