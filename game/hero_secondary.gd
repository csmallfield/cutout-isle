# The hero's secondary motion: a scarf (two verlet tails drawn as outlined
# ribbons) and a dangling belt pouch, simulated in the cutout's card plane
# (the flip node's space) so they mirror and paper-turn with the views, plus
# squash and stretch on the whole cutout.
#   chains   MotionChain at the physics rate on the hero's clock (or on
#            real time through a hit-stop, Tune.chain_flow); air drag
#            against the body's velocity seen in the card plane, frame
#            acceleration, a little wind
#   squash   the move's authored squash channel over a MotionSquash spring
#            (a slight stretch when running)
class_name HeroSecondary
extends Node

## Per view: where the scarf tails and the pouch hang from (SVG units), how
## far in front of (+) or behind (-) the cards they draw, and the scarf's
## rest direction (card plane).
const SCARF := {
	&"front": {root = Vector2(126, 192), z = -0.004, dir = Vector3(0.35, -1.0, 0.0)},
	&"side": {root = Vector2(90, 186), z = -0.004, dir = Vector3(-1.0, -0.5, 0.0)},
	&"back": {root = Vector2(116, 190), z = 0.22, dir = Vector3(0.2, -1.0, 0.0)},
}
const POUCH := {
	&"front": {root = Vector2(68, 250), z = 0.22},
	&"side": {root = Vector2(88, 250), z = 0.22},
	&"back": {root = Vector2(152, 250), z = 0.22},
}

var hero: Hero
var scarf_a := MotionChain.new(9, 0.034)
var scarf_b := MotionChain.new(7, 0.032)
var pouch := MotionChain.new(3, 0.028)
var squash := MotionSquash.new(8.0, 240.0)
var _ribbon_a := MotionRibbon3D.new()
var _ribbon_b := MotionRibbon3D.new()
var _cord := MotionRibbon3D.new()
var _pouch_card: MeshInstance3D
var _last_v := Vector3.ZERO
var _wind_t := 0.0


func setup(p_hero: Hero) -> void:
	hero = p_hero
	var look := hero.look
	for c: MotionChain in [scarf_a, scarf_b]:
		c.drag = 3.2
		c.damping = 0.06
		c.stiffness = 0.12
		c.gravity = Vector3(0, -4.5, 0)       # card metres are small; a lighter pull reads better
	pouch.drag = 1.2
	pouch.damping = 0.08
	pouch.gravity = Vector3(0, -9.8, 0)
	for r: MotionRibbon3D in [_ribbon_a, _ribbon_b]:
		r.material_override = look.cutout
		r.color = Color("#d8433b")
		r.outline = 0.0045
		r.outline_color = Look.INK
	_ribbon_a.width_from = 0.05
	_ribbon_a.width_to = 0.03
	_ribbon_b.width_from = 0.04
	_ribbon_b.width_to = 0.024
	_ribbon_b.color = Color("#c23a33")
	_cord.material_override = look.cutout
	_cord.color = Color("#5b3a26")
	_cord.width_from = 0.008
	_cord.width_to = 0.008
	_cord.outline = 0.0
	_pouch_card = Cutout.card(look, "res://art/pouch.svg", 0.07, Vector2(0.5, 4.0 / 44.0))
	for n in [_ribbon_a, _ribbon_b, _cord, _pouch_card]:
		hero.cut.flip.add_child(n)
	hero.cut.view_changed.connect(on_view)
	on_view(hero.cut.view, hero.cut.mirrored, true)


## Re-root the chains on a view change; mirror them when the side flips.
func on_view(view: StringName, mirrored: bool, first := false) -> void:
	var sc: Dictionary = SCARF[view]
	var pc: Dictionary = POUCH[view]
	for c: MotionChain in [scarf_a, scarf_b]:
		var d: Vector3 = sc.dir
		for i in c.rest_dirs.size():
			c.rest_dirs[i] = d.normalized()
	if first:
		scarf_a.teleport(_root(sc.root))
		scarf_b.teleport(_root(sc.root + Vector2(-6, 2)))
		pouch.teleport(_root(pc.root))
	elif _mirrored_last != mirrored:
		for c: MotionChain in [scarf_a, scarf_b, pouch]:
			c.mirror_x()
	_mirrored_last = mirrored
	_ribbon_a.position.z = sc.z
	_ribbon_b.position.z = sc.z - 0.002
	_cord.position.z = pc.z
	_pouch_card.position.z = pc.z + 0.002

var _mirrored_last := false


## A point given in SVG units of the view showing, riding the torso (lean,
## bob), in the card plane.
func _root(svg: Vector2) -> Transform3D:
	var rig := hero.cut.rig
	var torso: StringName = rig.parent_of[&"arm_r_upper"]
	var local := rig.svg_to_local(svg) - rig.rest_pivot(torso)
	return Transform3D(Basis(), rig.rig_transform(torso) * local)


func physics(delta: float, rate: float) -> void:
	var t := PerfProbe.begin()
	var tune := Tune.get_or_default()
	var dt := delta * (1.0 if tune.chain_flow else rate)
	if not tune.chains:
		dt = 0.0
	# the body's motion as the card plane sees it
	var v := hero.cut.ground_to_card(hero.velocity)
	var a := (v - _last_v) / maxf(delta, 1e-6) if dt > 0.0 else Vector3.ZERO
	if dt > 0.0:
		_last_v = v
	_wind_t += dt
	var wind := Vector3(sin(_wind_t * 1.3) * 0.35 + sin(_wind_t * 3.1) * 0.15, 0.1, 0.0)
	var view := hero.cut.view
	var sc: Dictionary = SCARF[view]
	for c: MotionChain in [scarf_a, scarf_b]:
		c.medium_velocity = wind - v
		c.frame_accel = a.limit_length(30.0)
	pouch.medium_velocity = -v
	pouch.frame_accel = a.limit_length(30.0)
	scarf_a.step(dt, _root(sc.root))
	scarf_b.step(dt, _root(sc.root + Vector2(-6, 2)))
	pouch.step(dt, _root((POUCH[view] as Dictionary).root))
	PerfProbe.end(&"chains", t)


func render(frac: float, move_squash: float, run: float) -> void:
	var t := PerfProbe.begin()
	var tune := Tune.get_or_default()
	_ribbon_a.update(scarf_a.render_points(frac))
	_ribbon_b.update(scarf_b.render_points(frac))
	var pp := pouch.render_points(frac)
	_cord.update(pp)
	var n := pp.size()
	var dir := pp[n - 1] - pp[n - 2]
	_pouch_card.position = Vector3(pp[n - 1].x, pp[n - 1].y, _pouch_card.position.z)
	_pouch_card.rotation.z = atan2(dir.y, dir.x) + PI * 0.5

	# squash: the move's authored squash on top of a spring (stretch when running)
	squash.bias = 0.03 * run
	squash.step(hero.clock.dt)
	var s := MotionSquash.scale_for(clampf(squash.amount() + move_squash, -0.4, 0.4)) if tune.hero_squash else Vector2.ONE
	hero.cut.scale = Vector3(s.x, s.y, 1.0)
	PerfProbe.end(&"secondary", t)
