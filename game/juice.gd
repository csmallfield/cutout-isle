# Combat feedback in one place, driven by GameEvents: hit-stop (per entity
# or global, from Tune), camera trauma and a kick along the blow. Reactions
# that belong to an actor (wobble, squash, flash, ring) live on the actor;
# this only does what spans actors.
class_name Juice
extends Node

var world: MotionClock
var rig: CameraRig


func setup(p_world: MotionClock, p_rig: CameraRig) -> void:
	world = p_world
	rig = p_rig
	GameEvents.event.connect(_on_event)


func _on_event(name: StringName, pos: Vector3, intensity: float, data: Dictionary) -> void:
	if not String(name).begins_with("hit."):
		return
	var tune := Tune.get_or_default()
	var target: Node = data.get("target")
	var dir: Vector3 = data.get("dir", Vector3.ZERO)
	if tune.hitstop:
		var hold := tune.hitstop_hold * lerpf(0.7, 1.2, intensity)
		if tune.per_entity:
			for n in [target, _attacker_of(target)]:
				if n and "clock" in n and n.clock:
					(n.clock as MotionClock).freeze(hold, tune.hitstop_ease)
		else:
			world.freeze(hold, tune.hitstop_ease)
	rig.hit(rig.screen_dir(pos, dir), 0.28 * intensity)


func _attacker_of(target: Node) -> Node:
	if target and "clock" in target:
		var info: Dictionary = (target.clock as MotionClock).last_data(&"hit")
		return info.get("attacker")
	return null
