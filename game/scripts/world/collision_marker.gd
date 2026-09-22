@tool
class_name CollisionMarker
extends Marker2D
## Author-time placement for one solid grid cell — the "COLISIÓN" build-mode
## tool. Deliberately independent of whatever texture/biome/structure is
## painted at that cell (StructureTileset walls still have no collision of
## their own, see docs/GDD.md's v1 limitation note): this is a plain physics
## brush a mapper drops wherever something should block movement — deep
## water, a cliff edge, anything — without needing that visual to also be a
## StructureMarker wall. world_zone.gd's _rebuild_collision() is what turns
## this into a real StaticBody2D; this class itself carries no collision
## shape, just the authored grid_pos.
##
## Same grid_pos-is-the-source-of-truth shape as StructureMarker/RoofMarker.
## No runtime _draw() at all — a red square over live gameplay would be a
## permanent visual lie about what's "wall", the exact opposite of how
## StructureMarker/RoofMarker's debug squares are editor-only. Only the
## editor-time square below exists, same guard as every other marker.

@export var grid_pos: Vector2i = Vector2i.ZERO:
	set(value):
		grid_pos = value
		position = BuildGrid.cell_to_world(grid_pos)


func _ready() -> void:
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(Vector2(-16, -16), Vector2(32, 32)), Color(1.0, 0.2, 0.2, 0.35))
	draw_rect(Rect2(Vector2(-16, -16), Vector2(32, 32)), Color(1.0, 0.2, 0.2, 0.9), false, 2.0)
