# Switches for every procedural layer, flipped from the debug overlay, so
# each layer can be judged by turning it off.
class_name Tune
extends RefCounted

var hitstop := true
## Per-entity hit-stop (attacker and victim freeze); off = global freeze.
var per_entity := true
var hitstop_hold := 0.075
var hitstop_ease := 0.05
var shake := true
var kick := true
var wobble := true
var squash := true
var flash := true
var rings := true
var sound := true
var bob := true
var paper_turn := true
## The hero shows 8 directions (front and back 3/4 views); off = 4.
var eight_dir := true
var smear := true
var chains := true
## Chains keep moving through a hit-stop (on real time) instead of freezing.
var chain_flow := false
var hero_squash := true

static var _t: Tune


static func get_or_default() -> Tune:
	if _t == null:
		_t = Tune.new()
	return _t
