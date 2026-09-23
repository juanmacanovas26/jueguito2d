extends Node
## Headless coverage for the runtime build-mode overlay (world_zone.gd's
## _place_marker / _remove_nearest_marker / save_markers_layout /
## _load_markers_override) — the place -> save -> reload loop, without an
## editor round-trip. Uses a throwaway scene_file_path so this never touches
## (or silently shadows) a real zone's saved layout.
##
##   Godot_v4.7.1-stable_win64_console.exe --headless --path game \
##       res://tools/validate_build_mode.tscn
##
## Exits 0 when everything passes, 1 otherwise.

const WORLD_ZONE_SCRIPT := preload("res://scripts/world/world_zone.gd")
const TEST_SCENE_PATH := "res://tools/__validate_build_mode_tmp.tscn"
const MIN_CHECKS := 250

var _failures: Array = []
var _checks := 0


func _ready() -> void:
	_cleanup_override_file()
	await _run()
	_cleanup_override_file()

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


## The checks below that instantiate pradera.tscn were written assuming a
## structure/roof-free "Markers" node — true when they were written, but no
## longer guaranteed now that pradera.tscn is the real, hand-built world (see
## docs/GDD.md's build-mode-editor entries): whatever the user actually built
## and saved is baked directly into its "Markers" node, not a separate
## override file any more (_load_markers_override() isn't even called at
## Play any more). Clears the IN-MEMORY instance's Markers children only —
## never touches the file on disk — right after instantiate(), before
## add_child() triggers _ready() and reads them, so these checks get the
## clean slate they assume regardless of what's really been built.
func _clear_markers(zone: Node) -> void:
	var markers := zone.get_node_or_null("Markers")
	if markers == null:
		return
	for child in markers.get_children():
		markers.remove_child(child)
		child.queue_free()


func _check_ran_enough() -> void:
	if _checks < MIN_CHECKS:
		_fail("only %d checks ran but at least %d are expected — a section aborted early"
			% [_checks, MIN_CHECKS])


func _override_path() -> String:
	return TEST_SCENE_PATH.get_basename() + "_markers.tscn"


func _cleanup_override_file() -> void:
	if ResourceLoader.exists(_override_path()):
		DirAccess.remove_absolute(_override_path())


## A bare zone, never added to the live tree (world_zone.gd's real _ready()
## needs a Floor child this test has no reason to build) — enough to call the
## marker-placement methods directly, the same way other suites call
## "private" _-prefixed methods on real objects.
func _make_zone() -> Node2D:
	var zone := Node2D.new()
	zone.set_script(WORLD_ZONE_SCRIPT)
	zone.scene_file_path = TEST_SCENE_PATH
	return zone


func _run() -> void:
	print("== validate_build_mode ==")
	await _check_place_and_remove()
	_check_save_and_reload()
	_check_build_icons()
	await _check_hud_build_panel_wiring()
	await _check_build_ghost_layering()
	_check_rotation()
	_check_building_rotation()
	_check_placement_validity()
	_check_structure_placement()
	_check_structure_save_round_trip()
	await _check_structure_rendering()
	await _check_decor_placement()
	await _check_building_scenes()
	_check_dock_filters()
	await _check_building_placement()
	await _check_collision_placement()
	_check_floor_tile_painting()
	_check_build_placement_parity()
	_check_draw_order()
	_check_props_over_ground()
	await _check_undo()
	await _check_roof_none_and_inheritance()
	await _check_manual_roof()


func _check_place_and_remove() -> void:
	print("\n[1] placing and removing markers")
	var zone := _make_zone()

	zone._place_marker("mob", Vector2(100, 50))
	var markers: Node = zone.get_node_or_null("Markers")
	_expect(markers != null and markers.get_child_count() == 1, "placing a mob adds one marker")
	var mobs: Node = zone.get_node_or_null("Mobs")
	_expect(mobs != null and mobs.get_child_count() == 1, "  and spawns the live mob immediately")

	zone._place_marker("vein", Vector2(-40, 10))
	var obstacles: Node = zone.get_node_or_null("Obstacles")
	_expect(obstacles != null and obstacles.get_child_count() == 1, "placing a vein spawns a gatherable")
	if obstacles and obstacles.get_child_count() == 1:
		var vein_node = obstacles.get_child(0)
		_expect(str(vein_node.visual_type) == "vein" and bool(vein_node.immortal),
			"  with vein properties applied")

	zone._place_marker("dungeon_entrance", Vector2(5, 5))
	_expect(markers.get_child_count() == 3, "a POI marker is also added under Markers")

	zone._remove_nearest_marker(Vector2(100, 50))
	_expect(markers.get_child_count() == 2, "removing near the mob's position deletes its marker")
	# The mob is queue_free()'d, not free()'d immediately (the normal, safe
	# way to delete a node) — give the deferred deletion a frame to land.
	await get_tree().process_frame
	_expect(mobs.get_child_count() == 0, "  and frees the live mob it had spawned")

	zone.free()


func _check_save_and_reload() -> void:
	print("\n[2] save_markers_layout() / _load_markers_override() round trip")
	var zone := _make_zone()
	zone._place_marker("rock", Vector2(77, -12))
	zone._place_marker("tree", Vector2(-5, 40))

	var saved: bool = zone.save_markers_layout()
	_expect(saved, "save_markers_layout() succeeds")
	_expect(ResourceLoader.exists(_override_path()), "  and writes the override file next to the zone")

	var zone2 := _make_zone()
	# No inline "Markers" node on this fresh zone — the saved override is its
	# only source of markers, same as a real zone reloaded after a save.
	zone2._load_markers_override()
	var markers2: Node = zone2.get_node_or_null("Markers")
	_expect(markers2 != null and markers2.get_child_count() == 2,
		"the reloaded zone's Markers node has both placed markers")

	zone.free()
	zone2.free()


## Every kind the palette can offer must produce a real icon. This is the
## exact bug this suite is here to catch: an earlier BuildIcons implementation
## round-tripped art through Image.get_image()/resize(), which could raise on
## a texture format that doesn't decode back to a CPU Image — and because
## hud.gd wired icon + click together in one loop, that one bad icon aborted
## the loop and silently left every kind after it un-clickable (see the fix
## in build_icons.gd and the connect-before-icon reorder in hud.gd).
func _check_build_icons() -> void:
	print("\n[3] BuildIcons.get_icon() for every palette kind")
	# Every id BuildCatalog actually lists, not a hand-kept copy of it — the
	# whole point of this check is catching a typo'd art path for a NEW kind,
	# which a hardcoded list here would silently stop covering.
	for kind in BuildCatalog.all_ids():
		var tex := BuildIcons.get_icon(kind)
		_expect(tex != null and tex.get_width() > 0 and tex.get_height() > 0,
			"BuildIcons.get_icon('%s') returns a real texture" % kind)


## Instantiates the real HUD scene and confirms every one of the 9 palette
## buttons actually got wired: has a listener on `toggled`, and toggling it
## on (as a real click inside the ButtonGroup would) really changes
## Game.build_selected_kind. Calling _place_marker() directly (see the
## sections above) proves the placement logic works; it can't catch a
## UI-wiring regression where a button looks selectable but does nothing —
## which is exactly what shipped and got reported.
func _check_hud_build_panel_wiring() -> void:
	print("\n[4] hud.gd builds the palette from BuildCatalog and wires every id")
	var hud = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame

	var expected_ids := BuildCatalog.all_ids()
	_expect(expected_ids.size() == 581, "BuildCatalog lists 581 placeable ids (got %d)" % expected_ids.size())

	var button_map: Dictionary = hud._build_kind_buttons
	_expect(button_map.size() == expected_ids.size(),
		"hud built one button per catalog id (got %d)" % button_map.size())

	for id in expected_ids:
		var button: Button = button_map.get(id)
		_expect(button != null, "'%s' has a palette button" % id)
		if button == null:
			continue
		_expect(button.toggled.get_connections().size() > 0,
			"  and its toggled signal is connected")

	# "mob" starts pre-toggled (see _build_palette()'s default selection), so
	# setting button_pressed=true on it first would be a no-op and never fire
	# `toggled` — force every button through a real off->on transition by
	# activating a different one first, the same way clicking a different
	# button in the group would.
	for i in expected_ids.size():
		var id: String = expected_ids[i]
		var button: Button = button_map.get(id)
		if button == null:
			continue
		var other: Button = button_map.get(expected_ids[(i + 1) % expected_ids.size()])
		if other:
			other.button_pressed = true
		Game.build_selected_kind = "__unset__"
		button.button_pressed = true
		_expect(Game.build_selected_kind == id,
			"  toggling '%s' on actually selects it (got '%s')" % [id, Game.build_selected_kind])

	hud.free()


## The ghost used to be drawn through the zone root's own _draw() — which
## sits at z_index -5 so the floor renders behind entities — so the ghost
## rendered behind the floor tilemap and everything else, permanently
## invisible. build_ghost.gd is a separate CanvasItem specifically to avoid
## that; this locks the fix in.
func _check_build_ghost_layering() -> void:
	print("\n[5] build ghost renders above the zone, not behind it")
	var zone = load("res://scenes/world/pradera.tscn").instantiate()
	add_child(zone)
	await get_tree().physics_frame

	var ghost: Node2D = zone.get_node_or_null("BuildGhost")
	_expect(ghost != null, "the zone spawns a BuildGhost child")
	if ghost:
		_expect(not ghost.z_as_relative,
			"  it opts out of z_as_relative so the zone's z_index=-5 can't hide it")
		_expect(ghost.z_index > 0, "  and sits above everything (z_index=%d)" % ghost.z_index)

	zone.free()


## Q/E (see hud.gd) sets Game.build_rotation; placing has to actually carry
## that onto the marker, not just the ghost preview. Cosmetic for today's
## round mob/resource art. The structure category that landed later
## (StructureMarker) does NOT use this — a cell's orientation is whichever
## shape button was clicked (StructureMarker.piece), not a rotation
## transform, so world_zone.gd's _place_marker() skips this assignment for
## wall/floor kinds.
func _check_rotation() -> void:
	print("\n[6] Game.build_rotation is applied when a marker is placed")
	var zone := _make_zone()
	var original_rotation := Game.build_rotation
	Game.build_rotation = PI / 2.0
	zone._place_marker("mob", Vector2(0, 0))
	Game.build_rotation = original_rotation

	var markers: Node = zone.get_node_or_null("Markers")
	_expect(markers != null and markers.get_child_count() == 1, "the marker was placed")
	if markers and markers.get_child_count() == 1:
		var marker: Node2D = markers.get_child(0)
		_expect(is_equal_approx(marker.rotation, PI / 2.0),
			"  and carries the rotation that was selected at placement time")

	zone.free()


## BuildingMarker.FIXED_FRONT_KINDS (house/mansion/bank) must always place
## facing front regardless of Game.build_rotation ("de frente sí o sí" —
## unlike a mob/barrel, a building's art was only ever drawn from one side).
## CARDINAL_ROTATE_KINDS (market/blacksmith/dock) instead snap to the
## nearest of the 4 cardinal directions rather than either the free 45° a
## plain prop gets or FIXED_FRONT's hard 0 — and a CARDINAL_ROTATE_KINDS
## member WITH real directional art (blacksmith: has_directional_art()==true)
## swaps its sprite (facing_steps) instead of getting a Transform rotation at
## all, unlike one without it yet (market: still rotates its one sprite).
## See BuildingMarker.placement_for().
func _check_building_rotation() -> void:
	print("\n[6b] building placement rotation: fixed-front vs. 4-cardinal snap vs. directional swap")
	var zone := _make_zone()
	var original_rotation := Game.build_rotation

	Game.build_rotation = PI / 3.0 # ~60°, deliberately not a "nice" angle
	zone._place_marker("building_mansion", Vector2(0, 0))
	zone._place_marker("building_house_small_a", Vector2(300, 0))
	zone._place_marker("building_bank", Vector2(-300, 0))

	# Close to 90° (100°) so the snap target is unambiguous either way.
	Game.build_rotation = deg_to_rad(100.0)
	zone._place_marker("building_market_produce", Vector2(600, 0))

	# Close to 180° -> facing_steps should land on index 2.
	Game.build_rotation = deg_to_rad(190.0)
	zone._place_marker("building_blacksmith", Vector2(0, 600))
	Game.build_rotation = original_rotation

	var markers: Node = zone.get_node_or_null("Markers")
	_expect(markers != null and markers.get_child_count() == 5, "all five buildings were placed")
	for child in markers.get_children():
		var b := child as BuildingMarker
		if b.building_id in ["mansion", "house_small_a", "bank"]:
			_expect(is_equal_approx(b.rotation, 0.0),
				"'%s' ignores build_rotation and faces front (got %.2f rad)" % [b.building_id, b.rotation])
		elif b.building_id == "market_produce":
			_expect(is_equal_approx(b.rotation, PI / 2.0),
				"'market_produce' (no directional art yet) snapped its ONE sprite to the nearest cardinal direction (got %.2f rad, expected PI/2)" % b.rotation)
		elif b.building_id == "blacksmith":
			_expect(is_equal_approx(b.rotation, 0.0) and b.facing_steps == 2,
				"'blacksmith' (has directional art) got NO Transform rotation and swapped to facing_steps=2 instead (rotation=%.2f, facing_steps=%d)" % [b.rotation, b.facing_steps])

	zone.free()


## The ghost turning red near an occupied spot only matters if a click there
## actually refuses — otherwise it's a preview that lies. Covers both
## invalidity reasons: outside the zone, and too close to something already
## placed.
func _check_placement_validity() -> void:
	print("\n[7] invalid placements (out of bounds / too close) are refused")
	var zone := _make_zone()
	zone.world_size = Vector2(400, 400)

	_expect(zone.is_placement_valid(Vector2(0, 0)), "the zone centre is valid")
	_expect(not zone.is_placement_valid(Vector2(1000, 1000)),
		"far outside world_size is invalid")

	zone._place_marker("tree", Vector2(0, 0))
	var markers: Node = zone.get_node_or_null("Markers")
	_expect(markers != null and markers.get_child_count() == 1, "the first tree was placed")

	_expect(not zone.is_placement_valid(Vector2(5, 5)),
		"right next to an existing marker is invalid (too close)")
	zone._place_marker("tree", Vector2(5, 5))
	_expect(markers.get_child_count() == 1,
		"  so _place_marker() actually refused it — still just the one tree")

	zone._place_marker("tree", Vector2(2000, 2000))
	_expect(markers.get_child_count() == 1,
		"an out-of-bounds click is refused too")

	zone.free()


## Structure cells are grid-snapped and deduplicated per cell — unlike every
## other marker kind, which is free-placed and only rejects on distance.
func _check_structure_placement() -> void:
	print("\n[8] structure cells: grid snap, dedup, door toggle, removal")
	var zone := _make_zone()

	zone._place_marker("wall_n", Vector2(5, -3)) # off-grid click, should snap
	var markers: Node = zone.get_node_or_null("Markers")
	_expect(markers != null and markers.get_child_count() == 1, "placing a wall adds one marker")
	var cell0: StructureMarker = markers.get_child(0)
	_expect(cell0.grid_pos == Vector2i(0, 0), "  snapped to the nearest grid cell (%s)" % cell0.grid_pos)
	_expect(cell0.wall_decor == "", "  no wall_decor by default")

	zone._place_marker("wall_n", Vector2(3, 1)) # snaps to the SAME cell as above
	_expect(markers.get_child_count() == 1,
		"placing another wall on the same cell is a no-op, not a duplicate")

	zone._place_marker("wall_n", Vector2(32, 0)) # the next cell over
	_expect(markers.get_child_count() == 2, "an actually-new cell is added (%d)" % markers.get_child_count())

	# A wall next to unrelated clutter must still place — this is the exact
	# hole is_placement_valid()'s MIN_MARKER_SPACING(=20) used to punch in a
	# room whenever some unrelated marker happened to sit within 20px of a
	# grid point (see is_within_bounds()'s doc comment).
	zone._place_marker("tree", Vector2(70, 0))
	zone._place_marker("wall_n", Vector2(64, 0)) # 6px from the tree above, would fail is_placement_valid()
	_expect(markers.get_child_count() == 4,
		"a wall places fine right next to unrelated clutter (tree), unlike ordinary markers")

	zone._place_marker("door", Vector2(0, 0))
	_expect(cell0.wall_decor == "door", "the door tool paints wall_decor='door' on the existing cell there")
	zone._place_marker("door", Vector2(0, 0))
	_expect(cell0.wall_decor == "", "  painting the same kind again clears it (toggle)")
	zone._place_marker("window_small", Vector2(0, 0))
	_expect(cell0.wall_decor == "window_small", "  a DIFFERENT wall_decor kind replaces whatever was there")
	zone._place_marker("door", Vector2(0, 0))
	_expect(cell0.wall_decor == "door", "  including replacing a window with a door")
	cell0.wall_decor = ""

	var before_noop_door := markers.get_child_count()
	zone._place_marker("door", Vector2(500, 500))
	_expect(markers.get_child_count() == before_noop_door,
		"the door tool over empty space does nothing (no marker to paint onto)")

	var before_removal := markers.get_child_count()
	zone._remove_nearest_marker(Vector2(0, 0))
	_expect(markers.get_child_count() == before_removal - 1,
		"right-click removal works on structure cells too")

	zone.free()


## save_markers_layout()/_load_markers_override() is the same generic
## PackedScene round trip every marker type already goes through — this
## confirms StructureMarker's grid_pos/wall_decor actually survive it, not
## just that a node with the right script name comes back.
func _check_structure_save_round_trip() -> void:
	print("\n[9] StructureMarker survives save_markers_layout() round trip")
	var zone := _make_zone()
	zone._place_marker("wall_n", Vector2(0, 0))
	zone._place_marker("wall_n", Vector2(32, 0))
	zone._place_marker("door", Vector2(32, 0))

	_expect(zone.save_markers_layout(), "save_markers_layout() succeeds with structure cells present")

	var zone2 := _make_zone()
	zone2._load_markers_override()
	var markers2: Node = zone2.get_node_or_null("Markers")
	_expect(markers2 != null and markers2.get_child_count() == 2,
		"both structure cells came back (%d)" % (markers2.get_child_count() if markers2 else -1))

	var by_cell := {}
	if markers2:
		for child in markers2.get_children():
			by_cell[(child as StructureMarker).grid_pos] = child
	_expect(by_cell.has(Vector2i(0, 0)) and (by_cell[Vector2i(0, 0)] as StructureMarker).wall_decor == "",
		"the plain wall cell restored with no wall_decor")
	_expect(by_cell.has(Vector2i(1, 0)) and (by_cell[Vector2i(1, 0)] as StructureMarker).wall_decor == "door",
		"the door cell restored with wall_decor='door'")

	zone.free()
	zone2.free()


## Every roof piece source_id currently painting `material`, flattened
## across StructureTileset.ROOF_PIECES — used because a rendered roof cell
## only tells you a source_id, and which PIECE that id belongs to is not
## interesting here, only which material it is.
func _roof_source_ids_for(zone, material: String) -> Array:
	var out: Array = []
	for piece in zone._roof_piece_source_ids:
		var by_material: Dictionary = zone._roof_piece_source_ids[piece]
		if by_material.has(material):
			out.append(int(by_material[material]))
	return out


## The point of the whole pipeline: a marker's grid_pos/piece/wall_material
## actually land the right sprite in the right TileMapLayer cell — no
## neighbour inference any more, so this checks the WIRING (StructureMarker
## -> _wall_piece_source_ids -> the TileMapLayer cell) rather than a shape
## computation. Needs a REAL zone (world_zone.gd's _ready() builds the
## Structures/Roof layers _make_zone()'s bare zone never gets) —
## pradera.tscn, same as validate_zone_builder.gd, with its saved markers
## override parked so this doesn't depend on whatever's been placed there by
## hand.
func _check_structure_rendering() -> void:
	print("\n[10] placed pieces actually paint the Structures/Roof TileMapLayers")
	const PRADERA_SCENE := "res://scenes/world/pradera.tscn"
	const PRADERA_OVERRIDE := "res://scenes/world/pradera_markers.tscn"
	var override_parked := false
	if ResourceLoader.exists(PRADERA_OVERRIDE):
		DirAccess.rename_absolute(PRADERA_OVERRIDE, PRADERA_OVERRIDE + ".parked")
		override_parked = true

	var zone = load(PRADERA_SCENE).instantiate()
	_clear_markers(zone)
	add_child(zone)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Three independent cells: a north corner in brick, a south (front-
	# facing) wall in stone, and an explicit floor tile — enough to cover
	# piece selection and material selection as two independent axes.
	var original_material := Game.build_wall_material
	Game.build_wall_material = "brick"
	zone._place_marker("corner_out_ne", Vector2(-10 * 32, -10 * 32))
	Game.build_wall_material = "stone"
	zone._place_marker("wall_s", Vector2(-10 * 32, -9 * 32))
	zone._place_marker("floor", Vector2(-9 * 32, -10 * 32))
	Game.build_wall_material = original_material

	var structures: TileMapLayer = zone.get_node_or_null("Structures")
	var roof: TileMapLayer = zone.get_node_or_null("Roof")
	_expect(structures is TileMapLayer, "the zone built its Structures TileMapLayer")
	_expect(roof != null, "  plus Roof")
	if structures == null or roof == null:
		zone.free()
		return

	var corner_cell := Vector2i(-10, -10)
	var wall_s_cell := Vector2i(-10, -9)
	var floor_cell := Vector2i(-9, -10)

	_expect(structures.get_cell_source_id(corner_cell)
			== int(zone._wall_piece_source_ids["corner_out_ne"]["brick"]),
		"the NE corner cell uses corner_out_ne's BRICK source id")
	_expect(structures.get_cell_source_id(wall_s_cell)
			== int(zone._wall_piece_source_ids["wall_s"]["stone"]),
		"  the south wall cell uses wall_s's STONE source id")
	_expect(structures.get_cell_source_id(floor_cell) == zone._floor_source_id,
		"  the floor cell uses the shared floor source id")

	# Two different pieces never share a sprite, and the same piece in two
	# different materials never shares one either — the two axes really are
	# independent.
	_expect(structures.get_cell_source_id(corner_cell) != structures.get_cell_source_id(wall_s_cell),
		"a corner and a straight wall do NOT share a sprite")
	_expect(int(zone._wall_piece_source_ids["wall_s"]["stone"])
			!= int(zone._wall_piece_source_ids["wall_s"]["brick"]),
		"  the same shape in two different materials has two different sprites")

	# Painting walls must not touch the roof layer at all: one brush, one
	# layer. This is the coupling that used to exist and was reported.
	_expect(roof.get_used_cells().is_empty(), "painting walls wrote NOTHING to the roof layer")

	# Roof only appears through the explicit action / hand-painting.
	var original_roof_material := Game.build_roof_material
	Game.build_roof_material = "slate"
	var added: int = zone.generate_roof_over_walls()
	Game.build_roof_material = original_roof_material
	_expect(added > 0, "the explicit generate_roof_over_walls() adds roof cells (%d)" % added)
	_expect(not roof.get_used_cells().is_empty(), "  and the roof layer now has content")
	# Regression: a wall piece is taller than one cell, so its upper half
	# rises into the row above its own footprint — the roof has to extend
	# one row further north over any wall cell it covers, or that sliver of
	# wall pokes out above the roofline (reported after this fix first
	# shipped without it). corner_cell and floor_cell both have a wall/floor
	# marker AND ended up under the generated roof, so both must show the
	# extra eave row directly above them.
	_expect(roof.get_cell_source_id(corner_cell + Vector2i(0, -1)) != -1,
		"  the roof extends one row north past a wall cell it covers (eave overhang)")
	_expect(roof.get_cell_source_id(floor_cell + Vector2i(0, -1)) != -1,
		"  ...same for the floor cell's row")

	# Regression: the eave-overhang extension above must NOT fire for an
	# east/west wall with nothing north of it — reported as "1 click painted
	# 2 cells" and a roof_eave_e stacked into a tall, blocky double tile
	# instead of a slim side eave. A standalone wall_e cell (no wall/roof
	# anywhere near it, notably nothing directly above) with a single
	# roof_eave_e placed on it must paint exactly that one cell.
	var stub_cell := Vector2i(5, 5)
	zone._place_marker("wall_e", BuildGrid.cell_to_world(stub_cell))
	Game.build_roof_material = "slate"
	zone._place_marker("roof_eave_e", BuildGrid.cell_to_world(stub_cell))
	Game.build_roof_material = original_roof_material
	_expect(roof.get_cell_source_id(stub_cell) != -1,
		"a standalone roof_eave_e over an isolated wall_e paints its own cell")
	_expect(roof.get_cell_source_id(stub_cell + Vector2i(0, -1)) == -1,
		"  but does NOT also paint the cell above it (no north-facing piece there to extend)")

	# Regression: same bug, different trigger — a north-facing CORNER
	# (roof_hip_ne) placed on completely open ground, no wall/floor marker
	# under it at all, also must not duplicate. Reported as "las esquinas se
	# ponen dobles con 1 clic" after the eave_e/w fix above was narrowed to
	# only the ROOF piece's own type (NORTH_FACING_ROOF_PIECES) without also
	# re-requiring a wall/floor cell underneath — hip_ne/hip_nw need BOTH.
	var lone_corner_cell := Vector2i(6, 6)
	Game.build_roof_material = "slate"
	zone._place_marker("roof_hip_ne", BuildGrid.cell_to_world(lone_corner_cell))
	Game.build_roof_material = original_roof_material
	_expect(roof.get_cell_source_id(lone_corner_cell) != -1,
		"a standalone roof_hip_ne with no wall under it paints its own cell")
	_expect(roof.get_cell_source_id(lone_corner_cell + Vector2i(0, -1)) == -1,
		"  but does NOT also paint the cell above it (nothing there to hide the bleed of)")

	# wall_decor still rides on top of the wall without replacing it — placed
	# on the south wall cell from above, which the auto-fill DID roof (every
	# wall gets roofed uniformly now); painting the door still leaves the
	# wall itself intact underneath, and the door exemption in
	# _rebuild_structures() keeps the roof from actually painting over it.
	var wall_decor_layer: TileMapLayer = zone.get_node_or_null("WallDecor")
	zone._place_marker("door", Vector2(-10 * 32, -9 * 32))
	_expect(structures.get_cell_source_id(wall_s_cell) != -1,
		"painting a door leaves the wall underneath painted")
	_expect(wall_decor_layer != null and wall_decor_layer.get_cell_source_id(wall_s_cell) == zone._wall_decor_source_ids["door"],
		"  and the door itself is a separate overlay on the WallDecor layer")

	zone.free()

	# Game.build_roof_material (R, see hud.gd) is stamped onto a RoofMarker
	# at placement time — a room roofed with it set to "red" should paint
	# that material instead of the default "slate". A FRESH zone: same
	# reasoning as before, one bounding box per zone.
	var zone2 = load(PRADERA_SCENE).instantiate()
	_clear_markers(zone2)
	add_child(zone2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	zone2._place_marker("wall_n", Vector2(0, 0))
	zone2._place_marker("wall_n", Vector2(0, -32))
	zone2._place_marker("wall_n", Vector2(0, 32))
	zone2._place_marker("wall_n", Vector2(-32, 0))
	zone2._place_marker("wall_n", Vector2(32, 0))
	var original_roof_material2 := Game.build_roof_material
	Game.build_roof_material = "red"
	zone2.generate_roof_over_walls() # explicit action; walls alone never roof
	Game.build_roof_material = original_roof_material2
	var roof2: TileMapLayer = zone2.get_node_or_null("Roof")
	var red_room_center := roof2.get_cell_source_id(Vector2i(0, 0)) if roof2 else -1
	_expect(_roof_source_ids_for(zone2, "red").has(red_room_center),
		"a room roofed with Game.build_roof_material='red' paints the red roof material")
	zone2.free()

	if override_parked:
		DirAccess.rename_absolute(PRADERA_OVERRIDE + ".parked", PRADERA_OVERRIDE)


## DecorMarker: one loose decoration prop per placeable id ("decor_<kind>",
## see world_zone.gd's _instantiate_marker()), free-placed like a POI —
## covers the id -> decor_id round trip and that every kind actually
## resolves a real texture, the same shape as [3]'s BuildIcons check but
## also exercising the actual _place_marker() path.
func _check_decor_placement() -> void:
	print("\n[12] DecorMarker: placement and every kind resolves a real texture")
	var zone := _make_zone()

	zone._place_marker("decor_barrel", Vector2(40, 70))
	var markers: Node = zone.get_node_or_null("Markers")
	_expect(markers != null and markers.get_child_count() == 1, "placing a decor prop adds one marker")
	var prop: DecorMarker = markers.get_child(0)
	_expect(prop.decor_id == "barrel", "the kind from the palette id round-trips")
	_expect(is_equal_approx(prop.global_position.x, 40.0) and is_equal_approx(prop.global_position.y, 70.0),
		"a decor prop is free-placed (not grid-snapped like a wall cell)")

	for kind in ["barrel", "crate", "crate_stack", "banner", "cart", "cart_wheel",
			"bush", "spigot", "fence", "garden_bed", "door_wood",
			"chimney_red", "chimney_blue", "roof_gable_red", "roof_gable_blue"]:
		var d := DecorMarker.new()
		d.decor_id = kind
		add_child(d)
		await get_tree().process_frame
		_expect(d._tex != null, "'%s' resolves a real texture" % kind)
		d.free()

	zone.free()


## BuildingMarker: whole prefab buildings ("building_<kind>", see
## world_zone.gd's _instantiate_marker()) — free-placed like DecorMarker, but
## with a footprint-sized clearance instead of the flat MIN_MARKER_SPACING
## (see BuildingMarker.clearance_for()/is_placement_valid()): covers the
## id -> building_id round trip, that a second building placed too close is
## refused while one placed clear of it is not, and that every kind resolves
## a real texture.
func _check_building_placement() -> void:
	print("\n[12b] BuildingMarker: placement, footprint clearance, texture resolution")
	var zone := _make_zone()

	zone._place_marker("building_house_small_a", Vector2(40, 70))
	var markers: Node = zone.get_node_or_null("Markers")
	_expect(markers != null and markers.get_child_count() == 1, "placing a building adds one marker")
	var house: BuildingMarker = markers.get_child(0)
	_expect(house.building_id == "house_small_a", "the kind from the palette id round-trips")
	_expect(is_equal_approx(house.global_position.x, 40.0) and is_equal_approx(house.global_position.y, 70.0),
		"a building is free-placed (not grid-snapped like a wall cell)")

	# Well within the sprite's own clearance (house_small_a is 128x160, so
	# clearance_for() is ~72px) but well past the flat 20px MIN_MARKER_SPACING
	# every other free-placed prop would have allowed — proves the bigger,
	# footprint-sized check is the one actually being applied.
	zone._place_marker("building_house_small_b", Vector2(60, 70))
	_expect(markers.get_child_count() == 1,
		"a second building too close for its OWN footprint is refused (%d)" % markers.get_child_count())

	# Clear of house_small_a's footprint.
	zone._place_marker("building_house_small_b", Vector2(300, 70))
	_expect(markers.get_child_count() == 2,
		"a building placed clear of the footprint is accepted (%d)" % markers.get_child_count())

	for kind in ["house_small_a", "house_small_b", "house_small_c", "house_small_d",
			"house_small_e", "house_small_f",
			"house_medium_common_a", "house_medium_common_b", "house_medium_common_c",
			"house_medium_common_d", "house_medium_common_e",
			"house_medium_noble", "house_medium_mage", "house_medium_gothic", "house_medium_cozy",
			"house_large_common", "house_large_noble", "house_large_mage",
			"house_large_gothic", "house_large_cozy",
			"house_grand_common", "house_grand_noble", "house_grand_mage",
			"house_grand_gothic", "house_grand_cozy",
			"house_palace_common", "house_palace_noble", "house_palace_mage",
			"house_palace_gothic", "house_palace_cozy",
			"mansion", "blacksmith", "bank", "general_goods", "inn", "temple",
			"market_produce", "market_textiles", "market_spices", "dock"]:
		var b := BuildingMarker.new()
		b.building_id = kind
		add_child(b)
		await get_tree().process_frame
		# Dos modos válidos desde que un edificio puede ser una escena armada a
		# mano (ver BuildingMarker): o instanció su escena, o cayó al PNG
		# plano. Lo que no puede es no mostrar nada.
		_expect(b._tex != null or b._instance != null,
			"'%s' resolves art (escena o sprite)" % kind)
		b.free()

	zone.free()


## CollisionMarker: grid snap, dedup, removal, and that _rebuild_collision()
## actually spawns/frees a real StaticBody2D — same "don't just trust marker
## bookkeeping" reasoning as the structure rendering check above.
## _place_marker() itself calls _rebuild_collision() with no _build_*()
## prerequisite (no TileMapLayer involved), so nothing needs pre-building.
func _check_collision_placement() -> void:
	print("\n[13c] CollisionMarker: grid snap, dedup, removal, real StaticBody2D")
	var zone := _make_zone()

	zone._place_marker("collision_block", Vector2(5, -3)) # off-grid click, should snap
	var markers: Node = zone.get_node_or_null("Markers")
	_expect(markers != null and markers.get_child_count() == 1, "placing a collision cell adds one marker")
	var cell0: CollisionMarker = markers.get_child(0)
	_expect(cell0.grid_pos == Vector2i(0, 0), "  snapped to the nearest grid cell (%s)" % cell0.grid_pos)

	var body: Node = zone._collision_bodies.get(cell0)
	_expect(body != null and is_instance_valid(body) and body is StaticBody2D,
		"a real StaticBody2D was spawned for it")
	if body:
		_expect(is_equal_approx((body as Node2D).global_position.x, 0.0)
			and is_equal_approx((body as Node2D).global_position.y, 0.0),
			"  positioned at the cell's world position")
		_expect((body as StaticBody2D).collision_layer == 1, "  on collision_layer 1, same as the zone's own walls")

	zone._place_marker("collision_block", Vector2(3, 1)) # snaps to the SAME cell as above
	_expect(markers.get_child_count() == 1,
		"placing another collision cell on the same cell is a no-op, not a duplicate")

	zone._place_marker("collision_block", Vector2(32, 0)) # the next cell over
	_expect(markers.get_child_count() == 2, "an actually-new cell is added (%d)" % markers.get_child_count())
	_expect(zone._collision_bodies.size() == 2, "  and it got its own body (%d bodies)" % zone._collision_bodies.size())

	zone._remove_nearest_marker(Vector2(0, 0))
	_expect(markers.get_child_count() == 1, "right-click removal works on collision cells too")
	_expect(zone._collision_bodies.size() == 1, "  and its body was freed, not left orphaned (%d bodies)" % zone._collision_bodies.size())
	# queue_free() is deferred, not immediate — same reasoning as
	# _check_place_and_remove()'s mob-removal check, give it a frame to land.
	await get_tree().process_frame
	_expect(not is_instance_valid(body), "  the freed body is actually gone (queue_free() landed)")

	zone.free()


## Ground and structure cells must never block a free-placed prop. The
## minimum-spacing rule exists so two barrels don't end up inside each other;
## applying it to grid cells made a painted area unbuildable (cells sit 32px
## apart, the spacing radius is 20px, so every painted cell blanketed the map)
## and also stopped anything from being placed inside a finished room.
func _check_props_over_ground() -> void:
	print("\n[13g] Props can be placed on painted floor, collision cells and inside rooms")
	for grid_kind in ["floor_pasto_01", "collision_block", "wall_n", "roof_eave_n"]:
		var m := BuildPlacement.make_marker(grid_kind, "stone", "slate")
		if m == null:
			continue
		_expect(not BuildPlacement.blocks_free_placement(m),
			"a '%s' cell does not crowd free placement" % grid_kind)
		m.free()
	for free_kind in ["decor_barrel", "mob", "tree", "building_bank", "vendor"]:
		var m2 := BuildPlacement.make_marker(free_kind)
		_expect(m2 != null and BuildPlacement.blocks_free_placement(m2),
			"a '%s' still does crowd free placement" % free_kind)
		if m2:
			m2.free()

	# End to end: paint a cell, then drop a prop on the exact same spot.
	var zone := _make_zone()
	zone._place_marker("floor_pasto_01", Vector2(0, 0))
	var markers: Node = zone.get_node_or_null("Markers")
	_expect(markers != null and markers.get_child_count() == 1, "painted one floor cell")
	_expect(zone.is_placement_valid(Vector2(0, 0), "decor_barrel"),
		"a prop is allowed on the very cell that was just painted")
	zone._place_marker("decor_barrel", Vector2(0, 0))
	_expect(markers.get_child_count() == 2,
		"  and placing it actually adds the marker (%d)" % markers.get_child_count())
	# ...but two props on the same spot still refuse, which is the rule's point.
	_expect(not zone.is_placement_valid(Vector2(0, 0), "decor_crate"),
		"two free-placed props on the same spot are still refused")
	zone.free()


## Draw order. The ground layers are created with add_child(), which appends
## them AFTER "Markers" in the tree, and equal-z siblings draw in tree order —
## so without explicit z a painted road covered the barrels standing on it,
## and a prop placed before a house disappeared behind it. These pin the
## whole stack: ground under markers, decor over buildings.
func _check_draw_order() -> void:
	print("\n[13f] Draw order: decor over floor tiles and over buildings")
	_expect(WorldZone.Z_FLOOR < WorldZone.Z_SUELO,
		"the base floor is under the painted floor (%d < %d)" % [WorldZone.Z_FLOOR, WorldZone.Z_SUELO])
	_expect(WorldZone.Z_SUELO < WorldZone.Z_STRUCTURES,
		"the painted floor is under the structures (%d < %d)" % [WorldZone.Z_SUELO, WorldZone.Z_STRUCTURES])
	_expect(WorldZone.Z_STRUCTURES < WorldZone.Z_BUILDING,
		"structures are under the markers (%d < %d)" % [WorldZone.Z_STRUCTURES, WorldZone.Z_BUILDING])
	_expect(WorldZone.Z_BUILDING < WorldZone.Z_DECOR,
		"decor draws OVER prefab buildings (%d < %d)" % [WorldZone.Z_BUILDING, WorldZone.Z_DECOR])

	# The constants are only worth anything if the nodes actually carry them.
	# ensure_render_layers() is the EDITOR's entry point and must pin the same
	# stack as Play does: it used to skip the Floor (only _build_floor(), a
	# Play-only function, set it), so every tile painted in the editor went
	# under the grass and looked like nothing happened.
	var zone := _make_zone()
	var base_floor := TileMapLayer.new()
	base_floor.name = "Floor"
	zone.add_child(base_floor)
	zone.ensure_render_layers()
	_expect(base_floor.z_index == WorldZone.Z_FLOOR,
		"ensure_render_layers() pins the Floor to Z_FLOOR (got %d)" % base_floor.z_index)
	var suelo_editor: TileMapLayer = zone.get_node_or_null("Suelo")
	_expect(suelo_editor != null and base_floor.z_index < suelo_editor.z_index,
		"  so a painted tile lands OVER the base floor on the editor path too")

	zone._build_floor_tiles()
	var suelo: TileMapLayer = zone.get_node_or_null("Suelo")
	_expect(suelo != null and suelo.z_index == WorldZone.Z_SUELO,
		"the 'Suelo' layer is built at Z_SUELO (got %d)" % (999 if suelo == null else suelo.z_index))
	_expect(suelo != null and suelo.z_as_relative,
		"  and stays RELATIVE, so it orders against the markers rather than the whole canvas")

	# Parented to THIS node, not to the bare zone: _make_zone() deliberately
	# never enters the scene tree, and _ready() (where the z is applied) only
	# fires on tree entry — markers under it would report a default z and the
	# check would pass or fail for the wrong reason.
	var decor := DecorMarker.new()
	add_child(decor)
	var building := BuildingMarker.new()
	add_child(building)
	_expect(decor.z_index == WorldZone.Z_DECOR, "a DecorMarker carries Z_DECOR (got %d)" % decor.z_index)
	_expect(building.z_index == WorldZone.Z_BUILDING, "a BuildingMarker carries Z_BUILDING (got %d)" % building.z_index)
	_expect(decor.z_index > building.z_index,
		"  so decor wins over a building regardless of which was placed first")
	decor.free()
	building.free()
	zone.free()


## The in-game tool and the Godot editor plugin must place the SAME thing for
## the same palette id. They used to hold two hand-synced copies of that
## mapping and drifted every time an id was added — a piece that worked in
## game and silently did nothing in the editor. Both now go through
## BuildPlacement; this walks the whole catalog to prove it, so a future id
## can't be taught to only one of them.
func _check_build_placement_parity() -> void:
	print("\n[13e] The editor plugin and the in-game tool agree on every id")
	var plugin_src := FileAccess.get_file_as_string("res://addons/build_mode_editor/plugin.gd")
	var zone_src := FileAccess.get_file_as_string("res://scripts/world/world_zone.gd")

	# Neither may carry its own copy of the id -> marker-class mapping.
	for pair in [["plugin.gd", plugin_src], ["world_zone.gd", zone_src]]:
		var name: String = pair[0]
		var src: String = pair[1]
		_expect(src.contains("BuildPlacement."),
			"%s routes placement through BuildPlacement" % name)

	# The editor addon is the OTHER front-end for all of this, and nothing
	# else here loads it — so a parse error in it only ever showed up as an
	# "import reported N error line(s)" warning while every suite still went
	# green, and the first sign was the whole tool being dead in Godot.
	# load() returns null for a script that fails to parse.
	for addon_script in ["res://addons/build_mode_editor/plugin.gd",
			"res://addons/build_mode_editor/build_dock.gd"]:
		_expect(ResourceLoader.exists(addon_script) and load(addon_script) != null,
			"the editor addon parses (%s)" % addon_script.get_file())

	var missing: Array[String] = []
	var not_a_node: Array[String] = []
	for kind in BuildCatalog.all_ids():
		var marker := BuildPlacement.make_marker(kind, "stone", "slate")
		if marker == null:
			# Two kinds legitimately have no marker class. Wall decor paints
			# onto an existing wall, and the free brush paints into a coverage
			# mask (see PaintLayer) — it has no per-cell anything to place.
			if not StructureTileset.WALL_DECOR.has(kind) and not PaintLayer.is_paint_id(kind):
				missing.append(kind)
			continue
		if not (marker is Node2D):
			not_a_node.append(kind)
		marker.free()
	_expect(missing.is_empty(),
		"every placeable id maps to a marker class (unmapped: %s)" % str(missing))
	_expect(not_a_node.is_empty(),
		"every marker is a Node2D (bad: %s)" % str(not_a_node))

	# Grid classification has to agree with what the ghost preview snaps, or
	# the preview sits somewhere the piece won't land.
	for kind in ["wall_n", "roof_eave_n", "collision_block"]:
		_expect(BuildPlacement.is_grid_kind(kind), "'%s' is a grid kind" % kind)
	for kind in ["decor_barrel", "mob", "tree", "building_bank"]:
		_expect(not BuildPlacement.is_grid_kind(kind), "'%s' is free-placed" % kind)
	var floor_ids := BuildCatalog.ids_in_category("suelo").filter(
		func(id: String) -> bool: return id.begins_with("floor_"))
	if not floor_ids.is_empty():
		_expect(BuildPlacement.is_grid_kind(floor_ids[0]),
			"painted floor tiles snap to the grid ('%s')" % floor_ids[0])
		# The bare "floor" structure piece must NOT be mistaken for one.
		_expect(not BuildPlacement.is_floor_tile("floor"),
			"the structure kit's 'floor' piece is not treated as a painted tile")


## The "SUELO" painter (FloorTileMarker + PaintedFloorTileset). Unlike the other
## grid tools, painting the same cell twice with DIFFERENT tiles has to
## replace what's there rather than refuse (that's what painting over
## something means), while repainting the identical tile must stay a no-op —
## otherwise one drag across a cell stacks duplicate markers on it.
func _check_floor_tile_painting() -> void:
	print("\n[13d] FloorTileMarker: paint, repaint-in-place, dedup, removal")
	var ids := BuildCatalog.ids_in_category("suelo").filter(
		func(id: String) -> bool: return id.begins_with("floor_"))
	_expect(ids.size() > 0, "the 'suelo' category exposes paintable floor_* ids (%d)" % ids.size())
	if ids.is_empty():
		return
	var kind_a: String = ids[0]
	var kind_b: String = ids[mini(1, ids.size() - 1)]

	var zone := _make_zone()
	zone._build_floor_tiles()
	var layer: TileMapLayer = zone.get_node_or_null("Suelo")
	_expect(layer != null, "a 'Suelo' TileMapLayer is created")
	_expect(layer != null and layer.tile_set != null
		and layer.tile_set.get_source_count() == ids.size(),
		"  its TileSet has one source per paintable id (%d of %d)"
		% [0 if layer == null or layer.tile_set == null else layer.tile_set.get_source_count(), ids.size()])

	zone._place_marker(kind_a, Vector2(5, -3)) # off-grid click, should snap
	var markers: Node = zone.get_node_or_null("Markers")
	_expect(markers != null and markers.get_child_count() == 1, "painting a cell adds one marker")
	var m0: FloorTileMarker = markers.get_child(0)
	_expect(m0.grid_pos == Vector2i(0, 0), "  snapped to the nearest cell (%s)" % m0.grid_pos)
	_expect(m0.tile_id == kind_a.trim_prefix("floor_"), "  carrying the picked tile id (%s)" % m0.tile_id)
	_expect(layer != null and layer.get_cell_source_id(Vector2i(0, 0)) >= 0,
		"  and the tile is actually painted into the layer")

	zone._place_marker(kind_a, Vector2(3, 1)) # same cell, same tile
	_expect(markers.get_child_count() == 1,
		"repainting the same cell with the same tile is a no-op (%d markers)" % markers.get_child_count())

	if kind_b != kind_a:
		zone._place_marker(kind_b, Vector2(3, 1)) # same cell, DIFFERENT tile
		_expect(markers.get_child_count() == 1,
			"repainting it with a different tile replaces rather than stacks (%d markers)"
			% markers.get_child_count())
		var m1: FloorTileMarker = markers.get_child(0)
		_expect(m1.tile_id == kind_b.trim_prefix("floor_"),
			"  and the cell now shows the new tile (%s)" % m1.tile_id)

	zone._place_marker(kind_a, Vector2(32, 0)) # the next cell over
	_expect(markers.get_child_count() == 2, "an actually-new cell is added (%d)" % markers.get_child_count())
	_expect(layer != null and layer.get_used_cells().size() == 2,
		"  both cells are painted (%d)" % (0 if layer == null else layer.get_used_cells().size()))

	zone._remove_nearest_marker(Vector2(0, 0))
	_expect(markers.get_child_count() == 1, "right-click removal works on painted cells too")
	_expect(layer != null and layer.get_cell_source_id(Vector2i(0, 0)) == -1,
		"  and the tile is erased from the layer, not just the marker")

	zone.free()


## Build-mode undo (Ctrl+Z, see hud.gd -> world_zone.undo_build_action()).
## The important property is that ONE GESTURE is one undo step: a drag that
## painted a whole wall run has to come back off in a single press, not
## cell-by-cell, or undo is useless for actual mapping. Also covers that a
## REMOVED marker is restored as the same node with its properties intact,
## rather than a rebuilt approximation.
func _check_undo() -> void:
	print("\n[14] build-mode undo: one gesture = one step")
	var zone := _make_zone()
	var markers_of := func() -> int:
		var m: Node = zone.get_node_or_null("Markers")
		return m.get_child_count() if m else 0

	# One "gesture" that paints 4 wall cells, the way a drag does.
	zone.begin_build_action()
	for i in 4:
		zone._place_marker("wall_n", Vector2(i * 32, 0))
	_expect(markers_of.call() == 4, "a 4-cell drag placed 4 markers (%d)" % markers_of.call())

	_expect(zone.undo_build_action(), "undo reports it did something")
	_expect(markers_of.call() == 0,
		"  and the WHOLE drag came off in one step, not one cell (%d left)" % markers_of.call())

	_expect(not zone.undo_build_action(), "undo on an empty stack reports nothing to undo")

	# Separate gestures stay separate steps.
	zone.begin_build_action()
	zone._place_marker("wall_n", Vector2(0, 0))
	zone.begin_build_action()
	zone._place_marker("wall_n", Vector2(32, 0))
	_expect(markers_of.call() == 2, "two separate gestures placed two cells")
	zone.undo_build_action()
	_expect(markers_of.call() == 1, "  undoing once removes only the second gesture")
	zone.undo_build_action()
	_expect(markers_of.call() == 0, "  undoing again removes the first")

	# Undoing a REMOVAL puts the original marker back, properties intact.
	var original_material := Game.build_wall_material
	Game.build_wall_material = "brick"
	zone.begin_build_action()
	zone._place_marker("wall_n", Vector2(0, 0))
	Game.build_wall_material = original_material
	var placed: StructureMarker = zone._structure_marker_at(Vector2(0, 0))
	_expect(placed != null and placed.wall_material == "brick", "placed a brick wall cell")
	zone.begin_build_action()
	zone._remove_nearest_marker(Vector2(0, 0))
	_expect(zone._structure_marker_at(Vector2(0, 0)) == null, "  removing it clears the cell")
	zone.undo_build_action()
	var restored: StructureMarker = zone._structure_marker_at(Vector2(0, 0))
	_expect(restored != null, "  undo puts the marker back")
	_expect(restored != null and restored.wall_material == "brick",
		"  ...still brick, i.e. the same node rather than a default rebuild")

	# Undoing a wall_decor paint restores the PREVIOUS decor, not just "".
	zone.begin_build_action()
	zone._place_marker("door", Vector2(0, 0))
	_expect(restored.wall_decor == "door", "painted a door onto the cell")
	zone.begin_build_action()
	zone._place_marker("window_small", Vector2(0, 0))
	_expect(restored.wall_decor == "window_small", "  then replaced it with a window")
	zone.undo_build_action()
	_expect(restored.wall_decor == "door",
		"  undo restores the DOOR that was there before, not an empty cell")

	zone.free()


## Game.build_roof_material == "none" (the third state of R, see hud.gd):
## cells placed with it generate NO roof, which is how a walled courtyard or
## a ruin gets built. Also covers the hollow-room material inheritance —
## interior cells have no marker of their own, so they must inherit the
## surrounding material rather than snapping back to a hardcoded default.
func _check_roof_none_and_inheritance() -> void:
	print("\n[15] roof: 'none' builds roofless, hollow interiors inherit material")
	const PRADERA_SCENE := "res://scenes/world/pradera.tscn"
	const PRADERA_OVERRIDE := "res://scenes/world/pradera_markers.tscn"
	var override_parked := false
	if ResourceLoader.exists(PRADERA_OVERRIDE):
		DirAccess.rename_absolute(PRADERA_OVERRIDE, PRADERA_OVERRIDE + ".parked")
		override_parked = true
	var original := Game.build_roof_material

	# A courtyard: a solid block placed entirely with the roof set to none.
	var zone = load(PRADERA_SCENE).instantiate()
	_clear_markers(zone)
	add_child(zone)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Game.build_roof_material = "none"
	for y in range(3):
		for x in range(3):
			zone._place_marker("wall_n", Vector2((x - 10) * 32, (y - 10) * 32))
	var roof: TileMapLayer = zone.get_node_or_null("Roof")
	var structures: TileMapLayer = zone.get_node_or_null("Structures")
	_expect(structures != null and structures.get_cell_source_id(Vector2i(-9, -9)) != -1,
		"the walls of a roofless block are still built")
	var any_roof := false
	if roof:
		for c in roof.get_used_cells():
			any_roof = true
			break
	_expect(not any_roof, "  but NO roof cell is generated anywhere for it")
	Game.build_roof_material = "none"
	_expect(zone.generate_roof_over_walls() == 0,
		"  and asking to generate a roof while the selector says none does nothing")
	zone.free()

	# A HOLLOW red-roofed room: only the outline is painted, so the interior
	# cells have no marker to read a material from.
	var zone2 = load(PRADERA_SCENE).instantiate()
	_clear_markers(zone2)
	add_child(zone2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Game.build_roof_material = "red"
	for y in range(4):
		for x in range(4):
			if x != 0 and x != 3 and y != 0 and y != 3:
				continue # outline only — leave the middle hollow
			zone2._place_marker("wall_n", Vector2(x * 32, y * 32))
	zone2.generate_roof_over_walls() # explicit action
	Game.build_roof_material = original

	var roof2: TileMapLayer = zone2.get_node_or_null("Roof")
	var interior := Vector2i(1, 1) # hollow: no marker of its own
	var red_ids: Array = _roof_source_ids_for(zone2, "red")
	var slate_ids: Array = _roof_source_ids_for(zone2, "slate")
	var interior_id := roof2.get_cell_source_id(interior) if roof2 else -1
	_expect(interior_id != -1, "the hollow interior of an outlined room is still roofed")
	_expect(red_ids.has(interior_id),
		"  in the RED material the room was built with, inherited from its walls")
	_expect(not slate_ids.has(interior_id),
		"  not snapped back to the default slate (the bug this covers)")
	zone2.free()

	Game.build_roof_material = original
	if override_parked:
		DirAccess.rename_absolute(PRADERA_OVERRIDE + ".parked", PRADERA_OVERRIDE)


## Hand-painted roof (RoofMarker, the "TECHO (pintar)" category) — the
## manual counterpart to the automatic roof. Covers that it paints where
## there is no building at all (a porch/lean-to overhanging past the walls),
## that it survives the same grid dedup as other grid kinds, and that a
## manual cell overrides the automatic material on a shared cell.
func _check_manual_roof() -> void:
	print("\n[16] hand-painted roof: standalone, dedup, and overriding the auto roof")
	const PRADERA_SCENE := "res://scenes/world/pradera.tscn"
	const PRADERA_OVERRIDE := "res://scenes/world/pradera_markers.tscn"
	var override_parked := false
	if ResourceLoader.exists(PRADERA_OVERRIDE):
		DirAccess.rename_absolute(PRADERA_OVERRIDE, PRADERA_OVERRIDE + ".parked")
		override_parked = true

	var zone = load(PRADERA_SCENE).instantiate()
	_clear_markers(zone)
	add_child(zone)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Painted with no walls anywhere near it — a roof over open ground, which
	# the automatic roof can never produce since it derives from a footprint.
	# "roof_interior" stands in for any single roof shape button here — the
	# test is about placement/material, not which of the 20 shapes it is.
	var original_material := Game.build_roof_material
	Game.build_roof_material = "red"
	zone._place_marker("roof_interior", Vector2(-10 * 32, -10 * 32))
	var roof: TileMapLayer = zone.get_node_or_null("Roof")
	var painted := roof.get_cell_source_id(Vector2i(-10, -10)) if roof else -1
	_expect(painted != -1, "a roof cell painted over empty ground actually renders")
	_expect(_roof_source_ids_for(zone, "red").has(painted),
		"  in the material Game.build_roof_material asked for")
	# Regression: the north-eave extension in _rebuild_structures() (hides a
	# tall wall piece's upper half poking above the roof) is gated on the
	# roof cell sitting on top of an actual wall — a stand-alone roof piece
	# over open ground has no wall to hide, so it must render as exactly ONE
	# tile. A first version of that fix extended every roof cell
	# unconditionally, which duplicated this single placed piece into two.
	_expect(roof.get_cell_source_id(Vector2i(-10, -11)) == -1,
		"  and does NOT also paint the cell above it — one piece placed, one tile rendered")

	var markers: Node = zone.get_node_or_null("Markers")
	var before := markers.get_child_count()
	Game.build_roof_material = "slate"
	zone._place_marker("roof_interior", Vector2(-10 * 32 + 3, -10 * 32 - 2)) # same cell
	_expect(markers.get_child_count() == before,
		"painting another roof cell on the same cell is a no-op, not a duplicate")
	Game.build_roof_material = original_material

	zone._remove_nearest_marker(Vector2(-10 * 32, -10 * 32))
	_expect(roof.get_cell_source_id(Vector2i(-10, -10)) == -1,
		"right-click removal clears the painted roof cell again")
	zone.free()

	# A manual cell beats the automatic roof's material on a shared cell.
	var zone2 = load(PRADERA_SCENE).instantiate()
	_clear_markers(zone2)
	add_child(zone2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Game.build_roof_material = "slate"
	for y in range(3):
		for x in range(3):
			zone2._place_marker("wall_n", Vector2(x * 32, y * 32))
	zone2.generate_roof_over_walls() # explicit action
	var roof2: TileMapLayer = zone2.get_node_or_null("Roof")
	var interior := Vector2i(1, 1)
	_expect(_roof_source_ids_for(zone2, "slate").has(roof2.get_cell_source_id(interior)),
		"the generated roof covers the room's interior in slate")
	# Generated cells ARE RoofMarkers, so the ordinary per-cell dedup every
	# grid brush has applies to them too: painting over one is a no-op, and
	# changing its material means erasing first. There is no separate
	# "automatic" layer left for a manual cell to override.
	Game.build_roof_material = "red"
	zone2._place_marker("roof_interior", Vector2(32, 32))
	_expect(_roof_source_ids_for(zone2, "slate").has(roof2.get_cell_source_id(interior)),
		"  painting over an already-roofed cell is a no-op, not a silent overwrite")
	zone2._remove_nearest_marker(Vector2(32, 32))
	zone2._place_marker("roof_interior", Vector2(32, 32))
	_expect(_roof_source_ids_for(zone2, "red").has(roof2.get_cell_source_id(interior)),
		"  and erasing it first lets a different material be painted there")
	Game.build_roof_material = original_material
	zone2.free()

	if override_parked:
		DirAccess.rename_absolute(PRADERA_OVERRIDE + ".parked", PRADERA_OVERRIDE)


## Un edificio armado como escena (con sus colliders) en vez de un PNG plano
## — ver BuildingMarker y tools/collider_editor.gd. Lo que se cubre acá es lo
## que hace que una casa deje de ser "un sprite vacío": que el marker
## instancie la escena, que esa escena traiga un cuerpo sólido de verdad, y
## que la instancia NO termine serializada en el .tscn de la zona (si se
## guardara, arreglarle el collider a una casa no arreglaría las ya puestas).
func _check_building_scenes() -> void:
	print("\n[12c] BuildingMarker: edificios como escena, con colisión")

	_expect(BuildingMarker.has_scene("house_small_a"),
		"'house_small_a' ya está armado como escena")
	_expect(BuildingMarker.scene_path("house_small_a").ends_with("house_small_a.tscn"),
		"scene_path() resuelve el .tscn por el nombre del edificio")

	var with_scene := BuildingMarker.new()
	with_scene.building_id = "house_small_a"
	add_child(with_scene)
	await get_tree().process_frame

	_expect(with_scene._instance != null, "el marker instancia la escena del edificio")
	_expect(with_scene._tex == null,
		"con escena instanciada el marker no dibuja además el PNG (sería el edificio dos veces)")

	var body := with_scene._instance as StaticBody2D
	_expect(body != null, "la escena del edificio es un cuerpo sólido (StaticBody2D)")
	if body != null:
		_expect(body.collision_layer == 1,
			"el edificio vive en la capa 1, la misma que WorldBounds y CollisionMarker")
		var shapes: Array[CollisionShape2D] = []
		for child in body.get_children():
			if child is CollisionShape2D:
				shapes.append(child as CollisionShape2D)
		_expect(not shapes.is_empty(), "la escena trae al menos un CollisionShape2D")
		var solid := false
		var grounded := false
		for shape_node in shapes:
			var rect := shape_node.shape as RectangleShape2D
			if rect == null:
				continue
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				solid = true
			# El collider es la planta: tiene que estar abajo, a los pies del
			# edificio, no flotando a la altura del techo.
			if shape_node.position.y + rect.size.y * 0.5 > -64.0:
				grounded = true
		_expect(solid, "el collider tiene área real (no un rect de 0x0)")
		_expect(grounded, "el collider se apoya en el suelo, no queda flotando en el techo")

	_expect(with_scene._instance.owner == null,
		"la instancia no tiene owner: la zona guarda el marker, nunca el edificio entero")

	# Cambiar a un edificio sin escena vuelve al modo viejo, sin dejar la
	# instancia anterior colgada.
	with_scene.building_id = "mansion"
	await get_tree().process_frame
	_expect(not BuildingMarker.has_scene("mansion"), "'mansion' todavía no tiene escena")
	_expect(with_scene._instance == null and with_scene._tex != null,
		"un edificio sin escena cae al PNG plano y libera la instancia anterior")
	with_scene.free()

	# El catálogo no duplica un edificio que ya declara ENTRIES solo porque
	# ahora además tenga escena.
	var scanned := BuildCatalog.scanned_building_ids()
	_expect(not scanned.has("building_house_small_a"),
		"un edificio ya declarado no se duplica al armarle la escena")
	var building_ids := BuildCatalog.ids_in_category("building")
	var seen := {}
	var duplicated := false
	for id in building_ids:
		if seen.has(id):
			duplicated = true
		seen[id] = true
	_expect(not duplicated, "la categoría EDIFICIOS no repite ids")


## El buscador y el filtro por categoría del dock del editor. Son de la
## vista, no del catálogo, así que lo que importa es que jamás cambien QUÉ
## existe: solo qué botones se dibujan.
func _check_dock_filters() -> void:
	print("\n[12d] Dock del editor: buscador y filtro por categoría")
	var dock_script: GDScript = load("res://addons/build_mode_editor/build_dock.gd")
	var dock: PanelContainer = dock_script.new()
	add_child(dock)

	_expect(dock._fold("Árbol") == "arbol", "el buscador ignora tildes")
	_expect(dock._fold("HERRERÍA") == "herreria", "el buscador ignora mayúsculas y tildes")

	dock._search_text = ""
	_expect(dock._matches("tree"), "sin texto, todo entra")

	dock._search_text = "arbol"
	_expect(dock._matches("tree"), "busca por etiqueta ('Árbol' -> tree)")
	_expect(not dock._matches("rock"), "y deja afuera lo que no coincide")

	dock._search_text = "house_small"
	_expect(dock._matches("building_house_small_a"), "busca también por id, no solo por etiqueta")

	dock._search_text = ""
	dock._category_filter = "building"
	dock._populate_palette()
	var only_buildings := true
	for id in dock._kind_buttons.keys():
		if not BuildCatalog.ids_in_category("building").has(str(id)):
			only_buildings = false
	_expect(only_buildings and not dock._kind_buttons.is_empty(),
		"filtrando por EDIFICIOS solo quedan botones de edificios")

	dock._category_filter = ""
	dock._search_text = "no_existe_este_id_zzz"
	dock._populate_palette()
	_expect(dock._kind_buttons.is_empty(), "una búsqueda sin resultados no deja botones")

	dock._search_text = ""
	dock._populate_palette()
	_expect(dock._kind_buttons.size() == BuildCatalog.all_ids().size(),
		"limpiar el filtro devuelve el catálogo completo")

	dock.free()
