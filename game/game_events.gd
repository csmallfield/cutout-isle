# The game's event bus (autoload "GameEvents"): gameplay says what happened,
# once; motion, camera and sound subscribe. Names follow the motion kit's cue
# naming (dot families: hit.wood, step.grass), so a cue map's prefix rules
# apply unchanged.
extends Node

signal event(name: StringName, position: Vector3, intensity: float, data: Dictionary)


func emit(name: StringName, position: Vector3, intensity := 1.0, data := {}) -> void:
	event.emit(name, position, intensity, data)
