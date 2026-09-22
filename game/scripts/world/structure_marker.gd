@tool
class_name StructureMarker
extends Marker2D
## Author-time placement for one structure grid cell — a wall, corner,
## partition, column, or floor piece, whichever the player picked in the
## "ESTRUCTURA" palette (StructureTileset.WALL_PIECES). Unlike the old
## neighbour-computed system, `piece` is stamped directly at placement time
## and is the actual source of truth for what renders — no per-rebuild
## inference from this marker's neighbours any more (see docs/GDD.md and
## world_zone.gd's _rebuild_structures()).
##
## grid_pos is the source of truth for where this cell sits; global_position
## is derived from it (grid_pos * BuildGrid.DEFAULT_CELL) so saving/loading
## never has to worry about the two disagreeing after a snap-rounding
## difference.

@export var grid_pos: Vector2i = Vector2i.ZERO:
	set(value):
		grid_pos = value
		position = BuildGrid.cell_to_world(grid_pos)
## Which of StructureTileset.WALL_PIECES this cell renders as — "wall_n",
## "corner_out_ne", "partition_hub", "column", "floor", etc. Chosen at
## placement time from whichever shape button was selected in the palette;
## see world_zone.gd's _instantiate_marker().
@export var piece: String = "wall_n"
## Which of StructureTileset.WALL_MATERIALS this cell paints with — "stone"
## (default), "brick", "plain", or "wood". A separate axis from `piece`,
## chosen globally in the palette (Game.build_wall_material) and stamped per
## cell so it survives save/reload independently of shape.
@export var wall_material: String = "stone"
## Which of StructureTileset.WALL_DECOR is painted ON TOP of this cell —
## "door", "window_small", "window_medium", "window_large", "window_arched",
## "window_flowerbox", "torch", or "" for none. Purely a separate overlay
## (see world_zone.gd's _paint_wall_decor()/_rebuild_structures()) — it does
## NOT change this cell's own `piece`, so a doorway keeps its wall
## underneath and can also carry a window.
@export var wall_decor: String = ""


func _ready() -> void:
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var c := Color(0.95, 0.75, 0.25, 0.9) if wall_decor != "" else Color(0.75, 0.55, 0.35, 0.9)
	draw_rect(Rect2(Vector2(-14, -14), Vector2(28, 28)), c, false, 2.0)
