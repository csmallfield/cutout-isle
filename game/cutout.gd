# Cutout cards from SVG art: every part a flat card (MotionSvgMesh, `flat`)
# stacked toward +Z, drawn with the cutout material, plus outlines of chosen
# parts. Phase 2 grows this into the kit's cutout rig (part pivots, IK);
# for now one card is one MeshInstance3D.
class_name Cutout
extends RefCounted

## Gap between stacked parts (metres along the card normal). Character
## outlines use a smaller depth bias than this (Look.card_edges), so a back
## part's outline never draws over a front part.
const LAYER := 0.012


## A card `width` metres wide from the SVG at `path`. `anchor` (fractions of
## the viewBox) sits at the origin; `outline` lists part ids to outline
## (when empty: every part without class "flat"). Returns the card; its outline is child "Edges".
static func card(look: Look, path: String, width: float, anchor := Vector2(0.5, 1.0), outline: PackedStringArray = PackedStringArray()) -> MeshInstance3D:
	var data := MotionSvgData.load_any(path)
	var opts := {flat = true, depth = 0.0, layer = LAYER, anchor = anchor}
	var mi := MotionFlat3D.instance(MotionSvgMesh.build(data, width, opts), look.cutout)
	mi.name = String(path.get_file().get_basename())
	var only := []
	for id in outline:
		for i in data.find(id):
			only.append(i)
	if outline.is_empty():          # every part but class "flat" (as MotionCutoutRig)
		for i in data.parts.size():
			if not (data.parts[i].classes as PackedStringArray).has("flat"):
				only.append(i)
	var eo := opts.duplicate()
	if not only.is_empty():
		eo["only"] = only
	# outlines from a mesh of just those parts, at their own layers
	var src := MotionSvgMesh.build(data, width, eo)
	var em := MotionEdges3D.from_mesh(src, {kind = MotionEdges3D.ALWAYS, crease_deg = 89.0})
	var edges := MotionFlat3D.instance(em, look.card_edges)
	edges.name = "Edges"
	mi.add_child(edges)
	return mi


## Where an SVG point lands on a card built with `width` and `anchor`
## (card-local metres; z at that part's layer is up to you).
static func point(path: String, svg_pt: Vector2, width: float, anchor := Vector2(0.5, 1.0)) -> Vector3:
	var vb := MotionSvgData.load_any(path).view_box
	var k := width / vb.size.x
	var a := vb.position + vb.size * anchor
	return Vector3((svg_pt.x - a.x) * k, -(svg_pt.y - a.y) * k, 0.0)
