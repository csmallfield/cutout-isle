# Live procedural sound (audio kit), driven by GameEvents.
#   one-shots   the cue map in audio/ (tools/make_sound.py), placed in 3D
#               (trigger_at) and pooled: every frequent cue has a few takes
#               rendered at load, picked without repeats at the nearest
#               intensity, so nothing renders on the frame of an event
#   voices      sea wash (a looped recipe, rate drifting), wind (filtered
#               noise with gusts), the charge riser (pitch and level follow
#               the hero's charge), a low-health drone plus heartbeat
#   music       "Isle": explore and combat sections queued on the bar from
#               how recently a hit landed; ducks under the effects
# Without the native core (no LIVE), it falls back to AudioStreamPlayer3Ds
# playing AKRecipeStream variants: one-shots only, no voices or music.
class_name Sound
extends Node

const MAP := preload("res://audio/cue_map.tres")
const SONG := preload("res://audio/music/isle_song.tres")
const SEA := preload("res://audio/sfx/sea_wash.tres")
## Pools: cue -> variants, or [variants, intensity steps].
const POOLS := {
	"swing": [8, 3], "swing.charge": 4, "hit.wood": [6, 3], "hit.flesh": [6, 3], "hit.metal": [4, 2], "block": 4,
	"step.grass": [10, 3], "step.stone": [10, 3], "step.sand": [8, 3], "step.wood": [10, 3],
	"dash": 4, "land": [4, 2], "pickup": 3, "enemy.alert": 4, "enemy.ko": 4, "charge.full": 3, "heart": 2,
}
## Seconds after the last hit before the music drops back to exploring.
@export var combat_hold := 6.0

var player: AKLivePlayer
var ok := false
var hero: Node3D
var island: Node
var load_ms := 0.0

var _sea := -1
var _wind := -1
var _riser := -1
var _drone := -1
var _gust_t := 0.0
var _last_hit := -1e9
var _section := "explore"
var _heart_t := 0.0
var _fallback: Array[AudioStreamPlayer3D] = []
var _fallback_streams := {}


func _ready() -> void:
	var t0 := Time.get_ticks_usec()
	player = AKLivePlayer.new()
	player.name = "Live"
	player.cue_map = MAP
	player.unit_size = 6.0
	player.max_distance = 60.0
	player.follow_reverb_zones = true
	player.song = SONG
	player.song_follow = "loop"
	var pools := {}
	for cue in POOLS:
		var spec: Variant = POOLS[cue]
		pools[cue] = {variants = spec[0], intensity_steps = spec[1]} if spec is Array else spec
	player.pools = pools
	add_child(player)
	ok = player.live != null
	if ok:
		player.song_play(SONG, "explore")
		_start_voices()
	else:
		push_warning("Sound: the audio kit's native core isn't loaded; one-shots only, no voices or music (run tools/setup)")
		_make_fallback()
	load_ms = (Time.get_ticks_usec() - t0) * 0.001
	print("Sound: %s ready in %.0f ms" % ["live mixer, pools, voices and music" if ok else "fallback players", load_ms])
	GameEvents.event.connect(_on_event)


func _start_voices() -> void:
	var live := player.live
	_sea = live.loop_start(SEA, {gain = 0.35, send = 0.25, rate = 1.0, attack_s = 2.0})
	_wind = live.voice_start({shape = "noise", gain = 0.0, cutoff_hz = 500.0, q = 1.6, send = 0.15, attack_s = 1.0})
	_riser = live.voice_start({shape = "saw", freq_hz = 110.0, gain = 0.0, cutoff_hz = 600.0, q = 3.0, noise = 0.15, send = 0.25, attack_s = 0.05})
	_drone = live.voice_start({shape = "triangle", freq_hz = 55.0, gain = 0.0, cutoff_hz = 300.0, q = 0.8, send = 0.1, attack_s = 0.5})


func _on_event(name: StringName, pos: Vector3, intensity: float, _data: Dictionary) -> void:
	if String(name).begins_with("hit."):
		_last_hit = Time.get_ticks_msec() * 0.001
	if not Tune.get_or_default().sound or MAP.recipe_for(name) == null:
		return                          # game events without a sound (area, damage_number...)
	var t := MotionPerfProbe.begin()
	if ok:
		player.trigger_at(name, pos, intensity)
	else:
		_fallback_play(name, pos, intensity)
	MotionPerfProbe.end(&"sound", t)


func _process(delta: float) -> void:
	if not ok:
		return
	var t := MotionPerfProbe.begin()
	var live := player.live
	var on := Tune.get_or_default().sound
	# sea: a slow drift in rate (the waves' pitch), wind: gusts
	var now := Time.get_ticks_msec() * 0.001
	live.voice_set(_sea, "rate", 0.92 + 0.08 * sin(now * 0.21) + 0.04 * sin(now * 0.53), 0.5)
	live.voice_set(_sea, "gain", 0.35 if on else 0.0, 0.5)
	_gust_t -= delta
	if _gust_t <= 0.0:
		_gust_t = randf_range(2.5, 6.0)
		live.voice_set(_wind, "gain", randf_range(0.02, 0.07) if on else 0.0, _gust_t * 0.5)
		live.voice_set(_wind, "cutoff_hz", randf_range(350.0, 1100.0), _gust_t * 0.6)
	# the charge riser and low health, from the hero
	if hero:
		var charge: float = hero.charge_ratio() if hero.has_method(&"charge_ratio") else 0.0
		live.voice_set(_riser, "gain", 0.11 * charge if on else 0.0, 0.06)
		live.voice_set(_riser, "freq_hz", lerpf(110.0, 330.0, charge * charge), 0.06)
		live.voice_set(_riser, "cutoff_hz", lerpf(500.0, 3200.0, charge), 0.06)
		var hp: int = hero.get("hp") if "hp" in hero else 99
		var low := hp <= 2 and hp > 0
		live.voice_set(_drone, "gain", (0.12 if hp <= 1 else 0.07) if low and on else 0.0, 0.8)
		if low and on:
			_heart_t -= delta
			if _heart_t <= 0.0:
				_heart_t = 0.62 if hp <= 1 else 0.85
				player.trigger(&"heart", 1.0)
	# music: combat while hits keep landing, explore after a quiet spell
	var engaged := false
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e.is_engaged():
			engaged = true
			break
	var want := "combat" if engaged or now - _last_hit < combat_hold * 0.5 else "explore"
	if want != _section:
		_section = want
		player.song_queue(want, &"bar")
	MotionPerfProbe.end(&"sound", t)


# ------------------------------------------------------------------ fallback (no native core)

func _make_fallback() -> void:
	for i in 12:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 6.0
		p.max_distance = 60.0
		add_child(p)
		_fallback.append(p)
	for cue in MAP.sounds:
		var s := AKRecipeStream.of(MAP.sounds[cue])
		s.warm()
		_fallback_streams[cue] = s


func _fallback_play(name: StringName, pos: Vector3, intensity: float) -> void:
	var s: AudioStream = _fallback_streams.get(String(name))
	if s == null:
		return
	var p := _fallback[0]
	for c in _fallback:
		if not c.playing:
			p = c
			break
	p.stream = s
	p.global_position = pos
	p.volume_db = linear_to_db(clampf(0.3 + 0.7 * intensity, 0.05, 1.0))
	p.play()
