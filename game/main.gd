# Phase 1 look-and-feel spike: one outlined, flat-shaded island chunk under
# Forward+, an orthographic follow camera, the cutout hero and the training
# dummy. Wires the world clock, the event bus, juice, sound and the overlay.
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
	hero.position = Vector3(-1.2, 0, 0.7)

	var dummy := Dummy.new()
	dummy.name = "Dummy"
	add_child(dummy)
	dummy.setup(look, world)
	dummy.position = Vector3(0.8, 0, 0.6)

	var rig := CameraRig.new()
	rig.name = "Camera"
	rig.pitch = PITCH
	add_child(rig)
	rig.target_node = hero
	rig.snap_to(hero.position + Vector3(0, 0.5, 0))

	var juice := Juice.new()
	juice.name = "Juice"
	add_child(juice)
	juice.setup(world, rig)

	var sound := Sound.new()
	sound.name = "Sound"
	add_child(sound)

	var overlay := preload("res://game/debug_overlay.gd").new()
	overlay.name = "Overlay"
	overlay.native_ok = sound.ok
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
