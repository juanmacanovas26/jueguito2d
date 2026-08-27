extends Node
## Headless coverage for Fase 2's mapping tool: ZoneBuilder turning marker
## nodes (MobSpawnMarker/ResourceNodeMarker/POIMarker) into live entities,
## plus a regression check that migrating pradera.tscn off the old hardcoded
## Vector2/Dictionary arrays didn't silently drop any content.
##
##   Godot_v4.7.1-stable_win64_console.exe --headless --path game \
##       res://tools/validate_zone_builder.tscn
##
## Exits 0 when everything passes, 1 otherwise.

const PRADERA_SCENE := "res://scenes/world/pradera.tscn"
const PRADERA_OVERRIDE := "res://scenes/world/pradera_markers.tscn"
const MIN_CHECKS := 10

var _failures: Array = []
var _checks := 0


func _ready() -> void:
	await _run()


func _run() -> void:
	print("== validate_zone_builder ==")
	await _check_synthetic_markers()
	await _check_pradera_migration()

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


func _check_synthetic_markers() -> void:
	print("\n[1] ZoneBuilder.build() on a synthetic marker set")
	var markers := Node2D.new()
	add_child(markers)

	var mob_marker := MobSpawnMarker.new()
	mob_marker.position = Vector2(40, -20)
	mob_marker.max_hp = 123.0
	mob_marker.ranged = true
	mob_marker.attack_range = 77.0
	markers.add_child(mob_marker)

	var tree_marker := ResourceNodeMarker.new()
	tree_marker.position = Vector2(-30, 10)
	markers.add_child(tree_marker)

	var vein_marker := ResourceNodeMarker.new()
	vein_marker.kind = ResourceNodeMarker.Kind.VEIN
	vein_marker.position = Vector2(5, 5)
	markers.add_child(vein_marker)

	var poi_marker := POIMarker.new()
	poi_marker.kind = POIMarker.Kind.VENDOR
	markers.add_child(poi_marker)

	var zone_root := Node2D.new()
	add_child(zone_root)

	var pois := ZoneBuilder.build(markers, zone_root)
	await get_tree().physics_frame

	_expect(pois.size() == 1 and pois[0] == poi_marker, "the POI marker is returned, untouched")
	# A POI has no spawned entity of its own to show it exists (unlike a mob
	# or a gatherable) — it has to draw itself at runtime, not just in the
	# editor, or a placed POI would be invisible in Play mode.
	_expect(poi_marker.is_processing(),
		"POIMarker keeps processing (and so redrawing) outside the editor too")

	var mobs_container := zone_root.get_node_or_null("Mobs")
	_expect(mobs_container != null and mobs_container.get_child_count() == 1,
		"exactly one mob was spawned")
	if mobs_container and mobs_container.get_child_count() == 1:
		var mob = mobs_container.get_child(0)
		_expect(is_equal_approx(mob.max_hp, 123.0), "mob stats carried over (max_hp)")
		_expect(mob.ranged and is_equal_approx(mob.attack_range, 77.0),
			"ranged-only fields carried over")
		_expect(mob.global_position.distance_to(Vector2(40, -20)) < 0.5,
			"the mob spawned at the marker's position")
		# The property above just proves the export var was set; _ready()
		# BAKES max_hp/body_color into health/_base_color, and only reads
		# them once — this is what actually regressed (see zone_builder.gd's
		# note on property order vs add_child()).
		_expect(is_equal_approx(mob.health.max_hp, 123.0),
			"  and health.max_hp actually baked the marker's value, not the class default")
		_expect(mob._base_color.is_equal_approx(mob_marker.body_color),
			"  same for the ranged tint (_base_color)")

	var obstacles_container := zone_root.get_node_or_null("Obstacles")
	_expect(obstacles_container != null and obstacles_container.get_child_count() == 2,
		"both the tree and the vein were spawned")
	if obstacles_container and obstacles_container.get_child_count() == 2:
		for c in obstacles_container.get_children():
			var expected_art := "res://assets/world/%s.png" % str(c.visual_type)
			# resource_node.gd doesn't name the art layer, so just check SOME
			# child under Visual renders the texture matching this node's OWN
			# visual_type — not a stale one baked in before visual_type was
			# actually set (the real bug: it used to always be "tree").
			var visual_root: Node = c.get_node("Visual")
			var found_right_art := false
			for v in visual_root.get_children():
				if v is Sprite2D and v.texture and v.texture.resource_path == expected_art:
					found_right_art = true
			_expect(found_right_art,
				"'%s' node's own visual matches its visual_type ('%s'), not a baked-in default"
					% [c.display_name, c.visual_type])
	if obstacles_container:
		var kinds: Array = []
		for c in obstacles_container.get_children():
			kinds.append(str(c.visual_type))
		_expect(kinds.has("tree"), "the default-kind marker became a tree")
		_expect(kinds.has("vein"), "the VEIN-kind marker became a vein")

	markers.free()
	zone_root.free()


func _check_pradera_migration() -> void:
	print("\n[2] pradera.tscn still spawns everything it did before the marker migration")
	# This checks the content baked into pradera.tscn itself, not whatever a
	# dev has since placed with build mode — a saved *_markers.tscn override
	# (see world_zone.gd's _load_markers_override()) would otherwise make
	# this test's counts drift every time someone actually uses the tool. Set
	# it aside for the duration of this check if one exists.
	var override_parked := false
	if ResourceLoader.exists(PRADERA_OVERRIDE):
		DirAccess.rename_absolute(PRADERA_OVERRIDE, PRADERA_OVERRIDE + ".parked")
		override_parked = true

	var zone = load(PRADERA_SCENE).instantiate()
	add_child(zone)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var mobs: Node = zone.get_node_or_null("Mobs")
	_expect(mobs != null and mobs.get_child_count() == 8,
		"8 mobs spawned (got %d)" % (mobs.get_child_count() if mobs else -1))

	var obstacles: Node = zone.get_node_or_null("Obstacles")
	_expect(obstacles != null and obstacles.get_child_count() == 28,
		"28 gatherables spawned: 12 trees + 12 rocks + 4 veins (got %d)"
			% (obstacles.get_child_count() if obstacles else -1))

	if obstacles:
		var veins := 0
		for c in obstacles.get_children():
			if str(c.visual_type) == "vein" and bool(c.immortal):
				veins += 1
		_expect(veins == 4, "all 4 veins are immortal (got %d)" % veins)

	zone.free()
	if override_parked:
		DirAccess.rename_absolute(PRADERA_OVERRIDE + ".parked", PRADERA_OVERRIDE)
