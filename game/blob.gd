# The hopping blob: moves only in hops (a squash before take-off, a stretch
# in the air, a squash on landing, all from frames since the hop on its
# clock), attacks with a lunging hop and hurts on landing. One cutout card.
class_name Blob
extends Enemy

const ART := "res://art/blob.svg"
const HOP_TIME := 0.42
const HOP_HEIGHT := 0.45

var _card: Node3D
var _mesh: MeshInstance3D
var _hop_dir := Vector3.ZERO
var _hop_speed := 0.0
var _airborne := false
var _wait := 0.0


func _build_visual() -> void:
	max_hp = 2.4
	hp = max_hp
	speed = 2.6
	attack_range = 1.9
	_card = Node3D.new()
	_card.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_card)
	_mesh = MotionCutoutRig.card(MotionSvgData.load_any(ART), 0.62, look.cutout, look.card_edges, Vector2(0.5, 96.0 / 100.0))
	_card.add_child(_mesh)


func _set_flash(a: float) -> void:
	MotionFlat3D.set_flash(_mesh, Color("#fff4d8"), a)


# Hops replace walking: the base class asks for a velocity; a blob only
# moves while in the air, in the direction it chose at take-off.
func _physics_process(delta: float) -> void:
	var dt := delta * clock.rate()
	if state == State.APPROACH or state == State.IDLE:
		_wait -= dt
		if not _airborne and _wait <= 0.0 and (state == State.APPROACH or MK.rand(Time.get_ticks_msec() * 0.001) < 0.02):
			var to := (target.global_position - global_position) if target else Vector3.ZERO
			to.y = 0.0
			_hop(to.normalized() if state == State.APPROACH else Vector3(cos(spawn.x + clock.time), 0, sin(clock.time)).normalized(),
				speed if state == State.APPROACH else speed * 0.4)
	_update_hop()
	super._physics_process(delta)


func _hop(dir: Vector3, spd: float) -> void:
	_hop_dir = dir
	_hop_speed = spd
	_airborne = true
	clock.mark(&"hop")


func _update_hop() -> void:
	if _airborne and clock.since(&"hop") >= HOP_TIME:
		_airborne = false
		clock.mark(&"land")
		_wait = 0.35
		if state == State.ATTACK:
			_try_hit_hero(1.0)
		GameEvents.emit(&"land", global_position, 0.35, {source = self})


func _attack_velocity() -> Vector3:
	return _hop_dir * _hop_speed if _airborne and state != State.KO and state != State.STAGGER else Vector3.ZERO


# Hops do the moving.
func _walks() -> bool:
	return false


func _separation() -> Vector3:
	return Vector3.ZERO


var _lunged := false


func _attack_update(_dt: float) -> bool:
	hitbox.position = Vector3(0, 0.3, 0)
	if _state_t < 0.3:                 # a crouch that telegraphs the lunge
		_lunged = false
		return false
	if not _lunged:
		if _airborne:
			return false
		_lunged = true
		var to := target.global_position - global_position
		to.y = 0.0
		_hop(to.normalized(), 4.2)
		return false
	return not _airborne               # over when it lands


func _pose(_dt: float) -> void:
	var tune := Tune.get_or_default()
	var y := 0.0
	var amount := 0.0
	if state == State.KO:
		var k := clock.since(&"ko")
		_card.visible = k < 0.25
		_card.scale = Vector3.ONE * (1.0 + k * 2.0) * (1.0 - k * 4.0)
		return
	_card.visible = true
	var hop_t := clock.since(&"hop")
	if _airborne:
		var u := clampf(hop_t / HOP_TIME, 0.0, 1.0)
		y = sin(PI * u) * HOP_HEIGHT * (1.4 if state == State.ATTACK else 1.0)
		amount = 0.22 * (1.0 - u) - 0.05          # stretched on the way up
	else:
		amount = MotionSquash.land(clock.frames_since(&"land"), -0.3)
		if state == State.ATTACK and _state_t < 0.4:
			amount = -0.25 * clampf(_state_t / 0.3, 0.0, 1.0)     # the crouch
		amount += sin(clock.time * 5.0) * 0.02             # breathing
	if not tune.squash:
		amount = 0.0
	if clock.frames_since(&"hit") < 8.0:
		amount += MotionSquash.land(clock.frames_since(&"hit"), -0.25)
	var s := MotionSquash.scale_for(amount)
	_card.position = Vector3(0, y, 0)
	_card.rotation = Vector3(-deg_to_rad(28.0), 0, 0)
	_card.scale = Vector3(s.x, s.y / cos(deg_to_rad(50.0 - 28.0)), 1.0)
	_shadow.scale = Vector3.ONE * (1.0 - y * 0.8)
