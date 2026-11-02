# Debug overlay (F1): frame timing, draw calls, per-system script cost
# (PerfProbe), and switches for every procedural layer (Tune). Runs last in
# the frame so it closes PerfProbe's frame.
#   F1 overlay   F2 time scale (1, 0.5, 0.25)   F3 per-entity / global hit-stop
#   1 hit-stop  2 shake  3 kick  4 wobble  5 squash  6 flash  7 ring
#   8 sound  9 bob  0 paper turn  -  smear  C chains  H chains flow
#   through hit-stop  Q hero squash   R reset worst frame
extends CanvasLayer

var _label: Label
var _scales := [1.0, 0.5, 0.25]
var _si := 0
var _since_start := 0.0
var native_ok := false

const KEYS := {
	KEY_1: "hitstop", KEY_2: "shake", KEY_3: "kick", KEY_4: "wobble", KEY_5: "squash",
	KEY_6: "flash", KEY_7: "rings", KEY_8: "sound", KEY_9: "bob", KEY_0: "paper_turn", KEY_MINUS: "smear",
	KEY_C: "chains", KEY_H: "chain_flow", KEY_Q: "hero_squash",
}


func _ready() -> void:
	layer = 100
	process_priority = 10000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override(&"font_size", 15)
	_label.add_theme_color_override(&"font_color", Color("#fffbe8"))
	_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override(&"shadow_offset_x", 1)
	_label.add_theme_constant_override(&"shadow_offset_y", 1)
	add_child(_label)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var tune := Tune.get_or_default()
	match k.keycode:
		KEY_F1:
			visible = not visible
		KEY_F2:
			_si = (_si + 1) % _scales.size()
			Engine.time_scale = _scales[_si]
		KEY_F3:
			tune.per_entity = not tune.per_entity
		KEY_R:
			PerfProbe.reset_worst()
		_:
			if KEYS.has(k.keycode):
				var prop: String = KEYS[k.keycode]
				tune.set(prop, not tune.get(prop))


func _process(delta: float) -> void:
	_since_start += delta
	PerfProbe.end_frame()
	if _since_start < 2.0:
		PerfProbe.reset_worst()       # ignore load hitches
	if not visible:
		return
	var tune := Tune.get_or_default()
	var lines := PackedStringArray()
	lines.append("%d fps   process %.2f ms   physics %.2f ms   worst frame %.1f ms   draw calls %d" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		PerfProbe.worst_frame_ms,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	lines.append("renderer %s   time scale %.2f   hit-stop %s   sound %s" % [
		RenderingServer.get_current_rendering_method(), Engine.time_scale,
		"per entity" if tune.per_entity else "GLOBAL", "live" if native_ok else "OFF (no native core)"])
	var total := 0.0
	var st := PerfProbe.stats()
	var names := st.keys()
	names.sort()
	for n in names:
		var v: Vector2 = st[n]
		total += v.x
		lines.append("  %-12s %6.0f us avg  %6.0f max" % [n, v.x, v.y])
	lines.append("  %-12s %6.0f us avg (script, budget 2000)" % ["total", total])
	var sw := PackedStringArray()
	var order := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_C, KEY_H, KEY_Q]
	for key in order:
		var prop: String = KEYS[key]
		sw.append("%s %s%s" % [OS.get_keycode_string(key), prop, "" if tune.get(prop) else " OFF"])
	lines.append("  ".join(sw))
	lines.append("F1 overlay  F2 time scale  F3 hit-stop scope  R reset worst   move WASD / stick, attack J / Space / pad X")
	_label.text = "\n".join(lines)
