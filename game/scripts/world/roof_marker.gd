@tool
class_name RoofMarker
extends Marker2D
## Author-time placement for one roof cell — eave, hip, valley, ridge, end,
## pyramid, or interior (StructureTileset.ROOF_PIECES), picked directly in
## the "TECHO (pintar)" palette. The manual counterpart to the roof
## world_zone.gd's generate_roof_over_walls() ("G") stamps in bulk over a
## building's footprint.
##
## Both coexist on purpose. The bulk fill (StructureGrid.compute_roof(),
## converted to a piece id via StructureGrid.roof_piece_id()) is fast for an
## ordinary rectangular house; painting by hand is what covers everything it
## can't express — an L-shaped building, a valley where two roofs meet, a
## porch/lean-to that sticks out past the walls, or a shape with no bulk fill
## at all. Either way the result is the same kind of data: one RoofMarker per
## cell with an explicit `piece`, so a hand-painted valley and an
## auto-filled hip read identically to world_zone.gd's _rebuild_structures().
##
## Same grid_pos-is-the-source-of-truth shape as StructureMarker,
## for the same reason: saving/loading never has to reconcile position with
## cell after a snap-rounding difference.

@export var grid_pos: Vector2i = Vector2i.ZERO:
	set(value):
		grid_pos = value
		position = BuildGrid.cell_to_world(grid_pos)
## Which of StructureTileset.ROOF_PIECES this cell renders as — "eave_n",
## "hip_ne", "ridge_ew", "pyramid", "interior", etc.
@export var piece: String = "interior"
## Which of StructureTileset.ROOF_MATERIALS this cell paints with — "slate"
## or "red". Stamped from Game.build_roof_material at placement time.
@export var roof_material: String = "slate"


func _ready() -> void:
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(Vector2(-14, -14), Vector2(28, 28)), Color(0.45, 0.55, 0.95, 0.9), false, 2.0)
