extends Node
## Headless coverage for the "CAMINO (auto)" brush — RoadAutotiler's mask
## maths and the table tools/bake_road_autotile.py generates for it, plus the
## end-to-end paint: a FloorTileMarker carrying an "autoroad_*" id has to come
## out of world_zone.gd's _rebuild_floor_tiles() as a real road tile in the
## "Suelo" layer, chosen from its neighbours.
##
##   Godot_v4.7.1-stable_win64_console.exe --headless --path game \
##       res://tools/validate_road_autotile.tscn
##
## Exits 0 when everything passes, 1 otherwise.

const WORLD_ZONE_SCRIPT := preload("res://scripts/world/world_zone.gd")
const TEST_SCENE_PATH := "res://tools/__validate_road_autotile_tmp.tscn"
## Mirrors the baker's MAX_RUN_SEAM.
const MAX_RUN_SEAM := 100.0
const MIN_CHECKS := 50

var _failures: Array = []
var _checks := 0


func _ready() -> void:
	_test_table()
	_test_masks()
	_test_fallbacks()
	_test_diagonal_run()
	_test_painted_zone()

	_expect(_checks >= MIN_CHECKS,
		"ran at least %d checks (got %d) — did a section silently skip?" % [MIN_CHECKS, _checks])
	print("\n-- %d checks, %d failures --" % [_checks, _failures.size()])
	for f in _failures:
		print("FAIL: " + f)
	print("RESULT: " + ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _ok(label: String) -> void:
	_checks += 1
	print("  ok   " + label)


func _fail(label: String) -> void:
	_checks += 1
	_failures.append(label)
	print("  FAIL " + label)


func _expect(cond: bool, label: String) -> void:
	if cond:
		_ok(label)
	else:
		_fail(label)


## Every style has to cover the cases a road is actually MADE of, or a road
## drawn in that style has holes in it. This is the check that catches art
## being renamed or removed without re-running the baker.
func _test_table() -> void:
	print("\n[table]")
	var required := {
		RoadAutotiler.N | RoadAutotiler.NE | RoadAutotiler.E: "corner N+E",
		RoadAutotiler.E | RoadAutotiler.SE | RoadAutotiler.S: "corner E+S",
		RoadAutotiler.S | RoadAutotiler.SW | RoadAutotiler.W: "corner S+W",
		RoadAutotiler.W | RoadAutotiler.NW | RoadAutotiler.N: "corner W+N",
		RoadAutotiler.N | RoadAutotiler.NE | RoadAutotiler.E | RoadAutotiler.SE | RoadAutotiler.S: "west edge",
		RoadAutotiler.E | RoadAutotiler.SE | RoadAutotiler.S | RoadAutotiler.SW | RoadAutotiler.W: "north edge",
		RoadAutotiler.S | RoadAutotiler.SW | RoadAutotiler.W | RoadAutotiler.NW | RoadAutotiler.N: "east edge",
		RoadAutotiler.W | RoadAutotiler.NW | RoadAutotiler.N | RoadAutotiler.NE | RoadAutotiler.E: "south edge",
	}
	_expect(not RoadAutotiler.styles().is_empty(), "the baked table has at least one style")
	# The palette is a hand-written const list; which styles QUALIFY is decided
	# by measuring the art in the baker. Drift between the two is silent
	# otherwise — a dead palette button, or a style that earned its place and
	# nobody exposed it.
	var palette := {}
	for id in BuildCatalog.ids_in_category("camino"):
		palette[RoadAutotiler.style_of(id.trim_prefix("floor_"))] = true
	var table_styles := {}
	for style in RoadAutotiler.styles():
		table_styles[style] = true
	_expect(palette.keys() == table_styles.keys(),
		"the CAMINO palette offers exactly the baked styles (palette %s, baked %s)"
			% [palette.keys(), table_styles.keys()])
	for style in RoadAutotiler.styles():
		var entry: Dictionary = RoadAutotileTable.TABLE[style]
		var missing: Array = []
		for mask in required:
			if not entry["round"].has(mask):
				missing.append(required[mask])
		_expect(missing.is_empty(), "%s covers every edge and corner (missing: %s)" % [style, missing])
		_expect(str(entry["fill"]) != "", "%s has an interior fill tile" % style)
		_expect(entry["diag"].size() == 4, "%s has all four 45° bevels" % style)
		# The table is only useful if PaintedFloorTileset actually ships the
		# art it names — the two are generated and loaded independently.
		var known := {}
		for id in PaintedFloorTileset.ids_sorted():
			known[id] = true
		var unknown: Array = []
		for group in ["round", "diag"]:
			for mask in entry[group]:
				if not known.has(str(entry[group][mask][0])):
					unknown.append(entry[group][mask][0])
		if not known.has(str(entry["fill"])):
			unknown.append(entry["fill"])
		_expect(unknown.is_empty(), "%s only names tiles the palette ships (stray: %s)" % [style, unknown])
		# The reason madera/losa are not here: a west edge is stacked down the
		# side of a road, so if its own art has a rim on its top and bottom the
		# road reads as a stack of boxes. Re-check it on the real texture
		# rather than trusting the baker's note.
		var west: int = RoadAutotiler.N | RoadAutotiler.NE | RoadAutotiler.E | RoadAutotiler.SE | RoadAutotiler.S
		_expect(_vertical_seam(str(entry["round"][west][0])) <= MAX_RUN_SEAM,
			"  %s's west edge repeats when stacked (seam %.0f, budget %.0f)"
				% [style, _vertical_seam(str(entry["round"][west][0])), MAX_RUN_SEAM])


## How badly a tile seams against a copy of itself stacked BELOW it: the jump
## across the seam compared with the ordinary variation inside the tile. Same
## measure tools/bake_road_autotile.py gates styles on, reimplemented here so
## the check tests the shipped art rather than re-reading the baker's own note.
func _vertical_seam(tile_id: String) -> float:
	var path := PaintedFloorTileset.path_for(tile_id)
	if not ResourceLoader.exists(path):
		return 999.0
	var img: Image = (load(path) as Texture2D).get_image()
	var w := img.get_width()
	var h := img.get_height()
	var seam := 0.0
	for x in w:
		seam += _channel_diff(img.get_pixel(x, h - 1), img.get_pixel(x, 0))
	var inner := 0.0
	for x in w:
		for y in h - 1:
			inner += _channel_diff(img.get_pixel(x, y), img.get_pixel(x, y + 1))
	return absf(seam / float(w) - inner / float(w * (h - 1)))


func _channel_diff(a: Color, b: Color) -> float:
	return (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) * 255.0


func _cells(list: Array) -> Dictionary:
	var out := {}
	for c in list:
		out[c] = true
	return out


func _test_masks() -> void:
	print("\n[masks]")
	# A 3x3 block: the middle cell has all eight neighbours, the sides have
	# an edge's worth, the corners a corner's worth.
	var block: Array = []
	for y in range(3):
		for x in range(3):
			block.append(Vector2i(x, y))
	var cells := _cells(block)
	_expect(RoadAutotiler.mask_at(cells, Vector2i(1, 1)) == RoadAutotiler.FILL,
		"the middle of a 3x3 block is the interior mask")
	_expect(RoadAutotiler.mask_at(cells, Vector2i(0, 1))
		== RoadAutotiler.N | RoadAutotiler.NE | RoadAutotiler.E | RoadAutotiler.SE | RoadAutotiler.S,
		"its left-hand cell is the west edge")
	_expect(RoadAutotiler.mask_at(cells, Vector2i(0, 0))
		== RoadAutotiler.E | RoadAutotiler.SE | RoadAutotiler.S,
		"its top-left cell is the E+S corner")
	_expect(RoadAutotiler.mask_at(cells, Vector2i(2, 2))
		== RoadAutotiler.W | RoadAutotiler.NW | RoadAutotiler.N,
		"its bottom-right cell is the W+N corner")

	# A corner bit with only one of its cardinals is not a connection: the
	# art has no piece for a road that touches only diagonally.
	var touching := _cells([Vector2i(0, 0), Vector2i(1, 1)])
	_expect(RoadAutotiler.mask_at(touching, Vector2i(0, 0)) == 0,
		"a diagonal-only neighbour does not count as connected")

	# Concave notch: an L of cells leaves one diagonal empty.
	var l_shape := _cells([
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(2, 2), Vector2i(1, 2)])
	_expect(RoadAutotiler.mask_at(l_shape, Vector2i(1, 1)) == RoadAutotiler.FILL & ~RoadAutotiler.SW,
		"a cell missing only its SW diagonal reads as the SW inner corner")


func _test_fallbacks() -> void:
	print("\n[fallbacks]")
	var style: String = RoadAutotiler.styles()[0]
	var entry: Dictionary = RoadAutotileTable.TABLE[style]

	_expect(RoadAutotiler.resolve("no-such-style", RoadAutotiler.FILL, false).is_empty(),
		"an unknown style resolves to nothing rather than a wrong tile")

	var fill := RoadAutotiler.resolve(style, RoadAutotiler.FILL, false)
	_expect(str(fill[0]) == str(entry["fill"]), "the interior mask resolves to the style's fill tile")
	# The mask-255 bucket holds the insides of DIFFERENT decorated shapes, not
	# variants of one texture, so every interior cell has to draw the same
	# one — an earlier version picked among them per cell and turned a wide
	# road into a patchwork.
	var distinct := {}
	for i in range(64):
		distinct[RoadAutotiler.resolve(style, RoadAutotiler.FILL, false)[0]] = true
	_expect(distinct.size() == 1, "  and every interior cell draws that same tile")

	# A bare L-bend has the cardinals of a corner but neither corner bit, so
	# it has to land on the corner piece rather than on nothing.
	var bend: int = RoadAutotiler.N | RoadAutotiler.E
	var bend_tile := RoadAutotiler.resolve(style, bend, false)
	_expect(bend_tile[0] == entry["round"][RoadAutotiler.N | RoadAutotiler.NE | RoadAutotiler.E][0],
		"a mask with a corner's cardinals but no corner bits falls back to that corner")

	# One-cell-wide road: no art exists for it in this set at all, so the
	# honest outcome is the interior fill, not an empty cell.
	var thin: int = RoadAutotiler.N | RoadAutotiler.S
	var thin_tile := RoadAutotiler.resolve(style, thin, false)
	_expect(not thin_tile.is_empty() and str(thin_tile[0]) == str(entry["fill"]),
		"a one-cell-wide run falls back to the fill instead of resolving to nothing")

	for mask in range(256):
		var got := RoadAutotiler.resolve(style, mask, false)
		if got.is_empty() or str(got[0]) == "":
			_fail("every one of the 256 masks resolves to a tile (mask %d did not)" % mask)
			return
	_ok("every one of the 256 masks resolves to some tile")


## The bevel-vs-rounded choice, which is what makes a diagonal look like a
## diagonal instead of a staircase.
func _test_diagonal_run() -> void:
	print("\n[diagonal]")
	var style: String = RoadAutotiler.styles()[0]
	var entry: Dictionary = RoadAutotileTable.TABLE[style]
	var corner: int = RoadAutotiler.N | RoadAutotiler.NE | RoadAutotiler.E

	# A 3-wide band running down-right: x - y in [0, 2].
	var band: Array = []
	for y in range(-2, 6):
		for d in range(3):
			band.append(Vector2i(y + d, y))
	var cells := _cells(band)
	var step := Vector2i(2, 2)
	var mask := RoadAutotiler.mask_at(cells, step)
	_expect(mask == corner, "the lower edge of a diagonal band is the N+E corner mask")
	_expect(RoadAutotiler.bevel_at(cells, step, mask), "  and reads as a diagonal run")
	_expect(RoadAutotiler.resolve(style, mask, true)[0] == entry["diag"][corner][0],
		"  so it draws the 45° bevel, not the rounded corner")

	# The thinnest diagonal the grid has: a staircase two cells wide. Its
	# steps carry NO corner bits at all, so this is the case that silently
	# stopped bevelling when bevel_at() matched on the raw mask instead of
	# the corner family.
	var stair: Array = []
	for i in range(7):
		stair.append(Vector2i(10 + i, i))
		stair.append(Vector2i(11 + i, i))
	var stair_cells := _cells(stair)
	var lower := Vector2i(11 + 3, 3)
	var lower_mask := RoadAutotiler.mask_at(stair_cells, lower)
	_expect(lower_mask & ~RoadAutotiler.CARDINALS == 0,
		"a 2-cell staircase step has no corner bits to match on")
	_expect(RoadAutotiler.corner_family(lower_mask) != 0,
		"  but still reads as a corner by its cardinals")
	_expect(RoadAutotiler.bevel_at(stair_cells, lower, lower_mask),
		"  and bevels, so the thinnest diagonal is not a zigzag")
	var upper := Vector2i(10 + 3, 3)
	var upper_mask := RoadAutotiler.mask_at(stair_cells, upper)
	_expect(RoadAutotiler.bevel_at(stair_cells, upper, upper_mask),
		"  on its other side too, so the band has two parallel edges")
	_expect(RoadAutotiler.corner_family(upper_mask) != RoadAutotiler.corner_family(lower_mask),
		"  and those two edges are opposite corners, not the same one twice")

	# The same mask at a lone L-bend, where the neighbouring steps are not
	# road, has to stay rounded — that is the "curve" half of the feature.
	var elbow := _cells([
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
		Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, 1), Vector2i(2, 0),
		Vector2i(3, 0), Vector2i(3, 1)])
	var elbow_mask := RoadAutotiler.mask_at(elbow, Vector2i(0, 1))
	_expect(elbow_mask == corner, "a lone bend's outer cell has the same corner mask")
	_expect(not RoadAutotiler.bevel_at(elbow, Vector2i(0, 1), elbow_mask),
		"  but does not read as a diagonal run")
	_expect(RoadAutotiler.resolve(style, elbow_mask, false)[0]
		== entry["round"][corner][0], "  so it keeps the rounded corner")


## The whole path, through the real zone: place auto-road markers with the
## build-mode brush and read back what landed in the "Suelo" TileMapLayer.
func _test_painted_zone() -> void:
	print("\n[painted zone]")
	# A bare zone, never added to the live tree — world_zone.gd's real
	# _ready() wants a Floor child this suite has no reason to build. Same
	# shape validate_build_mode.gd's _make_zone() uses, for the same reason.
	var zone := Node2D.new()
	zone.set_script(WORLD_ZONE_SCRIPT)
	zone.scene_file_path = TEST_SCENE_PATH
	zone._build_floor_tiles()

	var style: String = RoadAutotiler.styles()[0]
	var kind := RoadAutotiler.palette_id(style)
	_expect(BuildCatalog.ids_in_category("camino").has(kind),
		"the palette offers '%s' under CAMINO (auto)" % kind)
	_expect(BuildIcons.get_icon(kind) != null, "  and it has a palette icon")

	var previous_brush: int = Game.build_brush_size
	Game.build_brush_size = 1
	# A 2-wide vertical road, four cells long, placed cell by cell
	# (single_cell) so the shape under test is exactly this and not whatever
	# the brush would have fanned out to.
	for y in range(4):
		for x in range(2):
			zone._place_marker(kind, BuildGrid.cell_to_world(Vector2i(x, y)), true)
	var layer: TileMapLayer = zone.get_node_or_null("Suelo")
	_expect(layer != null, "the zone has a Suelo layer to paint into")
	if layer == null:
		zone.free()
		Game.build_brush_size = previous_brush
		return

	var entry: Dictionary = RoadAutotileTable.TABLE[style]
	var west: int = RoadAutotiler.N | RoadAutotiler.NE | RoadAutotiler.E | RoadAutotiler.SE | RoadAutotiler.S
	var east: int = RoadAutotiler.S | RoadAutotiler.SW | RoadAutotiler.W | RoadAutotiler.NW | RoadAutotiler.N
	_expect(_tile_at(zone, layer, Vector2i(0, 1)) == entry["round"][west][0],
		"the left column of a 2-wide road paints the west edge")
	_expect(_tile_at(zone, layer, Vector2i(1, 1)) == entry["round"][east][0],
		"  and the right column paints the east edge")
	_expect(_tile_at(zone, layer, Vector2i(0, 0))
		== entry["round"][RoadAutotiler.E | RoadAutotiler.SE | RoadAutotiler.S][0],
		"  the top-left cell caps it with the E+S corner")

	# Extending the road has to REPAINT the cell that was the cap, not just
	# add a new one — that neighbour dependency is the whole feature.
	var was_cap := _tile_at(zone, layer, Vector2i(0, 3))
	for x in range(2):
		zone._place_marker(kind, BuildGrid.cell_to_world(Vector2i(x, 4)), true)
	_expect(_tile_at(zone, layer, Vector2i(0, 3)) != was_cap,
		"extending the road repaints the cell that used to be its end")
	_expect(_tile_at(zone, layer, Vector2i(0, 3)) == entry["round"][west][0],
		"  into the straight west edge")

	# Erasing has to unwind it the same way.
	for x in range(2):
		zone._remove_nearest_marker(BuildGrid.cell_to_world(Vector2i(x, 4)))
	_expect(_tile_at(zone, layer, Vector2i(0, 3)) == was_cap,
		"and erasing the extension puts the end cap back")

	# The brush: one click, size*size cells.
	Game.build_brush_size = 3
	zone._place_marker(kind, BuildGrid.cell_to_world(Vector2i(20, 20)))
	_expect(_painted_cells(zone, layer, Vector2i(20, 20), 3) == 9,
		"a 3x3 brush paints nine cells in one click (got %d)"
			% _painted_cells(zone, layer, Vector2i(20, 20), 3))
	_expect(_tile_at(zone, layer, Vector2i(20, 20)) == str(entry["fill"]),
		"  and the middle of that stamp is the interior fill")

	# The art has no one-cell-wide road, so a 1x1 setting still has to paint
	# 2x2 for an auto-road — WITHOUT the setting itself being rewritten
	# behind the user's back.
	Game.build_brush_size = 1
	zone._place_marker(kind, BuildGrid.cell_to_world(Vector2i(26, 20)))
	_expect(_painted_cells(zone, layer, Vector2i(26, 20), 2) == 4,
		"a 1x1 brush still paints an auto-road 2 cells wide (got %d)"
			% _painted_cells(zone, layer, Vector2i(26, 20), 2))
	_expect(Game.build_brush_size == 1, "  and leaves the brush setting alone")
	# The same minimum must NOT leak onto the ordinary per-piece floor tiles.
	var plain_ids := BuildCatalog.ids_in_category("suelo").filter(
		func(id: String) -> bool: return id.begins_with("floor_"))
	if not plain_ids.is_empty():
		zone._place_marker(str(plain_ids[0]), BuildGrid.cell_to_world(Vector2i(30, 20)))
		_expect(_painted_cells(zone, layer, Vector2i(30, 20), 2) == 1,
			"while a plain SUELO tile at 1x1 still paints exactly one cell")

	# Undo folds the whole stamp back into one step. Cells kept well inside
	# world_size (2400x1800, so |y| <= 900) — out of bounds nothing is
	# placed at all, and "it is not there afterwards" would pass for the
	# wrong reason.
	Game.build_brush_size = 3
	var undo_at := Vector2i(34, 20)
	zone.begin_build_action()
	zone._place_marker(kind, BuildGrid.cell_to_world(undo_at))
	_expect(_painted_cells(zone, layer, undo_at, 3) == 9,
		"a brush stamp inside the zone bounds paints before being undone")
	zone.undo_build_action()
	_expect(_painted_cells(zone, layer, undo_at, 3) == 0,
		"  and Ctrl+Z takes the whole stamp back as one action")

	Game.build_brush_size = previous_brush
	zone.free()


## How many of the `size`-square block anchored the way _paint_floor_brush()
## anchors it (up-left of `centre`) actually got painted.
func _painted_cells(zone: Node, layer: TileMapLayer, centre: Vector2i, size: int) -> int:
	var start := centre - Vector2i(size / 2, size / 2)
	var painted := 0
	for dy in size:
		for dx in size:
			if _tile_at(zone, layer, start + Vector2i(dx, dy)) != "":
				painted += 1
	return painted


## The tile id painted at `cell`, via the zone's own id -> source_id map, or
## "" when nothing is there.
func _tile_at(zone: Node, layer: TileMapLayer, cell: Vector2i) -> String:
	var source_id := layer.get_cell_source_id(cell)
	if source_id < 0:
		return ""
	var ids: Dictionary = zone._floor_tile_source_ids
	for tile_id in ids:
		if int(ids[tile_id]) == source_id:
			return str(tile_id)
	return ""
