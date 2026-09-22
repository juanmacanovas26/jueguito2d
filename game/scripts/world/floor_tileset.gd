class_name FloorTileset
extends RefCounted
## Builds the TileSet used by the "Floor" TileMapLayer (see world_zone.gd).
## Each tile is a single 32x32 source PNG. Drop the real art at the paths
## below (same file names) and re-run the game — the tileset picks it up
## automatically, no code changes needed. Until then, a flat placeholder
## color is used so the scene keeps running.

const TILE_SIZE := BuildGrid.TILE_SIZE_2I

const GRASS_BASE := "res://assets/tiles/grass_01.png"
const GRASS_VARIANT_A := "res://assets/tiles/grass_02.png"
const GRASS_VARIANT_B := "res://assets/tiles/grass_03.png"
const DIRT_PATH := "res://assets/tiles/dirt_path.png"

## 16-tile corner Wang set for the grass/dirt border, laid out 4x4 with a 1px
## transparent gutter between tiles (so the sheet is 131x131, not 128x128).
##
## The cell order is the canonical binary enumeration of which corners are
## grass:  index = TL*8 + TR*4 + BL*2 + BR*1
## i.e. #0 is all dirt, #15 is all grass. Verified by sampling the art, not
## assumed — see the terrain wiring in _add_wang_source().
const GRASS_DIRT_WANG := "res://assets/tiles/grass_dirt_wang.png"
const WANG_SEPARATION := 1
const WANG_COLUMNS := 4

## Terrain indices inside the terrain set built by build().
const TERRAIN_DIRT := 0
const TERRAIN_GRASS := 1
const TERRAIN_SET := 0

## Registration order defines source_id (0, 1, 2, 3 — TileSet assigns ids
## sequentially starting at 0 on a fresh TileSet).
const _SOURCES := [GRASS_BASE, GRASS_VARIANT_A, GRASS_VARIANT_B, DIRT_PATH]

const _PLACEHOLDER_COLORS := {
	GRASS_BASE: Color(0.33, 0.47, 0.31),
	GRASS_VARIANT_A: Color(0.29, 0.43, 0.28),
	GRASS_VARIANT_B: Color(0.37, 0.51, 0.32),
	DIRT_PATH: Color(0.62, 0.49, 0.32),
}


static func build() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE
	# Sources 0..3 stay exactly where they were so grass_source_ids() and
	# dirt_path_source_id() keep meaning the same thing.
	for path in _SOURCES:
		var src := TileSetAtlasSource.new()
		src.texture = _load_or_placeholder(path)
		src.texture_region_size = TILE_SIZE
		src.create_tile(Vector2i.ZERO)
		ts.add_source(src)
	_add_wang_source(ts)
	return ts


## Source id of the grass/dirt Wang sheet, or -1 when its art is missing.
static func wang_source_id() -> int:
	return _wang_source_id


static var _wang_source_id: int = -1


## Registers the 16-tile Wang sheet and wires it up as a Godot terrain set, so
## TileMapLayer.set_cells_terrain_connect() can pick the right border tile on
## its own. Corner-match mode: what matters is which of the four CORNERS of a
## cell are grass, which is exactly how the sheet is drawn.
static func _add_wang_source(ts: TileSet) -> void:
	_wang_source_id = -1
	if not ResourceLoader.exists(GRASS_DIRT_WANG):
		return
	var tex: Resource = load(GRASS_DIRT_WANG)
	if not (tex is Texture2D):
		return
	var expected := TILE_SIZE.x * WANG_COLUMNS + WANG_SEPARATION * (WANG_COLUMNS - 1)
	var size: Vector2 = tex.get_size()
	if int(size.x) != expected or int(size.y) != expected:
		push_warning("[FloorTileset] %s is %dx%d but a %d-column Wang sheet of %dpx tiles with %dpx gutters must be %dx%d — skipping it."
			% [GRASS_DIRT_WANG, int(size.x), int(size.y), WANG_COLUMNS, TILE_SIZE.x, WANG_SEPARATION, expected, expected])
		return

	ts.add_terrain_set()
	ts.set_terrain_set_mode(TERRAIN_SET, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	ts.add_terrain(TERRAIN_SET)
	ts.set_terrain_name(TERRAIN_SET, TERRAIN_DIRT, "Dirt")
	ts.set_terrain_color(TERRAIN_SET, TERRAIN_DIRT, Color(0.62, 0.49, 0.32))
	ts.add_terrain(TERRAIN_SET)
	ts.set_terrain_name(TERRAIN_SET, TERRAIN_GRASS, "Grass")
	ts.set_terrain_color(TERRAIN_SET, TERRAIN_GRASS, Color(0.33, 0.47, 0.31))

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = TILE_SIZE
	src.separation = Vector2i(WANG_SEPARATION, WANG_SEPARATION)

	# index = TL*8 + TR*4 + BL*2 + BR*1, read left-to-right then top-to-bottom.
	for index in 16:
		var coords := Vector2i(index % WANG_COLUMNS, index / WANG_COLUMNS)
		src.create_tile(coords)
		var data: TileData = src.get_tile_data(coords, 0)
		data.terrain_set = TERRAIN_SET
		_set_corner(data, TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, index & 8)
		_set_corner(data, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, index & 4)
		_set_corner(data, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, index & 2)
		_set_corner(data, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, index & 1)
		# The tile's own terrain is the majority of its corners, which is what
		# Godot uses when a cell is painted without neighbours to match.
		var grass_corners := 0
		for bit in [8, 4, 2, 1]:
			if index & bit != 0:
				grass_corners += 1
		data.terrain = TERRAIN_GRASS if grass_corners >= 2 else TERRAIN_DIRT

	_wang_source_id = ts.get_next_source_id()
	ts.add_source(src, _wang_source_id)


static func _set_corner(data: TileData, corner: int, is_grass: int) -> void:
	data.set_terrain_peering_bit(corner, TERRAIN_GRASS if is_grass != 0 else TERRAIN_DIRT)


## A tile PNG smaller than TILE_SIZE cannot hold a single 32x32 region: Godot
## refuses to create the tile AND fails building the atlas' padded texture,
## which used to be three errors on every boot and left the source with no tile
## at all (so that terrain silently never painted). Reject the art instead and
## fall back to the flat placeholder, which at least renders.
static func _is_usable(tex: Texture2D, path: String) -> bool:
	if tex == null:
		return false
	var size := tex.get_size()
	if int(size.x) < TILE_SIZE.x or int(size.y) < TILE_SIZE.y:
		push_warning("[FloorTileset] %s is %dx%d but tiles are %dx%d — using the placeholder colour. Redraw it at %dx%d (see docs/ART.md)."
			% [path, int(size.x), int(size.y), TILE_SIZE.x, TILE_SIZE.y, TILE_SIZE.x, TILE_SIZE.y])
		return false
	return true


## Source ids for the plain-grass variants (base + 2 accents), in the order
## they should be weighted when scattering the floor pattern.
static func grass_source_ids() -> Array[int]:
	return [0, 1, 2]


static func dirt_path_source_id() -> int:
	return 3


static func _load_or_placeholder(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex: Resource = load(path)
		if tex is Texture2D and _is_usable(tex, path):
			return tex
	var img := Image.create(TILE_SIZE.x, TILE_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(_PLACEHOLDER_COLORS.get(path, Color(0.3, 0.42, 0.3)))
	return ImageTexture.create_from_image(img)
