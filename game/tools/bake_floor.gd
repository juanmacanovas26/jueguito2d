extends Node
## One-time bake: paints the procedural grass/dirt Floor layer directly into
## pradera.tscn and overwrites it, so opening the scene in the Godot editor
## shows the real map instead of a blank Floor node — world_zone.gd's
## _build_floor() only ever painted it at runtime in _ready(), so there was
## nothing to look at in the editor, and it recomputed from scratch on every
## single Play.
##
## Re-run this after changing world_size, dirt_coverage, or
## dirt_patch_scale — world_zone.gd's _build_floor() now skips regenerating
## the Floor layer whenever it already has cells (see its own comment), so a
## stale bake stays stale until this runs again.
##
##   Godot_v4.7.1-stable_win64_console.exe --headless --path game \
##       res://tools/bake_floor.tscn

const SCENE_PATH := "res://scenes/world/pradera.tscn"


func _ready() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	# Instantiate WITHOUT adding to the tree: _ready() (player spawn, Game
	# registration, HUD, mob/resource spawning...) never runs, so nothing
	# outside the Floor node is touched. _build_floor() only needs $Floor to
	# exist as a child, which instantiate() alone already gives it.
	var zone = packed.instantiate()
	if not zone.has_method("_build_floor"):
		push_error("scene's root script has no _build_floor() — wrong scene?")
		get_tree().quit(1)
		return

	var floor_layer: TileMapLayer = zone.get_node("Floor")
	var before := floor_layer.get_used_cells().size()
	# Force a fresh bake even if one already exists — that's the point of
	# re-running this tool after a world_size/coverage change.
	floor_layer.clear()
	zone.call("_build_floor")
	var after := floor_layer.get_used_cells().size()

	var new_packed := PackedScene.new()
	var err := new_packed.pack(zone)
	if err != OK:
		push_error("pack() failed: %d" % err)
		get_tree().quit(1)
		return
	err = ResourceSaver.save(new_packed, SCENE_PATH)
	if err != OK:
		push_error("could not write %s (%d)" % [SCENE_PATH, err])
		get_tree().quit(1)
		return

	print("baked Floor: %d -> %d cells, wrote %s" % [before, after, SCENE_PATH])
	get_tree().quit(0)
