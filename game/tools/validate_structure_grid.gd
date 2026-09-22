extends Node
## Headless coverage for StructureGrid's pure geometry — the hip roof over a
## footprint's bounding box (StructureGrid.compute_roof(), still the engine
## behind the "G" bulk roof-fill) and its RoofPiece -> palette-id mapping.
## No scene, no I/O, so every check runs synchronously against
## StructureGrid's static funcs.
##
## Wall/corner/pillar role-by-neighbour is NOT covered here any more — that
## whole mechanism (compute_walls/compute_wall_masks/MASK_*/affected_by) was
## removed with the rearchitecture that lets the player pick each wall piece
## directly (see docs/GDD.md and StructureMarker.piece).
##
##   Godot_v4.7.1-stable_win64_console.exe --headless --path game \
##       res://tools/validate_structure_grid.tscn
##
## Exits 0 when everything passes, 1 otherwise.

const MIN_CHECKS := 28

var _failures: Array = []
var _checks := 0


func _ready() -> void:
	_run()


func _run() -> void:
	print("== validate_structure_grid ==")
	_check_roof_1x1()
	_check_roof_wide_rect()
	_check_roof_square_and_tall()
	_check_roof_piece_id()

	_check_ran_enough()
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


func _check_ran_enough() -> void:
	if _checks < MIN_CHECKS:
		_fail("only %d checks ran but at least %d are expected — a section aborted early"
			% [_checks, MIN_CHECKS])


func _check_roof_1x1() -> void:
	print("\n[1] Roof over a 1x1 footprint")
	var roof := StructureGrid.compute_roof({Vector2i(5, 5): true})
	_expect(roof.size() == 1, "one cell in, one roof piece out")
	_expect(roof[Vector2i(5, 5)] == StructureGrid.RoofPiece.PYRAMID,
		"a lone cell gets the pyramid cap")
	_expect(StructureGrid.compute_roof({}).is_empty(), "an empty footprint has no roof")


func _check_roof_wide_rect() -> void:
	print("\n[2] Roof over a 5x5 footprint (ridge distinct from plain interior)")
	var occupied := {}
	for y in range(5):
		for x in range(5):
			occupied[Vector2i(x, y)] = true
	var roof := StructureGrid.compute_roof(occupied)
	_expect(roof.size() == 25, "every bounding-box cell gets a roof piece (%d)" % roof.size())

	_expect(roof[Vector2i(0, 0)] == StructureGrid.RoofPiece.HIP_NW, "top-left corner is a hip")
	_expect(roof[Vector2i(4, 0)] == StructureGrid.RoofPiece.HIP_NE, "top-right corner is a hip")
	_expect(roof[Vector2i(0, 4)] == StructureGrid.RoofPiece.HIP_SW, "bottom-left corner is a hip")
	_expect(roof[Vector2i(4, 4)] == StructureGrid.RoofPiece.HIP_SE, "bottom-right corner is a hip")

	_expect(roof[Vector2i(2, 0)] == StructureGrid.RoofPiece.EAVE_N, "top edge (non-corner) is an eave")
	_expect(roof[Vector2i(2, 4)] == StructureGrid.RoofPiece.EAVE_S, "bottom edge (non-corner) is an eave")
	_expect(roof[Vector2i(0, 2)] == StructureGrid.RoofPiece.EAVE_W, "left edge (non-corner) is an eave")
	_expect(roof[Vector2i(4, 2)] == StructureGrid.RoofPiece.EAVE_E, "right edge (non-corner) is an eave")

	# width==height==5 ties toward an east-west ridge (see StructureGrid.compute_roof).
	_expect(roof[Vector2i(1, 2)] == StructureGrid.RoofPiece.RIDGE_EW
			and roof[Vector2i(2, 2)] == StructureGrid.RoofPiece.RIDGE_EW
			and roof[Vector2i(3, 2)] == StructureGrid.RoofPiece.RIDGE_EW,
		"the centerline of a square footprint runs an east-west ridge")
	_expect(roof[Vector2i(1, 1)] == StructureGrid.RoofPiece.INTERIOR
			and roof[Vector2i(1, 3)] == StructureGrid.RoofPiece.INTERIOR,
		"interior cells off the ridge row are plain flat fill, not ridge")


func _check_roof_square_and_tall() -> void:
	print("\n[3] Roof ridge orientation follows the long axis")
	var wide := {}
	for y in range(3):
		for x in range(7):
			wide[Vector2i(x, y)] = true
	var wide_roof := StructureGrid.compute_roof(wide)
	_expect(wide_roof[Vector2i(3, 1)] == StructureGrid.RoofPiece.RIDGE_EW,
		"a wider-than-tall footprint runs an east-west ridge")

	var tall := {}
	for y in range(7):
		for x in range(3):
			tall[Vector2i(x, y)] = true
	var tall_roof := StructureGrid.compute_roof(tall)
	_expect(tall_roof[Vector2i(1, 3)] == StructureGrid.RoofPiece.RIDGE_NS,
		"a taller-than-wide footprint runs a north-south ridge")
	_expect(tall_roof[Vector2i(0, 0)] == StructureGrid.RoofPiece.HIP_NW
			and tall_roof[Vector2i(2, 6)] == StructureGrid.RoofPiece.HIP_SE,
		"...and its corners are still hips regardless of orientation")


## roof_piece_id() is the bridge between this pure geometry and
## RoofMarker.piece/StructureTileset.ROOF_PIECES — every RoofPiece value has
## to map to a real palette id, or generate_roof_over_walls() silently paints
## nothing for whichever one is missing.
func _check_roof_piece_id() -> void:
	print("\n[4] RoofPiece -> palette piece id")
	var expected := {
		StructureGrid.RoofPiece.EAVE_N: "eave_n",
		StructureGrid.RoofPiece.EAVE_S: "eave_s",
		StructureGrid.RoofPiece.EAVE_E: "eave_e",
		StructureGrid.RoofPiece.EAVE_W: "eave_w",
		StructureGrid.RoofPiece.HIP_NE: "hip_ne",
		StructureGrid.RoofPiece.HIP_NW: "hip_nw",
		StructureGrid.RoofPiece.HIP_SE: "hip_se",
		StructureGrid.RoofPiece.HIP_SW: "hip_sw",
		StructureGrid.RoofPiece.RIDGE_EW: "ridge_ew",
		StructureGrid.RoofPiece.RIDGE_NS: "ridge_ns",
		StructureGrid.RoofPiece.INTERIOR: "interior",
		StructureGrid.RoofPiece.PYRAMID: "pyramid",
	}
	for piece in expected:
		var got := StructureGrid.roof_piece_id(piece)
		_expect(got == expected[piece], "RoofPiece %d -> \"%s\" (got \"%s\")" % [piece, expected[piece], got])
	for id in StructureTileset.ROOF_PIECES:
		if not expected.values().has(id):
			_expect(id == "valley_ne" or id == "valley_nw" or id == "valley_se" or id == "valley_sw"
					or id.begins_with("end_"),
				"every StructureTileset.ROOF_PIECES id not produced by compute_roof() is a manual-only piece (valley/end), not a typo: \"%s\"" % id)
