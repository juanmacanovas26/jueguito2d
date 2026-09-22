class_name StructureTileset
extends RefCounted
## Builds the TileSets used by the "Structures"/"WallDecor"/"Roof"
## TileMapLayers (world_zone.gd's build-mode section) from the modular
## building kit generated with PixelLab at assets/world/structures/kit/ (see
## docs/GDD.md's rearchitecture entry) — one real sprite per wall/roof PIECE
## per MATERIAL, two independent axes chosen separately in the palette
## (piece = which shape button; material = Game.build_wall_material /
## Game.build_roof_material). This replaces the old Hypnobius flat-texture
## pack, which had no real corner/pillar/interior-wall art and forced every
## role to share one repeating texture (or, for a while, a procedurally
## rim-shaded approximation of a corner — see the removed WallTileset).
##
## WALL_PIECES/ROOF_PIECES are pure shape; StructureMarker.piece/
## RoofMarker.piece store them directly (no StructureGrid inference any
## more — a player clicks the exact piece they want). A door/window/torch
## stays a THIRD, separate axis: optional decoration painted ON TOP of a
## wall/corner/partition/column cell (StructureMarker.wall_decor), not a
## replacement for its piece — see world_zone.gd's _paint_wall_decor()/
## _rebuild_structures().
const TILE_SIZE := BuildGrid.TILE_SIZE_2I
const DIR := "res://assets/world/structures/"
const KIT_DIR := DIR + "kit/"
const DECOR_DIR := "res://assets/world/decor/"

## Every wall/floor piece id the kit provides, one PNG per id per material
## (except "floor", which is shared across materials — see FLOOR_FILE).
const WALL_PIECES := [
	"wall_n", "wall_e", "wall_s", "wall_w",
	"corner_in_ne", "corner_in_nw", "corner_in_se", "corner_in_sw",
	"corner_out_ne", "corner_out_nw", "corner_out_se", "corner_out_sw",
	"partition_hub", "partition_n", "partition_e", "partition_s", "partition_w",
	"column",
]
const WALL_MATERIALS := ["stone", "brick", "plain", "wood"]
const FLOOR_FILE := KIT_DIR + "floor.png"

## Every roof piece id the kit provides. No VALLEY_* counterpart in
## StructureGrid's automatic fill (see its class doc) — valleys are a
## manual-only piece here, for L-shaped/multi-building roofs the automatic
## hip-over-a-bounding-box can't express.
const ROOF_PIECES := [
	"eave_n", "eave_e", "eave_s", "eave_w",
	"hip_ne", "hip_nw", "hip_se", "hip_sw",
	"valley_ne", "valley_nw", "valley_se", "valley_sw",
	"ridge_ew", "ridge_ns",
	"end_n", "end_e", "end_s", "end_w",
	"pyramid", "interior",
]
const ROOF_MATERIALS := ["slate", "red"]

## Manual per-piece pixel nudge on top of the computed anchor (see
## _add_piece_source()) — positive x moves the sprite right, positive y
## moves it down. Every WALL_PIECES/ROOF_PIECES id defaults to
## Vector2i.ZERO; add an entry here to fine-tune one that looks a few
## pixels off once you've actually looked at it in-game (the anchor formula
## is the same for every piece, but the art inside each piece's canvas was
## painted independently, so a specific one being slightly off-center is
## expected, not a bug in the formula). Same offset for every material of a
## given piece — they all share one canvas size, so a shape-level nudge
## applies to all of them, not per-material.
## Tried a large upward nudge on eave_s/hip_se/hip_sw here (moving the
## anchor toward the top of the cell instead of the bottom) — confirmed
## working via tools/eave_repro_screenshot.gd's isolated 3rd repro (a lone
## wall_s + roof_eave_s, nothing else around): the piece really does move,
## but the result is a roof floating disconnected above the wall with a
## visible gap, not "aligned to the top of the grid" in any way that looks
## right. Reverted to empty pending a clearer target from the user — this
## isolated repro (no busy room to hide the effect) is the fast way to
## check the next attempt.
const PIECE_OFFSETS := {}

## StructureMarker.wall_decor value -> path. Unchanged from the Hypnobius
## pack originally — regenerated with PixelLab (style-matched, taller
## canvas) once the kit's own wall pieces made the old Hypnobius-scale door/
## window/torch art read as too small against them (reported in use).
const WALL_DECOR := {
	"door": DIR + "door.png",
	"window_small": DECOR_DIR + "window_small.png",
	"window_medium": DECOR_DIR + "window_medium.png",
	"window_large": DECOR_DIR + "window_large.png",
	"window_arched": DECOR_DIR + "window_arched.png",
	"window_flowerbox": DECOR_DIR + "window_flowerbox.png",
	"torch": DECOR_DIR + "torch.png",
}

## How far above the cell's bottom edge each wall_decor kind sits, in px —
## see _add_piece_source()'s anchoring note. A door reaches the ground (0);
## a window or wall sconce does not (it would read as a hole at floor
## level). Zeroed out for the regenerated (taller-canvas) art below pending
## a real render — the old values were tuned pixel-by-pixel against the old,
## much shorter canvas and don't carry over; this project's own history
## (see docs/GDD.md) is "measure against a render, don't guess the number."
## Negative lowers a piece (see _add_piece_source()'s nudge note) — windows
## and torch reported as sitting a bit too high after a real render (twice
## now: first at 0, then again at -8), door stays put both times (never
## reported as wrong).
const WALL_DECOR_RAISE := {
	"door": 0,
	"window_small": -16,
	"window_medium": -16,
	"window_large": -16,
	"window_arched": -16,
	"window_flowerbox": -16,
	"torch": -8,
}


## Returns {"tileset": TileSet, "floor_source_id": int,
## "piece_source_ids": {piece_id: {material_id: source_id}}}.
static func build_walls() -> Dictionary:
	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE
	var floor_id := _add_piece_source(ts, FLOOR_FILE, PIECE_OFFSETS.get("floor", Vector2i.ZERO))
	var piece_ids := {}
	for piece in WALL_PIECES:
		var by_material := {}
		var offset: Vector2i = PIECE_OFFSETS.get(piece, Vector2i.ZERO)
		for material in WALL_MATERIALS:
			var path := "%s%s/%s.png" % [KIT_DIR, material, piece]
			by_material[material] = _add_piece_source(ts, path, offset)
		piece_ids[piece] = by_material
	return {"tileset": ts, "floor_source_id": floor_id, "piece_source_ids": piece_ids}


## Returns {"tileset": TileSet,
## "piece_source_ids": {piece_id: {material_id: source_id}}}.
static func build_roof() -> Dictionary:
	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE
	var piece_ids := {}
	for piece in ROOF_PIECES:
		var by_material := {}
		var offset: Vector2i = PIECE_OFFSETS.get(piece, Vector2i.ZERO)
		for material in ROOF_MATERIALS:
			var path := "%sroof_%s/%s.png" % [KIT_DIR, material, piece]
			by_material[material] = _add_piece_source(ts, path, offset)
		piece_ids[piece] = by_material
	return {"tileset": ts, "piece_source_ids": piece_ids}


## Returns {"tileset": TileSet, "source_ids": {String -> int} (WALL_DECOR keys)}.
static func build_wall_decor() -> Dictionary:
	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE
	var ids := {}
	for kind in WALL_DECOR:
		# Raising a piece off the ground means moving it UP, i.e. the
		# opposite of `nudge`'s "positive = down" convention below —
		# negate it here so WALL_DECOR_RAISE's own values stay positive
		# and read naturally ("raise by 20px").
		var raise := Vector2i(0, -int(WALL_DECOR_RAISE.get(kind, 0)))
		ids[kind] = _add_piece_source(ts, str(WALL_DECOR[kind]), raise)
	return {"tileset": ts, "source_ids": ids}


## Adds one TileSetAtlasSource to `ts` for the image at `path`, anchored so a
## tile taller/wider than TILE_SIZE stands on its cell rather than floating
## centered in it — the rule this project measured against a real render
## (see docs/GDD.md's "anclaje de tiles más grandes que su celda" entry):
## Godot draws an atlas tile CENTERED on the cell by default, and
## texture_origin's POSITIVE values move the image UP/LEFT (the opposite of
## what the name suggests). So `(tex_size - TILE_SIZE) / 2` on the Y axis
## pulls a taller piece's BASE down to the cell's bottom edge; the X axis
## needs no correction since centered is already the right anchor for a
## piece painted symmetrically around its cell's vertical centerline (every
## kit piece, and — for wall_decor — a door/window set into a wall
## segment). `nudge` adds on top of that base anchor — POSITIVE moves the
## sprite RIGHT/DOWN (the opposite sign of texture_origin, so a caller can
## think in normal screen directions instead of Godot's inverted
## convention) — used for WALL_DECOR_RAISE (lifting a window/torch off the
## ground) and PIECE_OFFSETS (manual per-piece fine-tuning).
## A missing or unreadable asset returns a LOUD magenta/black checkerboard
## source, never a plausible solid colour — a silent placeholder has cost
## real debugging time on this project before (see git history).
static func _add_piece_source(ts: TileSet, path: String, nudge: Vector2i = Vector2i.ZERO) -> int:
	var tex := _load_or_placeholder(path)
	var tex_size := tex.get_size()
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(tex_size)
	src.create_tile(Vector2i.ZERO)
	var data := src.get_tile_data(Vector2i.ZERO, 0)
	data.texture_origin = Vector2i(0, (int(tex_size.y) - TILE_SIZE.y) / 2) - nudge
	var id := ts.get_next_source_id()
	ts.add_source(src, id)
	return id


static func _load_or_placeholder(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex: Resource = load(path)
		if tex is Texture2D:
			return tex
	var img := Image.create(TILE_SIZE.x, TILE_SIZE.y, false, Image.FORMAT_RGBA8)
	var a := Color(1.0, 0.0, 1.0, 1.0) # magenta: unmistakably "no asset"
	var b := Color(0.0, 0.0, 0.0, 1.0)
	var quad := maxi(2, TILE_SIZE.x / 4)
	for y in TILE_SIZE.y:
		for x in TILE_SIZE.x:
			img.set_pixel(x, y, a if ((x / quad) + (y / quad)) % 2 == 0 else b)
	return ImageTexture.create_from_image(img)
