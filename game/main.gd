# Cutout Isle: the island chunk and its cave, the hero, the training dummy,
# blobs and sword grunts, the follow camera, juice, sound, the HUD and the
# debug overlay, wired to one world clock and the GameEvents bus.
extends Node3D

const PITCH := 50.0

var world := MotionClock.new()
var look: Look


func _enter_tree() -> void:
	Inputs.ensure()


func _ready() -> void:
	look = Look.new(self)

	var island := Island.new()
	island.name = "Island"
	add_child(island)
	island.setup(look)

	var hero := Hero.new()
	hero.name = "Hero"
	add_child(hero)
	hero.setup(look, world, PITCH)
	hero.position = Vector3(-3.0, 0, -0.2)
	hero._spawn = hero.position

	var dummy := Dummy.new()
	dummy.name = "Dummy"
	add_child(dummy)
	dummy.setup(look, world)
	dummy.position = Vector3(-1.0, 0, 0.5)
	dummy.add_to_group(&"lookable")
	hero.look_target = dummy

	var rig := CameraRig.new()
	rig.name = "Camera"
	rig.pitch = PITCH
	add_child(rig)
	rig.target_node = hero
	rig.snap_to(hero.position + Vector3(0, 0.5, 0))

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = CameraRig.SKY
	add_child(env)
	rig.env = env.environment
	rig.look = look

	for spec in [[Blob, Vector3(-11.0, 0, -3.0)], [Blob, Vector3(-12.5, 0, 0.5)], [Blob, Vector3(-9.5, 0, -0.5)],
			[Grunt, Vector3(5.0, 0, -5.5)], [Grunt, Vector3(3.0, 0, -8.2)],
			[Blob, Island.CAVE + Vector3(2.5, 0, -4.0)], [Grunt, Island.CAVE + Vector3(-2.5, 0, -6.0)]]:
		var e: Enemy = (spec[0] as GDScript).new()
		add_child(e)
		e.setup(look, world, hero, spec[1])

	_portal(Island.CAVE_MOUTH + Vector3(0, 0, 0.3), Island.CAVE_SPAWN, true, hero, rig)
	_portal(Island.CAVE + Vector3(0, 0, 5.6), Island.MOUTH_SPAWN, false, hero, rig)

	var hud := Hud.new()
	hud.name = "Hud"
	hud.hero = hero
	hud.camera = rig.camera
	add_child(hud)

	var juice := Juice.new()
	juice.name = "Juice"
	add_child(juice)
	juice.setup(world, rig, look)

	hero.island = island
	var sound := Sound.new()
	sound.name = "Sound"
	sound.island = island
	sound.hero = hero
	add_child(sound)

	var overlay := preload("res://game/debug_overlay.gd").new()
	overlay.name = "Overlay"
	overlay.native_ok = sound.ok
	overlay.hero = hero
	add_child(overlay)

	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--actors="):     # extra dummies for the cost budget (hero + N)
			var n := int(a.get_slice("=", 1))
			for i in n:
				var d := Dummy.new()
				add_child(d)
				d.setup(look, world)
				d.position = Vector3(-6.0 + (i % 5) * 2.6, 0, -3.0 + (i / 5) * 2.4 + (5.5 if i >= 5 else 0.0))
	if args.has("--bench"):
		get_tree().create_timer(20.0, true, false, true).timeout.connect(_bench_report)
	if args.has("--autoplay") or args.has("--bench"):
		var auto := preload("res://game/autoplay.gd").new()
		auto.name = "Autoplay"
		add_child(auto)


func _process(delta: float) -> void:
	var t := PerfProbe.begin()
	world.tick(delta)
	look.flat.apply()
	PerfProbe.end(&"world", t)


## A trigger that moves the hero through a transition (the cave mouth and
## the way back out), switching the camera's cave mode on the way.
func _portal(at: Vector3, to: Vector3, into_cave: bool, hero: Hero, rig: CameraRig) -> void:
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 1 << 1
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(2.2, 2.0, 0.8)
	cs.shape = b
	cs.position.y = 1.0
	a.add_child(cs)
	a.position = at
	add_child(a)
	a.body_entered.connect(func(body: Node3D) -> void:
		if body != hero or MotionTransition.busy:
			return
		_travel(hero, rig, to, into_cave))


func _travel(hero: Hero, rig: CameraRig, to: Vector3, into_cave: bool) -> void:
	var origin := rig.camera.unproject_position(hero.global_position + Vector3(0, 0.6, 0))
	await MotionTransition.cover("circle", origin)
	hero.global_position = to
	hero.reset_physics_interpolation()
	hero.aim = Vector3(0, 0, -1) if into_cave else Vector3(0, 0, 1)
	rig.snap_to(to + Vector3(0, 0.5, 0))
	rig.set_cave(into_cave)
	GameEvents.emit(&"area", to, 1.0, {cave = into_cave})
	await MotionTransition.uncover("circle")


func _bench_report() -> void:
	var st := PerfProbe.stats()
	var total := 0.0
	print("BENCH (CPU script cost only; cloud: software GL on shared cores)")
	for n in st:
		var v: Vector2 = st[n]
		total += v.x
		print("  %-12s avg %6.1f us   max %6.1f us" % [n, v.x, v.y])
	print("  total        avg %6.1f us" % total)
	get_tree().quit()
