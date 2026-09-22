extends Node2D
## Always-on-top build-mode placement preview.
##
## world_zone.gd (the zone root) sets z_index = -5 so its floor/content sit
## behind entities — drawing the ghost directly on that node put it BEHIND
## the floor tilemap and everything else, since a Node2D's own _draw() output
## renders before its children within the same relative z layer. This is a
## separate CanvasItem with z_as_relative = false so it always renders on top
## regardless of what the zone root (or anything else) is doing.
##
## Also shows rotation (Q/E, see hud.gd) and placement validity — green when
## the click would succeed, red when it would be refused — the same signal
## Rust/Valheim/Fortnite-style building tools give before you commit.

func _ready() -> void:
	z_as_relative = false
	z_index = 100


func _process(_delta: float) -> void:
	if Game.build_mode:
		var pos := get_global_mouse_position()
		# Grid kinds (walls/doors/roof) snap to the grid they'll actually be
		# stored on — see world_zone.gd's _place_marker()/BuildGrid — so the
		# preview shows exactly where a click will land, not a raw cursor pos.
		# The free brush never snaps, not even with T on: snapping the one
		# tool whose whole point is not being on the grid would be absurd.
		var snaps := _is_grid_kind() or Game.build_snap_to_grid
		if snaps and not PaintLayer.is_paint_id(Game.build_selected_kind):
			pos = BuildGrid.snap(pos)
		global_position = pos
	queue_redraw()


## "structure" (wall/door) and "roof" both place a fixed 32px grid cell with
## bounds-only validity, no rotation, no size of their own — see
## world_zone.gd's _place_marker(). Everything else (decor/resources/mobs/
## POIs) is free-placed at its own native size.
func _is_grid_kind() -> bool:
	# "suelo" is checked by id prefix, not by category: that category also
	# holds the whole composed pieces (a 6x6 pond, a plateau), which are
	# free-placed DecorMarkers — only the single-cell "floor_*" tiles snap.
	return (BuildCatalog.ids_in_category("structure").has(Game.build_selected_kind)
		or BuildCatalog.ids_in_category("roof").has(Game.build_selected_kind)
		or BuildCatalog.ids_in_category("collision").has(Game.build_selected_kind)
		or Game.build_selected_kind.begins_with("floor_"))


func _draw() -> void:
	if not Game.build_mode:
		return
	var kind := Game.build_selected_kind
	# The free brush previews its actual footprint — the circle it will paint
	# — rather than a swatch of the texture. A square swatch would be a lie
	# about the one thing that matters here, the shape of the dab.
	if PaintLayer.is_paint_id(kind):
		_draw_brush_ring(PaintLayer.radius_for(Game.build_brush_size))
		return
	var is_grid := _is_grid_kind()
	var draw_rotation := 0.0
	var facing_steps := 0
	if not is_grid:
		# Mirrors world_zone.gd's _place_marker(): a building kind doesn't
		# preview the flat free-45°-steps rotation every other prop does, and
		# a directional one (blacksmith) previews the correct SPRITE for the
		# facing it'll actually place at, not the front sprite rotated — see
		# BuildingMarker.placement_for().
		if kind.begins_with("building_"):
			var placement := BuildingMarker.placement_for(kind.trim_prefix("building_"), Game.build_rotation)
			draw_rotation = placement["rotation"]
			facing_steps = placement["facing_steps"]
		else:
			draw_rotation = Game.build_rotation
	var tex := BuildIcons.get_icon(kind, facing_steps)
	if tex == null:
		return
	var valid := true
	var zone := get_parent()
	# A grid kind only ever checks bounds at placement time (see
	# world_zone.gd's is_within_bounds() doc comment) — matching that here, or
	# the ghost would flash red next to ordinary world clutter for a click
	# that will actually succeed.
	if zone and is_grid and zone.has_method("is_within_bounds"):
		valid = zone.is_within_bounds(global_position)
	elif zone and zone.has_method("is_placement_valid"):
		valid = zone.is_placement_valid(global_position, kind)
	var tint := Color(0.55, 1.0, 0.55, 0.65) if valid else Color(1.0, 0.35, 0.35, 0.65)
	# Every kind draws at its texture's TRUE size — a preview that resizes
	# anything is a preview that lies about what the click will produce.
	# (Two separate versions of this got that wrong in opposite directions:
	# a flat 48x48 box for decor squashed a 64x16 banner and stretched a
	# 12x13 spigot; a flat 32x32 box for structures squashed the 32x64 wall
	# and the taller-than-a-cell door.)
	var draw_size := Vector2(tex.get_size())
	# Where that rect sits relative to the cursor differs by kind, matching
	# how each is actually anchored once placed:
	#  - grid kinds (wall/door/window/torch/ground): the cursor is on the
	#    CELL, and StructureTileset anchors an oversized tile bottom-centered
	#    on it (see _add_sources()'s texture_origin) — so the preview hangs
	#    down to the cell's bottom edge and grows up from there, not centered
	#    on the cursor. Half a cell down, because the TileMapLayer itself is
	#    offset half a cell (world_zone.gd's _build_structures()).
	#  - everything else: free-placed, DecorMarker/resource_node draw
	#    bottom-centered on the click point itself.
	var half_cell := Vector2(StructureTileset.TILE_SIZE) * 0.5
	var draw_origin := Vector2(-draw_size.x * 0.5, -draw_size.y)
	if is_grid:
		draw_origin += Vector2(0, half_cell.y)
	draw_set_transform(Vector2.ZERO, draw_rotation, Vector2.ONE)
	# A floor brush wider than one cell previews the WHOLE stamp, laid out
	# exactly as world_zone.gd's _paint_floor_brush() will place it (same
	# up-left bias for an even size) — a preview showing one cell for a click
	# that paints nine is the same lie as a resized one.
	for offset in _brush_offsets(kind):
		draw_texture_rect(tex, Rect2(draw_origin + offset, draw_size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The brush outline, plus a faint fill so it reads as an area and not just a
## circle drawn on the world. Red while the cursor is out of bounds, matching
## the refusal every other kind's ghost already signals that way.
func _draw_brush_ring(radius: float) -> void:
	var zone := get_parent()
	var inside := true
	if zone and zone.has_method("is_within_bounds"):
		inside = zone.is_within_bounds(global_position)
	var tint := Color(0.95, 0.85, 0.45) if inside else Color(1.0, 0.35, 0.35)
	draw_circle(Vector2.ZERO, radius, Color(tint.r, tint.g, tint.b, 0.16))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, 0.9), 1.5)


## One local-space offset per cell the click will paint; a single zero offset
## for everything that isn't a multi-cell floor brush.
func _brush_offsets(kind: String) -> Array[Vector2]:
	var size := RoadAutotiler.brush_size_for(
		kind, clampi(Game.build_brush_size, 1, Game.MAX_BRUSH_SIZE))
	if size <= 1 or not kind.begins_with("floor_"):
		return [Vector2.ZERO] as Array[Vector2]
	var out: Array[Vector2] = []
	var start := -(size / 2) * BuildGrid.TILE_SIZE
	for dy in size:
		for dx in size:
			out.append(Vector2(start + dx * BuildGrid.TILE_SIZE, start + dy * BuildGrid.TILE_SIZE))
	return out
