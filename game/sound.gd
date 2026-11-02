# Live procedural sound for the spike: an AKLivePlayer with a small cue map
# built in code, pooled so triggers render nothing on the frame of the event.
# Listens to GameEvents and places one-shots in 3D (trigger_at).
# Phase 5 replaces the recipes with a proper sound sheet and .tres files
# Chris can open in Sound Lab.
class_name Sound
extends Node

var player: AKLivePlayer
var ok := false


func _ready() -> void:
	player = AKLivePlayer.new()
	player.name = "Live"
	player.cue_map = _map()
	player.unit_size = 6.0
	player.max_distance = 60.0
	player.follow_reverb_zones = false
	player.pools = {"swing": 8, "hit.wood": {variants = 6, intensity_steps = 3}, "step.grass": {variants = 10, intensity_steps = 3}}
	var t0 := Time.get_ticks_usec()
	add_child(player)
	ok = player.live != null
	if ok:
		print("Sound: live mixer and pools ready in %.1f ms" % ((Time.get_ticks_usec() - t0) * 0.001))
	if not ok:
		push_warning("Sound: the audio kit's native core isn't loaded; the spike runs silent (run tools/setup)")
	GameEvents.event.connect(_on_event)


func _on_event(name: StringName, pos: Vector3, intensity: float, _data: Dictionary) -> void:
	if not ok or not Tune.get_or_default().sound:
		return
	var t := PerfProbe.begin()
	player.trigger_at(name, pos, intensity)
	PerfProbe.end(&"sound", t)


static func _map() -> AKCueMap:
	var m := AKCueMap.new()
	m.reverb = {room = 0.35, damp = 0.6, width = 1.0, quality = &"small", return_db = -4.0}
	# swing: an airy whoosh, a bit different every time
	var sw := AKRecipe.make(&"whoosh", {"length_s": 0.2, "low_hz": 380.0, "high_hz": 2600.0, "peak": 0.35, "shape": 2.2, "mode": "band", "q": 1.4, "noise": "pink"})
	sw.vary = {"length_s": 0.18, "high_hz": 0.22, "low_hz": 0.15, "peak": 0.2, "q": 0.25}
	sw.send = 0.12
	sw.gain_db = -6.0
	# hit.wood: a knock (click with a woody body) over a short thump
	var hit := AKRecipe.make(&"click", {"freq_hz": 900.0, "mode": "band", "q": 9.0, "decay_s": 0.05, "body_hz": 220.0, "body": 0.7})
	var thump: Array[Dictionary] = [{"voice": &"boing", "params": {"start_hz": 180.0, "end_hz": 70.0, "drop_s": 0.08, "decay_s": 0.12, "sub": 0.6, "click": 0.2}, "gain_db": -6.0}]
	hit.layers = thump
	hit.vary = {"freq_hz": 0.18, "body_hz": 0.15, "decay_s": 0.2}
	hit.bind = {"intensity": {"gain_db": [-10.0, 0.0]}}
	hit.send = 0.2
	# step.grass: a soft, dull scuff with a little weight under it
	var st := AKRecipe.make(&"click", {"freq_hz": 1400.0, "mode": "low", "q": 0.8, "attack_s": 0.004, "decay_s": 0.035, "body_hz": 110.0, "body": 0.35})
	var scuff: Array[Dictionary] = [{"voice": &"whoosh", "params": {"length_s": 0.07, "low_hz": 500.0, "high_hz": 2600.0, "peak": 0.2, "shape": 1.2, "noise": "pink"}, "gain_db": -12.0}]
	st.layers = scuff
	st.vary = {"freq_hz": 0.3, "decay_s": 0.25, "body_hz": 0.15}
	st.bind = {"intensity": {"gain_db": [-16.0, -6.0]}}
	st.send = 0.08
	m.sounds = {"swing": sw, "hit.wood": hit, "step.grass": st}
	return m
