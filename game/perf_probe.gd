# Per-system script timing for the debug overlay: wrap a system's work in
# `var t := PerfProbe.begin()` ... `PerfProbe.end(&"name", t)`. Averages and
# maxima are over the last 120 frames. In the cloud (software GL on shared
# cores) these are CPU script costs only, never GPU or frame-rate claims.
class_name PerfProbe
extends RefCounted

const WINDOW := 120

static var _acc := {}      # name -> usec this frame
static var _hist := {}     # name -> PackedFloat64Array (ring of frame totals)
static var _i := 0
static var worst_frame_ms := 0.0      # since start (or reset)
static var _last_usec := -1


static func begin() -> int:
	return Time.get_ticks_usec()


static func end(name: StringName, t0: int) -> void:
	_acc[name] = int(_acc.get(name, 0)) + Time.get_ticks_usec() - t0


## Close the frame (the overlay calls this last in the frame).
static func end_frame() -> void:
	var now := Time.get_ticks_usec()
	if _last_usec >= 0:
		worst_frame_ms = maxf(worst_frame_ms, (now - _last_usec) * 0.001)
	_last_usec = now
	for name in _acc.keys() + _hist.keys():
		if not _hist.has(name):
			var a := PackedFloat64Array()
			a.resize(WINDOW)
			_hist[name] = a
		var h: PackedFloat64Array = _hist[name]
		h[_i] = float(_acc.get(name, 0))
		_hist[name] = h
	_acc.clear()
	_i = (_i + 1) % WINDOW


static func reset_worst() -> void:
	worst_frame_ms = 0.0


## {name: Vector2(avg_us, max_us)} over the window.
static func stats() -> Dictionary:
	var out := {}
	for name in _hist:
		var h: PackedFloat64Array = _hist[name]
		var s := 0.0
		var m := 0.0
		for v in h:
			s += v
			m = maxf(m, v)
		out[name] = Vector2(s / WINDOW, m)
	return out
