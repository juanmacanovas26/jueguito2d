class_name RoadAutotiler
extends RefCounted
## The "CAMINO (auto)" brush: paint cells, and each one picks its own road
## tile from which of its eight neighbours are also road. That is what makes
## curves and diagonals possible at all — the 207 numbered road tiles in the
## "SUELO" palette are the same art, but finding the one piece that fits a
## bend by hand, cell by cell, is not something anyone does twice.
##
## This does NOT walk back PaintedFloorTileset's "no autotiling" decision. The
## thing that was tried and removed there is Godot's corner-match TERRAIN
## system over the Plains ground tiles, which cannot express a one-cell-wide
## shape and zigzagged (see docs/GDD.md). This is a different mechanism
## (a plain 8-bit blob mask, resolved here) over a different art set that was
## drawn for exactly this, and it is opt-in per brush: every existing floor
## tile still paints as the exact piece the palette shows.
##
## WIDTH: the road art is cut from composed shapes whose narrowest arm is two
## cells — the pack ships no one-cell-wide through piece at all (verified
## against the original sheets, not just the sliced set). A one-cell-wide
## stroke therefore has no art to resolve to and falls back to the interior
## fill, which reads as a hard-edged 32px strip. Roads want to be >= 2 cells
## wide; hud.gd nudges the brush to 2x2 when one of these is selected.
##
## NOT every road style in the art is offered here. A west edge is stacked
## down the side of a road, so art with a rim on its own top and bottom turns
## a long road into a stack of boxes — which is how this pack draws "madera"
## and "losa" (they are framed platforms, not roads). The baker measures that
## and leaves them out; they stay paintable piece by piece under SUELO, which
## is what they are actually good for.
##
## The mask -> tile table itself is generated from the tiles' alpha channels
## by tools/bake_road_autotile.py — see RoadAutotileTable.

## Neighbour bits, in the usual blob order. A corner bit only counts when
## both of its cardinals are road: a road touching only diagonally is not
## connected, and the art has no piece for it.
const N := 1
const NE := 2
const E := 4
const SE := 8
const S := 16
const SW := 32
const W := 64
const NW := 128
const CARDINALS := N | E | S | W
## Every neighbour is road — the interior of a wide road, which draws one of
## the style's plain fill variants rather than an edge piece.
const FILL := 255

## Cells a side below which an auto-road has no art to resolve to, so the
## brush never paints narrower than this however small it is set — see the
## class doc's WIDTH note. Applied by brush_size_for(), NOT by quietly
## rewriting Game.build_brush_size: a road being two cells wide is a fact
## about the art, not a preference the user expressed.
const MIN_WIDTH := 2

## Palette ids are "floor_autoroad_<style>"; the FloorTileMarker stores the
## id minus its "floor_" prefix, same as every other painted floor cell, so
## an auto-road cell needs no new marker type and no save-format change.
const ID_PREFIX := "autoroad_"

const _OFFSETS := {
	N: Vector2i(0, -1), NE: Vector2i(1, -1), E: Vector2i(1, 0), SE: Vector2i(1, 1),
	S: Vector2i(0, 1), SW: Vector2i(-1, 1), W: Vector2i(-1, 0), NW: Vector2i(-1, -1),
}

## The two corner masks whose empty corner faces SW/NE, so a run of them
## steps along the NW-SE diagonal; the other two step along NE-SW. Used to
## decide bevel-vs-rounded — see bevel_at().
const _DIAG_DOWN := [N | NE | E, S | SW | W]
const _DIAG_UP := [E | SE | S, W | NW | N]


static func styles() -> Array[String]:
	return RoadAutotileTable.STYLES


## "floor_autoroad_adoquin" for the palette / BuildCatalog.
static func palette_id(style: String) -> String:
	return "floor_" + ID_PREFIX + style


## True for a FloorTileMarker.tile_id that means "auto road", i.e. one whose
## art is decided per cell here instead of being the tile_id itself.
static func is_auto(tile_id: String) -> bool:
	return tile_id.begins_with(ID_PREFIX) and RoadAutotileTable.TABLE.has(style_of(tile_id))


static func style_of(tile_id: String) -> String:
	return tile_id.trim_prefix(ID_PREFIX)


## A representative tile for the palette button and the placement ghost —
## the style's interior fill, which is what a wide road mostly is.
static func icon_tile_id(style: String) -> String:
	return str(RoadAutotileTable.TABLE.get(style, {}).get("fill", ""))


## Cells a side one click of `kind` should paint, given the brush the user
## set. Only an auto-road raises it (to MIN_WIDTH); every other kind gets
## exactly what was asked for.
static func brush_size_for(kind: String, requested: int) -> int:
	if is_auto(kind.trim_prefix("floor_")):
		return maxi(requested, MIN_WIDTH)
	return requested


## Which of `cell`'s eight neighbours are road, canonicalised: a corner bit
## is cleared unless both of its cardinals are set. `cells` is a set of
## Vector2i (the cells painted with this same style).
static func mask_at(cells: Dictionary, cell: Vector2i) -> int:
	var mask := 0
	for bit in _OFFSETS:
		if cells.has(cell + _OFFSETS[bit]):
			mask |= int(bit)
	if (mask & (N | E)) != (N | E):
		mask &= ~NE
	if (mask & (E | S)) != (E | S):
		mask &= ~SE
	if (mask & (S | W)) != (S | W):
		mask &= ~SW
	if (mask & (W | N)) != (W | N):
		mask &= ~NW
	return mask


## Which outer corner a mask is a case of, by its CARDINALS alone — 0 when
## it is not a corner at all.
##
## Corner bits are deliberately ignored here. The thinnest diagonal a square
## grid can draw is a staircase two cells wide, and its steps have only two
## cardinal neighbours and NO corner bits at all (both diagonals fail the
## "needs both its cardinals" rule). Matching on the full mask would see
## those as something other than corners and quietly never bevel them, which
## is the exact case this feature exists for.
static func corner_family(mask: int) -> int:
	match mask & CARDINALS:
		N | E:
			return N | NE | E
		E | S:
			return E | SE | S
		S | W:
			return S | SW | W
		W | N:
			return W | NW | N
	return 0


## True when `cell` is a step in a diagonal run rather than a lone turn, and
## so should draw the 45-degree bevel instead of the rounded corner.
##
## A staircase of cells is how a square grid draws a diagonal, and drawing
## each step as a rounded outer corner is exactly what makes a staircase look
## like a staircase. The bevels butt up into one straight 45-degree line
## instead. A single L-bend in an orthogonal road has no neighbouring step,
## keeps the rounded piece, and reads as a curve.
##
## "Neighbouring step" means along the run, not across it: a corner whose
## empty side faces SW or NE steps along the NW-SE diagonal, the other two
## along NE-SW.
static func bevel_at(cells: Dictionary, cell: Vector2i, mask: int) -> bool:
	var family := corner_family(mask)
	if family == 0:
		return false
	var along: Array
	if _DIAG_DOWN.has(family):
		along = [Vector2i(-1, -1), Vector2i(1, 1)]
	else:
		along = [Vector2i(1, -1), Vector2i(-1, 1)]
	for step in along:
		var neighbour: Vector2i = cell + step
		if cells.has(neighbour) and corner_family(mask_at(cells, neighbour)) == family:
			return true
	return false


## -> [tile id, alternative-tile transform bits] for TileMapLayer.set_cell(),
## or an empty array when the style is unknown.
##
## The interior of a wide road is ONE tile per style, never a random pick
## among the mask-255 pieces: those are the insides of the different
## decorated shapes the pack composes, not variants of one texture, so
## mixing them turns a plaza into a patchwork. See the baker.
##
## A mask with no art of its own resolves to the closest piece that has the
## same CARDINAL neighbours, since corner bits only ever add or remove a
## small concave notch — a road whose art is missing one notch still reads
## as that road, where one missing an edge does not. With no such piece
## either (the one-cell-wide case this art has no answer for, see the class
## doc) it falls back to the interior fill.
static func resolve(style: String, mask: int, bevel: bool) -> Array:
	var entry: Dictionary = RoadAutotileTable.TABLE.get(style, {})
	if entry.is_empty():
		return []
	if bevel:
		# By family, not by the raw mask: see corner_family() — a staircase
		# step carries no corner bits to look up with.
		var diag: Dictionary = entry["diag"]
		var family := corner_family(mask)
		if diag.has(family):
			return diag[family]
	var round_pieces: Dictionary = entry["round"]
	if mask != FILL:
		var best := _closest(round_pieces, mask)
		if best >= 0:
			return round_pieces[best]
	return [str(entry["fill"]), 0]


## The mask in `pieces` with the same cardinals as `mask` and the fewest
## corner bits wrong; -1 when none shares its cardinals.
static func _closest(pieces: Dictionary, mask: int) -> int:
	if pieces.has(mask):
		return mask
	var best := -1
	var best_cost := 9
	for candidate in pieces:
		var m := int(candidate)
		if (m & CARDINALS) != (mask & CARDINALS):
			continue
		var cost := _bit_count((m ^ mask) & ~CARDINALS)
		# Ties break towards the lower mask so the choice is stable across
		# runs rather than riding on Dictionary iteration order.
		if cost < best_cost or (cost == best_cost and m < best):
			best_cost = cost
			best = m
	return best


static func _bit_count(value: int) -> int:
	var n := 0
	while value != 0:
		n += value & 1
		value >>= 1
	return n
