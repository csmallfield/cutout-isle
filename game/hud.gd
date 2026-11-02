# The HUD, built from motion kit pieces and driven by GameEvents:
#   hearts         one MotionLiquidFill per heart (a heart MotionSvg filling
#                  with liquid); losing one drains it with a slosh, and the
#                  others slosh in sympathy; healing pours it back
#   combo counter  hits chained within 1.2 s, popping on a spring
#   damage numbers rising and fading over the hit, popping on a spring
# The HUD runs on real time (it keeps moving through hit-stop) and follows
# the 1920 x 1080 reference, letterboxed by the window's stretch settings.
class_name Hud
extends CanvasLayer

const HEART := "res://art/heart.svg"
const HEART_EMPTY := "res://art/heart_empty.svg"
const HEART_W := 54.0

var hero: Node
var camera: Camera3D
var _hearts: Array[Dictionary] = []      # {fill, back, level: MotionSpring, frame}
var _time := 0.0
var _combo := 0
var _combo_t := -10.0
var _combo_label: Label
var _combo_pop := MotionSpring.new(0.0, 9.0, 260.0)
var _numbers: Array[Dictionary] = []     # {label, pos: Vector3, t, pop}
var _font: Font


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	var heart := MotionSvgData.load_any(HEART)
	var empty := MotionSvgData.load_any(HEART_EMPTY)
	var n: int = hero.max_hp if hero else 5
	for i in n:
		var holder := Node2D.new()
		holder.position = Vector2(36 + i * (HEART_W + 10), 34)
		add_child(holder)
		var back := MotionSvg.new()
		back.data = empty
		back.width = HEART_W
		holder.add_child(back)
		var fill := MotionLiquidFill.new()
		fill.size = Vector2(HEART_W, HEART_W * 58.0 / 64.0)
		fill.wave_amp = 3.0
		fill.wave_freq = 0.55
		fill.ripple = 0.6
		fill.ripple_len = 30.0
		fill.meniscus = 3.0
		fill.meniscus_color = Color("#ff9c8a")
		fill.fill_level = 1.0
		var svg := MotionSvg.new()
		svg.data = heart
		svg.width = HEART_W
		fill.fill.add_child(svg)
		holder.add_child(fill)
		_hearts.append({fill = fill, level = MotionSpring.new(1.0, 8.0, 60.0), holder = holder})
	_combo_label = Label.new()
	_combo_label.add_theme_font_size_override(&"font_size", 54)
	_combo_label.add_theme_color_override(&"font_color", Color("#fffbe8"))
	_combo_label.add_theme_color_override(&"font_outline_color", Color("#1b1622"))
	_combo_label.add_theme_constant_override(&"outline_size", 12)
	_combo_label.visible = false
	add_child(_combo_label)
	GameEvents.event.connect(_on_event)


func _on_event(name: StringName, pos: Vector3, intensity: float, data: Dictionary) -> void:
	match name:
		&"hero.hurt", &"hero.heal":
			_slosh_all(0.6 if name == &"hero.hurt" else 0.3)
		&"damage_number":
			_spawn_number(pos, intensity, bool(data.get("ko", false)))
	if String(name).begins_with("hit.") and data.get("target") != hero:
		if _time - _combo_t > 1.2:
			_combo = 0
		_combo += 1
		_combo_t = _time
		if _combo >= 2:
			_combo_pop.velocity += 9.0


func _slosh_all(amp: float) -> void:
	for h in _hearts:
		var fill: MotionLiquidFill = h.fill
		fill.kicks.append(Vector2(_time * 30.0, amp * (0.7 + MK.rand(_time + fill.position.x) * 0.6)))
		if fill.kicks.size() > 6:
			fill.kicks.pop_front()


func _spawn_number(pos: Vector3, power: float, ko: bool) -> void:
	var l := Label.new()
	l.text = ("%d" % roundi(power * 10.0)) + ("!" if ko else "")
	l.add_theme_font_size_override(&"font_size", 40 if not ko else 52)
	l.add_theme_color_override(&"font_color", Color("#ffe9a8") if not ko else Color("#ff9c5a"))
	l.add_theme_color_override(&"font_outline_color", Color("#1b1622"))
	l.add_theme_constant_override(&"outline_size", 10)
	add_child(l)
	_numbers.append({label = l, pos = pos + Vector3(0, 0.5, 0), t = 0.0, side = MK.rand(_time * 7.0) - 0.5})
	if _numbers.size() > 12:
		(_numbers.pop_front().label as Label).queue_free()


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 1e-4)
	_time += real
	var f := _time * 30.0
	# hearts
	var hp: int = hero.hp if hero else 0
	for i in _hearts.size():
		var h: Dictionary = _hearts[i]
		var spring: MotionSpring = h.level
		spring.target = 1.0 if i < hp else 0.0
		var lvl := spring.step(real)
		var fill: MotionLiquidFill = h.fill
		fill.fill_level = clampf(lvl, 0.0, 1.0) * 0.98
		fill._frame(f)
		var holder: Node2D = h.holder
		var pulse := 1.0 + (0.08 * maxf(0.0, sin(_time * TAU * 1.3)) if hp <= 2 and i < hp else 0.0)   # low health: the hearts beat
		holder.scale = Vector2.ONE * pulse
	# combo counter
	var show := _combo >= 2 and _time - _combo_t < 1.2
	_combo_label.visible = show
	if show:
		var s := 1.0 + _combo_pop.step(real) * 0.06
		_combo_label.text = "%d HITS" % _combo
		var vp := get_viewport().get_visible_rect().size
		_combo_label.pivot_offset = _combo_label.size * 0.5
		_combo_label.position = Vector2(vp.x - _combo_label.size.x - 40, 30)
		_combo_label.scale = Vector2.ONE * s
		_combo_label.modulate.a = 1.0 - MK.prog(f, (_combo_t + 0.9) * 30.0, 9.0)
	# damage numbers: a pop, a rise, a fade
	for i in range(_numbers.size() - 1, -1, -1):
		var d: Dictionary = _numbers[i]
		d.t = float(d.t) + real
		var t: float = d.t
		var l: Label = d.label
		if t > 0.8 or camera == null:
			l.queue_free()
			_numbers.remove_at(i)
			continue
		var p: Vector3 = d.pos
		var screen := camera.unproject_position(p) + Vector2(float(d.side) * 40.0 * t, -90.0 * MK.map(t * 30.0, [0, 24], [0, 1]))
		var pop := MK.spring(t * 30.0, 0.0, 10.0, 300.0)
		l.pivot_offset = l.size * 0.5
		l.position = screen - l.size * 0.5
		l.scale = Vector2.ONE * (0.4 + 0.6 * pop)
		l.modulate.a = 1.0 - MK.prog(t * 30.0, 14.0, 10.0)
