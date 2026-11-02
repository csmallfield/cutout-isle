# Scripted input for captures and the CPU-cost bench (run with
# `-- --autoplay`): a 3-hit combo and a charged swing on the dummy, then a
# simple bot that fights the nearest enemy, walks the path to the cave
# mouth, goes in and fights there. Deterministic enough to compare runs.
extends Node

var _f := 0
var _hero: Hero


func _ready() -> void:
	_hero = get_parent().get_node("Hero") as Hero


func _physics_process(_delta: float) -> void:
	_f += 1
	var t := _f / 60.0
	_release()
	if t < 0.3:
		_stick(Vector3(1, 0, 0.3))
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
	elif t < 15.0:
		_fight(14.0)
	elif t < 24.0:                     # to the cave: along the path to the mouth
		if _hero.global_position.z > -60.0:
			_go_to(Island.CAVE_MOUTH + Vector3(0, 0, 0.4))
		else:
			_fight(12.0)
	else:
		_fight(12.0)


## Walk to the nearest live enemy within `reach` and swing when close.
func _fight(reach: float) -> void:
	var best: Node3D = null
	var bd := reach
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e as Enemy).is_alive():
			continue
		var d := (e as Node3D).global_position.distance_to(_hero.global_position)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	var to := best.global_position - _hero.global_position
	to.y = 0.0
	if to.length() > 1.05:
		_stick(to)
	else:
		_stick(to * 0.05)
		if _f % 13 == 0:
			_tap()


func _go_to(p: Vector3) -> void:
	var to := p - _hero.global_position
	to.y = 0.0
	if to.length() > 0.2:
		_stick(to)


func _stick(dir: Vector3) -> void:
	var d := Vector2(dir.x, dir.z)
	if d.length() < 1e-4:
		return
	d = d.normalized() * minf(1.0, maxf(dir.length(), 0.35) * 1.5 if dir.length() < 0.3 else 1.0)
	if d.x > 0.0:
		Input.action_press(&"move_right", d.x)
	else:
		Input.action_press(&"move_left", -d.x)
	if d.y > 0.0:
		Input.action_press(&"move_down", d.y)
	else:
		Input.action_press(&"move_up", -d.y)


func _tap(action := &"attack") -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _untap() -> void:
	var e := InputEventAction.new()
	e.action = &"attack"
	e.pressed = false
	Input.action_release(&"attack")
	Input.parse_input_event(e)


func _release() -> void:
	for a in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(a)
