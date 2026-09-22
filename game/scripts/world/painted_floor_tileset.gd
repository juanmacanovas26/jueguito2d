class_name PaintedFloorTileset
extends RefCounted
## Builds the TileSet for the "Suelo" TileMapLayer (world_zone.gd's build
## mode) from the individual 32px floor tiles the palette can paint with.
##
## Two art sources today, told apart by id prefix (see path_for()):
##  - "road_*"  -> assets/world/roads/, cut from a CraftPix road set. These
##    carry ALPHA, so a road painted on the Suelo layer shows whatever floor
##    is underneath around its edges — that is what makes them work on any
##    surface. Their source art is 16px and is upscaled 2x on import, since
##    this project's grid is 32 (see tools/, and the note in roads/SOURCE.txt).
##  - everything else -> assets/world/decor/plains/tiles/, cut from "RPG
##    Pixel Realms - The Plains" by pixel-banner (see SOURCE.txt there).
##
## One TileSetAtlasSource per tile, keyed BY ID, and built fresh at runtime
## from the PNG files — deliberately not a pre-baked .tres whose sources are
## matched back to ids by their POSITION in the file. That positional
## coupling is what made the previous ground tileset brittle: inserting a
## tile anywhere but the end silently re-pointed every id after it at the
## wrong art. Here a missing or renamed file just drops that one id (with a
## warning) and leaves the rest correct.
##
## No terrain sets on purpose: an id painted from the palette is the exact
## piece that lands in the cell (see FloorTileMarker). Godot's corner-match
## terrain system was tried for this and removed — with two terrains and 16
## tiles it cannot represent a path one cell wide without alternating
## half-tiles into a zigzag (see docs/GDD.md).
##
## The one brush that does resolve its own tile is "CAMINO (auto)", which
## picks among the road_* ids above per cell from its neighbours. It is a
## plain blob mask rather than a terrain set, it only ever selects tiles that
## are already in this TileSet, and it changes nothing for any other id —
## see RoadAutotiler.

const TILE_SIZE := BuildGrid.TILE_SIZE_2I
const DIR := "res://assets/world/decor/plains/tiles/"
const ROADS_DIR := "res://assets/world/roads/"
## Ids under ROADS_DIR carry this prefix. Kept as a constant because both the
## palette id ("floor_road_adoquin_01") and the file name depend on it.
const ROAD_PREFIX := "road_"

## A paintable id is the palette id minus its "floor_" prefix, and maps
## straight onto "<id>.png" under DIR. Ids are grouped by the composed piece
## each tile was cut out of: grass fill, dirt patch edges, pond banks,
## dirt-cliff edges, stone-rimmed island edges, plus the odd bridge plank.
## An "autoroad_<style>" id has no art of its own — it is a brush, not a
## piece (see RoadAutotiler) — so it resolves to a representative tile of
## that style, which is what the palette button and the placement ghost show.
static func path_for(tile_id: String) -> String:
	if tile_id.begins_with(RoadAutotiler.ID_PREFIX):
		tile_id = RoadAutotiler.icon_tile_id(RoadAutotiler.style_of(tile_id))
	if tile_id.begins_with(ROAD_PREFIX):
		return ROADS_DIR + tile_id.trim_prefix(ROAD_PREFIX) + ".png"
	return DIR + tile_id + ".png"


## Returns {"tileset": TileSet, "source_ids": {tile_id -> int}}. Call once per
## zone (world_zone.gd's _build_floor_tiles()); safe to call again, it just
## rebuilds from scratch and so also picks up art added since the last call.
static func build() -> Dictionary:
	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE
	var ids := {}
	for tile_id in ids_sorted():
		var path := path_for(tile_id)
		if not ResourceLoader.exists(path):
			push_warning("[PaintedFloorTileset] missing %s — skipping '%s'." % [path, tile_id])
			continue
		var tex: Resource = load(path)
		if not (tex is Texture2D):
			continue
		var size: Vector2 = (tex as Texture2D).get_size()
		if int(size.x) != TILE_SIZE.x or int(size.y) != TILE_SIZE.y:
			push_warning("[PaintedFloorTileset] %s is %dx%d but floor tiles are %dx%d — skipping it."
				% [path, int(size.x), int(size.y), TILE_SIZE.x, TILE_SIZE.y])
			continue
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = TILE_SIZE
		src.create_tile(Vector2i.ZERO)
		var id := ts.get_next_source_id()
		ts.add_source(src, id)
		ids[tile_id] = id
	return {"tileset": ts, "source_ids": ids}


## Every paintable id, in palette order. Kept as a plain sorted list of the
## ids BuildCatalog exposes rather than a second hand-maintained table — the
## catalog is already the single source of truth for what the palette offers.
static func ids_sorted() -> Array[String]:
	var out: Array[String] = []
	for id in BuildCatalog.ids_in_category("suelo"):
		if id.begins_with("floor_"):
			out.append(id.trim_prefix("floor_"))
	return out
