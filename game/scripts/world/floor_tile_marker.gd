@tool
class_name FloorTileMarker
extends Marker2D
## Author-time placement for one painted floor/terrain cell — the "SUELO"
## and "CAMINO (auto)" build-mode tools. For a SUELO id this is a flat stamp
## with NO auto-blended borders: the player picks the exact piece (dirt edge,
## pond bank, cliff corner…) and paints it, which is the whole point — a
## corner-match terrain set was tried here and removed because it can't
## express a one-cell-wide shape (see PaintedFloorTileset's class doc and
## docs/GDD.md).
##
## A CAMINO id ("autoroad_<style>") is the exception, and is stored the same
## way: the id names a BRUSH rather than a piece, and world_zone.gd's
## _rebuild_floor_tiles() asks RoadAutotiler which road tile this cell's
## neighbours call for. Same marker, same exported properties, same saved
## scene — so nothing downstream had to learn a second cell type.
##
## Same grid_pos-is-the-source-of-truth shape as StructureMarker/RoofMarker,
## for the same reason: saving and reloading never has to worry about the
## position disagreeing with the cell after a snap-rounding difference.
##
## Unlike DecorMarker this draws nothing of its own at runtime — the art is
## painted into the "Suelo" TileMapLayer by world_zone.gd's
## _rebuild_floor_tiles(), so a thousand painted cells cost one layer rather
## than a thousand CanvasItems.

@export var grid_pos: Vector2i = Vector2i.ZERO:
	set(value):
		grid_pos = value
		position = BuildGrid.cell_to_world(grid_pos)
## Which of PaintedFloorTileset's tiles this cell paints with — the palette id
## ("floor_tierra_01") minus its "floor_" prefix — or "autoroad_<style>",
## which resolves per cell instead (see the class doc).
@export var tile_id: String = "":
	set(value):
		tile_id = value
		queue_redraw()


func _ready() -> void:
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	queue_redraw()


## Editor-only outline, same as the other grid markers — in game the cell is
## already visible as the painted tile itself.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(Vector2(-14, -14), Vector2(28, 28)), Color(0.85, 0.7, 0.35, 0.9), false, 2.0)
