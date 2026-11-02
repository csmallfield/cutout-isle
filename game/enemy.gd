# Enemy base: a tiny state machine (idle -> notice -> approach -> attack ->
# recover, with stagger and KO), a hurtbox the hero's sword hits, a hitbox
# for its own attacks, knockback along the blow, a rate-limited flash, and a
# respawn. Everything runs on the enemy's own MotionClock (a child of the
# world clock), so a hit-stop freezes it with the hero.
# Steering is direct (toward the target, sliding along walls, pushed apart
# from other enemies): enough for an open island chunk; a NavigationAgent3D
# is the step up once the map has corridors.
# Subclasses build the visual (_build_visual) and pose it (_pose), and
# decide how an attack moves and when it hurts (_attack_update).
class_name Enemy
extends CharacterBody3D

enum State { IDLE, NOTICE, APPROACH, ATTACK, RECOVER, STAGGER, KO }

@export var max_hp := 3.0
@export var speed := 2.4
@export var notice_range := 6.0
@export var lose_range := 10.0
@export var attack_range := 1.2
@export var respawn_time := 7.0
## The cue its hits make on it (hit.flesh, hit.metal...).
@export var hit_cue := &"hit.flesh"

var clock: MotionClock
var look: Look
var target: Node3D
var hp := 3.0
var state := State.IDLE
var spawn := Vector3.ZERO
var _state_t := 0.0                 # local seconds in this state
var _knock := Vector3.ZERO
var _flash_ok := true
var hurtbox: Area3D
var hitbox: Area3D
var _hit_hero_this_attack := false
var _shadow: MeshInstance3D
var _onscreen: VisibleOnScreenNotifier3D


func setup(p_look: Look, world: MotionClock, p_target: Node3D, at: Vector3) -> void:
	look = p_look
	clock = MotionClock.new(world)
	target = p_target
	spawn = at
	position = at
	hp = max_hp
	add_to_group(&"enemies")
	add_to_group(&"lookable")
	collision_layer = 1 << 2
	collision_mask = 1 | (1 << 2)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = 0.8
	cs.shape = cyl
	cs.position.y = 0.4
	add_child(cs)
	hurtbox = Area3D.new()
	hurtbox.collision_layer = 1 << 4
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var hs := CollisionShape3D.new()
	var hc := CylinderShape3D.new()
	hc.radius = 0.4
	hc.height = 1.0
	hs.shape = hc
	hs.position.y = 0.5
	hurtbox.add_child(hs)
	add_child(hurtbox)
	hitbox = Area3D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1 << 6              # the hero's hurtbox
	hitbox.monitorable = false
	var ks := CollisionShape3D.new()
	var ksp := SphereShape3D.new()
	ksp.radius = 0.45
	ks.shape = ksp
	hitbox.add_child(ks)
	add_child(hitbox)
	_shadow = look.ground_decal(look.blob_uv, Vector2(0.38, 0.24), Color(0.1, 0.12, 0.2, 0.55))
	_shadow.position.y = 0.01
	add_child(_shadow)
	_onscreen = VisibleOnScreenNotifier3D.new()
	_onscreen.aabb = AABB(Vector3(-0.8, 0, -0.8), Vector3(1.6, 1.8, 1.6))
	add_child(_onscreen)
	_build_visual()


# --- for subclasses
func _build_visual() -> void:
	pass


func _pose(_dt: float) -> void:
	pass


## Movement and hurting during ATTACK; return true when the attack is over.
func _attack_update(_dt: float) -> bool:
	return true


func _set_flash(_amount: float) -> void:
	pass


## True while it is fighting (the music follows this).
func is_engaged() -> bool:
	return state in [State.NOTICE, State.APPROACH, State.ATTACK, State.RECOVER, State.STAGGER]


func is_alive() -> bool:
	return state != State.KO


func _go(s: State) -> void:
	state = s
	_state_t = 0.0
	clock.mark(StringName(State.keys()[s].to_lower()))
	if s == State.ATTACK:
		_hit_hero_this_attack = false


# ------------------------------------------------------------------ being hit

## Called by the hero's hitbox: info = {dir, power, attacker, point, move}.
func take_hit(info: Dictionary) -> void:
	if state == State.KO:
		return
	var dir: Vector3 = info.dir
	var power: float = info.get("power", 1.0)
	hp -= power
	_flash_ok = clock.count(&"hit", 1.0) < 3
	clock.mark(&"hit", info)
	_knock = dir * (2.6 + 1.6 * power)
	GameEvents.emit(hit_cue, info.get("point", global_position + Vector3(0, 0.5, 0)), clampf(power / 1.6, 0.3, 1.0), {target = self, dir = dir})
	if hp <= 0.0:
		_go(State.KO)
		GameEvents.emit(&"enemy.ko", global_position, 1.0, {target = self})
		GameEvents.emit(&"damage_number", info.get("point", global_position), power, {ko = true})
	else:
		_go(State.STAGGER)
		GameEvents.emit(&"damage_number", info.get("point", global_position), power, {})


# ------------------------------------------------------------------ brain and body

func _physics_process(delta: float) -> void:
	var t := MotionPerfProbe.begin()
	var r := clock.rate()
	var dt := delta * r
	_state_t += dt
	var to := Vector3.ZERO
	var dist := INF
	if target and is_instance_valid(target):
		to = target.global_position - global_position
		to.y = 0.0
		dist = to.length()
	var want := Vector3.ZERO
	match state:
		State.IDLE:
			if dist < notice_range and _target_alive():
				_go(State.NOTICE)
				GameEvents.emit(&"enemy.alert", global_position + Vector3(0, 1.0, 0), 1.0, {source = self})
		State.NOTICE:
			if _state_t > 0.45:
				_go(State.APPROACH)
		State.APPROACH:
			if dist > lose_range or not _target_alive():
				_go(State.IDLE)
			elif dist < attack_range:
				_go(State.ATTACK)
			elif _walks():
				want = to.normalized() * speed
		State.ATTACK:
			if _attack_update(dt):
				_go(State.RECOVER)
		State.RECOVER:
			if _state_t > 0.55:
				_go(State.APPROACH)
		State.STAGGER:
			if _state_t > 0.38:
				_go(State.APPROACH)
		State.KO:
			if _state_t > respawn_time:
				_respawn()
	if state in [State.APPROACH, State.ATTACK]:
		want += _separation() * 1.5
	_knock = _knock.lerp(Vector3.ZERO, 1.0 - exp(-dt * 9.0))
	if state == State.KO:
		want = Vector3.ZERO
	velocity = (want + _knock + _attack_velocity()) * r
	if r > 0.0 and state != State.KO:
		move_and_slide()
		velocity /= r
	MotionPerfProbe.end(&"enemies.brain", t)


## False for enemies that move some other way (hops).
func _walks() -> bool:
	return true


## Extra velocity from the attack (a lunge, a hop), in units per second.
func _attack_velocity() -> Vector3:
	return Vector3.ZERO


func _process(delta: float) -> void:
	var t := MotionPerfProbe.begin()
	clock.tick(delta)
	var f := clock.frames_since(&"hit")
	var fl := 0.0
	if Tune.get_or_default().flash and _flash_ok and f < 6.0 and state != State.KO:
		fl = 0.75 * exp(-f / 1.6)
	_set_flash(fl)
	_shadow.visible = state != State.KO or clock.since(&"ko") < 0.25
	# off screen: no posing (the brain and body still run in _physics_process)
	if _onscreen.is_on_screen() or Engine.get_frames_drawn() < 2:
		_pose(clock.dt)
	MotionPerfProbe.end(&"enemies.pose", t)


## Hurt the hero if the hitbox overlaps it (once per attack).
func _try_hit_hero(power := 1.0) -> void:
	if _hit_hero_this_attack:
		return
	for area in hitbox.get_overlapping_areas():
		var hero := area.get_parent()
		if hero and hero.has_method(&"take_damage"):
			var dir: Vector3 = hero.global_position - global_position
			dir.y = 0.0
			hero.take_damage({dir = dir.normalized() if dir.length() > 0.01 else Vector3.BACK, power = power, attacker = self})
			_hit_hero_this_attack = true
			return


func _target_alive() -> bool:
	return target != null and (not ("hp" in target) or int(target.hp) > 0)


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e == self or not (e as Enemy).is_alive():
			continue
		var d: Vector3 = global_position - (e as Node3D).global_position
		d.y = 0.0
		var l := d.length()
		if l < 1.0 and l > 1e-3:
			push += d / l * (1.0 - l)
	return push


func _respawn() -> void:
	global_position = spawn
	reset_physics_interpolation()
	hp = max_hp
	_knock = Vector3.ZERO
	_go(State.IDLE)
	clock.mark(&"spawn")
