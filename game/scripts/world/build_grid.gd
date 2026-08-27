class_name BuildGrid
extends RefCounted
## Reusable grid-snap math. Nothing calls this yet — mobs/resources/POIs stay
## free-placed today, see world_zone.gd's build-mode note — but structures
## (walls, furniture) will snap through this same helper once they exist, so
## a future online building mode (housing, base-building) can reuse it
## verbatim instead of a second grid implementation.

const DEFAULT_CELL := 32


static func snap(world_pos: Vector2, cell_size: int = DEFAULT_CELL) -> Vector2:
	return Vector2(
		roundf(world_pos.x / float(cell_size)) * cell_size,
		roundf(world_pos.y / float(cell_size)) * cell_size)
