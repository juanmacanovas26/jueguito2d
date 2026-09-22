class_name BuildGrid
extends RefCounted
## Reusable grid-snap math. Mobs/resources/POIs stay free-placed (see
## world_zone.gd's build-mode note), but structures (walls, corners, doors —
## see StructureMarker/StructureGrid) snap through this, so a future online
## building mode (housing, base-building) can reuse it verbatim instead of a
## second grid implementation.
##
## THE tile size for the whole project — grid maths and every render layer
## alike. It used to be declared five separate times (here, world_zone,
## floor_tileset, structure_tileset), all of them 32 by
## coincidence rather than by construction: nothing stopped one from drifting
## and silently misaligning a layer against the grid it is snapped to.
## Everything now reads this one.
const TILE_SIZE := 32
## Same value as a Vector2i, for the TileSet/TileMapLayer APIs that want one.
const TILE_SIZE_2I := Vector2i(TILE_SIZE, TILE_SIZE)

## Kept as an alias so older call sites keep working; TILE_SIZE is the name
## to use in new code.
const DEFAULT_CELL := TILE_SIZE


static func snap(world_pos: Vector2, cell_size: int = DEFAULT_CELL) -> Vector2:
	return Vector2(
		roundf(world_pos.x / float(cell_size)) * cell_size,
		roundf(world_pos.y / float(cell_size)) * cell_size)


## The integer cell index a SNAPPED world position (see snap()) corresponds
## to — safe because snap() always returns an exact multiple of cell_size, so
## this never needs to round away ambiguity of its own.
static func to_cell(snapped_world_pos: Vector2, cell_size: int = DEFAULT_CELL) -> Vector2i:
	return Vector2i(
		roundi(snapped_world_pos.x / float(cell_size)),
		roundi(snapped_world_pos.y / float(cell_size)))


## Inverse of to_cell() — the world position snap() would have produced for
## whatever click resolved to this cell.
static func cell_to_world(cell: Vector2i, cell_size: int = DEFAULT_CELL) -> Vector2:
	return Vector2(cell.x * cell_size, cell.y * cell_size)
