# The shared look for the spike: one MotionFlat3D (face tones, outlines,
# fog), the materials every builder uses, and the palette. One instance,
# made by main.gd and handed to everything that builds geometry.
class_name Look
extends RefCounted

const INK := Color("#1b1622")
const GRASS_TOP := Color("#8fcf6a")
const GRASS_LIT := Color("#79b85a")
const EARTH_LIT := Color("#b98a5a")
const EARTH_DARK := Color("#8a603d")
const SEA := Color("#3a8fae")
const STONE := Color("#c9c3b8")
const WOOD := Color("#c58b52")
const LEAF := Color("#4fa86c")
const STRAW := Color("#e2c27a")

var flat := MotionFlat3D.new()
## World: face tones, out of group motion.
var ground: ShaderMaterial
var earth: ShaderMaterial
var white: ShaderMaterial          # face tones in white: vertex colour paints
var white_instanced: ShaderMaterial
var cutout: ShaderMaterial
var edges: ShaderMaterial          # world outlines
var card_edges: ShaderMaterial     # character outlines: thinner bias, so a
                                   # back part's outline can't beat a front part
var shadows: ShaderMaterial
var atlas: MotionDecalAtlas
var blob_uv: Rect2


func _init(parent: Node) -> void:
	flat.light = Vector3(-0.55, 0.0, 0.83)
	ground = flat.material(GRASS_TOP, GRASS_LIT, GRASS_LIT.darkened(0.2), Color(0, 0, 0, 0), 0.0, false)
	earth = flat.material(GRASS_TOP, EARTH_LIT, EARTH_DARK, Color(0, 0, 0, 0), 0.0, false)
	white = flat.material(Color.WHITE, Color(0.86, 0.86, 0.86), Color(0.66, 0.66, 0.68), Color(0, 0, 0, 0), 0.0, false)
	white_instanced = flat.material(Color.WHITE, Color(0.86, 0.86, 0.86), Color(0.66, 0.66, 0.68), Color(0, 0, 0, 0), 0.0, false, false, true)
	cutout = flat.cutout()
	edges = flat.edges(INK, 2.2, 0.03)
	card_edges = flat.edges(INK, 2.6, 0.003)
	flat.fixed.append(edges)
	flat.fixed.append(card_edges)
	atlas = MotionDecalAtlas.new(Vector2i(256, 128))
	parent.add_child(atlas)
	blob_uv = atlas.add(Vector2i(120, 120), func(c: MotionCanvas, sz: Vector2) -> void:
		for i in 12:   # soft blob: stacked translucent discs
			c.circle(sz * 0.5, sz.x * 0.5 * (1.0 - i / 14.0), Color(1, 1, 1, 0.09)))
	shadows = flat.decals(atlas.texture, false)


## A flat ground decal (blob shadow, impact ring): a quad lying on y = 0 of
## its parent, `half` metres each way, mapped to `uv`.
func ground_decal(uv: Rect2, half: Vector2, col: Color) -> MeshInstance3D:
	var st := MotionFlat3D.begin()
	MotionFlat3D.quad(st, Vector3(-half.x, 0, half.y), Vector3(half.x, 0, half.y), Vector3(half.x, 0, -half.y), Vector3(-half.x, 0, -half.y),
			Vector3.UP, Vector2.ZERO, col, uv)
	return MotionFlat3D.instance(st.commit(), shadows)


## A flat ring lying on y = 0 (inner radius `r0`, outer 1) with its own
## alpha-blended material (set `albedo_color.a` to fade it): a smooth fade
## reads better on a big ring than the cutout material's dithered opacity.
func ground_ring(r0 := 0.82, seg := 40, col := Color.WHITE) -> MeshInstance3D:
	var st := MotionFlat3D.begin()
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		MotionFlat3D.quad(st, p0 * r0, p1 * r0, p1, p0, Vector3.UP, Vector2.ZERO, col)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return MotionFlat3D.instance(st.commit(), m)
