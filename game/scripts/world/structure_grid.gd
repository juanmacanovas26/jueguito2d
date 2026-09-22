class_name StructureGrid
extends RefCounted
## Pure geometry for the hip roof StructureGrid.compute_roof() generates over
## a footprint's bounding box (RoofMarker's "G" auto-fill — see
## world_zone.gd's generate_roof_over_walls()). No Node, no I/O, no
## randomness, easy to unit test in isolation.
##
## Wall/corner/pillar/floor pieces are NOT computed here any more: the
## rearchitecture that added the modular PixelLab kit (see docs/GDD.md) moved
## that decision to the player — StructureMarker.piece is stamped directly
## from whichever shape button was clicked in the palette, one piece per
## cell, no neighbour inference. This class used to also own that (an
## automatic wall/corner/pillar role from a 4-direction neighbour bitmask);
## it was removed with the art it existed to drive (WallTileset's
## procedurally rim-shaded composition, since the source pack had no real
## corner/pillar sprites to compute a ROLE for in the first place).

enum RoofPiece {
	EAVE_N, EAVE_S, EAVE_E, EAVE_W,
	HIP_NE, HIP_NW, HIP_SE, HIP_SW,
	RIDGE_EW, RIDGE_NS, INTERIOR, PYRAMID,
}

const _N := Vector2i(0, -1)
const _S := Vector2i(0, 1)
const _E := Vector2i(1, 0)
const _W := Vector2i(-1, 0)


## A hip roof over `occupied`'s bounding box (not its exact shape — a
## non-rectangular footprint still gets a roof over its whole bounding
## rectangle, including cells the player never painted; see
## world_zone.gd's generate_roof_over_walls(), which is the only caller and
## skips door cells). Empty input returns an
## empty result. Every cell inside the bounding box gets a piece.
static func compute_roof(occupied: Dictionary) -> Dictionary:
	if occupied.is_empty():
		return {}
	var min_x := 2147483647
	var max_x := -2147483648
	var min_y := 2147483647
	var max_y := -2147483648
	for cell in occupied:
		var pos: Vector2i = cell
		min_x = mini(min_x, pos.x)
		max_x = maxi(max_x, pos.x)
		min_y = mini(min_y, pos.y)
		max_y = maxi(max_y, pos.y)

	var out := {}
	if min_x == max_x and min_y == max_y:
		out[Vector2i(min_x, min_y)] = RoofPiece.PYRAMID
		return out

	var width := max_x - min_x + 1
	var height := max_y - min_y + 1
	# The ridge runs along whichever axis is longer — a hip roof's peak
	# follows the building's long dimension. Ties (square footprint) run it
	# east-west, an arbitrary but deterministic choice.
	var ridge_ew := width >= height
	var mid_x := int(roundf(float(min_x + max_x) / 2.0))
	var mid_y := int(roundf(float(min_y + max_y) / 2.0))

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var cell := Vector2i(x, y)
			var at_n := y == min_y
			var at_s := y == max_y
			var at_w := x == min_x
			var at_e := x == max_x

			if at_n and at_w:
				out[cell] = RoofPiece.HIP_NW
			elif at_n and at_e:
				out[cell] = RoofPiece.HIP_NE
			elif at_s and at_w:
				out[cell] = RoofPiece.HIP_SW
			elif at_s and at_e:
				out[cell] = RoofPiece.HIP_SE
			elif at_n:
				out[cell] = RoofPiece.EAVE_N
			elif at_s:
				out[cell] = RoofPiece.EAVE_S
			elif at_w:
				out[cell] = RoofPiece.EAVE_W
			elif at_e:
				out[cell] = RoofPiece.EAVE_E
			elif ridge_ew and y == mid_y:
				out[cell] = RoofPiece.RIDGE_EW
			elif not ridge_ew and x == mid_x:
				out[cell] = RoofPiece.RIDGE_NS
			else:
				out[cell] = RoofPiece.INTERIOR
	return out


## RoofPiece -> the palette/StructureTileset piece id string it corresponds
## to (see StructureTileset.ROOF_PIECES) — the auto-fill bridge between this
## pure-geometry result and RoofMarker.piece, which is what actually gets
## painted. No VALLEY_* here: compute_roof() only ever produces a convex hip
## roof over a rectangle, which has hips but never valleys — those stay a
## manual-only piece for L-shaped/multi-building roofs.
static func roof_piece_id(piece: RoofPiece) -> String:
	match piece:
		RoofPiece.EAVE_N: return "eave_n"
		RoofPiece.EAVE_S: return "eave_s"
		RoofPiece.EAVE_E: return "eave_e"
		RoofPiece.EAVE_W: return "eave_w"
		RoofPiece.HIP_NE: return "hip_ne"
		RoofPiece.HIP_NW: return "hip_nw"
		RoofPiece.HIP_SE: return "hip_se"
		RoofPiece.HIP_SW: return "hip_sw"
		RoofPiece.RIDGE_EW: return "ridge_ew"
		RoofPiece.RIDGE_NS: return "ridge_ns"
		RoofPiece.PYRAMID: return "pyramid"
		_: return "interior"
