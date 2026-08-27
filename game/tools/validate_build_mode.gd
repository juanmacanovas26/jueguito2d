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
const MIN_CHECKS := 30

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
	_check_placement_validity()


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
	for kind in ["mob", "tree", "rock", "vein",
			"vendor", "bank", "repair", "dungeon_entrance", "mini_boss"]:
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
	_expect(expected_ids.size() == 9, "BuildCatalog lists 9 placeable ids (got %d)" % expected_ids.size())

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
## round mob/resource art, but it's the piece a future structure category
## needs, and it should already work end to end.
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
