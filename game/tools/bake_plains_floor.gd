extends Node
## Fills a zone's "Floor" layer with a single flat tile and bakes it into the
## scene file, replacing the procedural grass/dirt pass.
##
##   Godot_v4.7.1-stable_win64_console.exe --headless --path game \
##       res://tools/bake_plains_floor.tscn
##
## A scene tool, not a `-s` SceneTree script: a SceneTree script's _init()
## runs before the main loop exists, and this one hung there indefinitely
## instead of baking. Every other baker in tools/ uses the scene form too.
##
## Why bake instead of generating at load: world_zone.gd's _build_floor()
## skips its procedural pass entirely when the Floor layer already has cells
## (the "don't clobber what's already there" rule it shares with
## _repaint_owned()). So writing the cells into the scene IS how you turn the
## procedural floor off — no flag, no code path to disable.
##
## Deliberately targets "Floor", not the painted "Suelo" layer above it: the
## base has to sit UNDER whatever gets painted by hand, so that erasing a
## painted feature reveals grass again instead of a hole.

const ZONE_PATH := "res://scenes/world/praderas_del_alba.tscn"
const TILE_PNG := "res://assets/world/decor/plains/tiles/pasto_01.png"
const TILE_PX := 32


func _ready() -> void:
	var scene: PackedScene = load(ZONE_PATH)
	if scene == null:
		push_error("could not load " + ZONE_PATH)
		get_tree().quit(1)
		return
	var zone: Node2D = scene.instantiate()

	var floor_layer: TileMapLayer = zone.get_node_or_null("Floor")
	if floor_layer == null:
		push_error("zone has no Floor layer")
		get_tree().quit(1)
		return

	var tex: Texture2D = load(TILE_PNG)
	if tex == null:
		push_error("could not load " + TILE_PNG)
		get_tree().quit(1)
		return

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_PX, TILE_PX)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_PX, TILE_PX)
	src.create_tile(Vector2i.ZERO)
	var source_id := ts.get_next_source_id()
	ts.add_source(src, source_id)
	floor_layer.tile_set = ts

	# Same grid maths as _build_floor()'s procedural pass, so the baked floor
	# lines up with world_size exactly the way a generated one would (ceil()
	# can overshoot by a few px per axis; that sliver hides under the walls).
	var world_size: Vector2 = zone.world_size
	var tiles_x := int(ceil(world_size.x / float(TILE_PX)))
	var tiles_y := int(ceil(world_size.y / float(TILE_PX)))
	floor_layer.position = Vector2(-tiles_x * TILE_PX * 0.5, -tiles_y * TILE_PX * 0.5)

	floor_layer.clear()
	for y in tiles_y:
		for x in tiles_x:
			floor_layer.set_cell(Vector2i(x, y), source_id, Vector2i.ZERO)

	# pack() only keeps descendants owned by the node being packed.
	_reown_direct_children(zone)

	var packed := PackedScene.new()
	if packed.pack(zone) != OK:
		push_error("pack() failed")
		get_tree().quit(1)
		return
	if ResourceSaver.save(packed, ZONE_PATH) != OK:
		push_error("save failed")
		get_tree().quit(1)
		return

	print("BAKED %d x %d = %d cells into %s" % [tiles_x, tiles_y, tiles_x * tiles_y, ZONE_PATH])
	print("BAKED floor offset = %s" % floor_layer.position)
	get_tree().quit(0)


## Re-owns ONLY the zone's own direct children, and never descends into them.
##
## The obvious version — walk the whole subtree setting owner — silently
## destroys the Player and HUD: giving an instanced scene's internal nodes an
## owner makes pack() write them out as plain nodes instead of a single
## `instance=` line, so the zone ends up holding frozen COPIES that stop
## tracking player.tscn/hud.tscn. (Measured: it inflated this scene from
## 770 KB of legitimate tile data to 770 KB *plus* an expanded player rig.)
## An instance root only needs its own owner set; its insides keep theirs.
func _reown_direct_children(zone: Node) -> void:
	for child in zone.get_children():
		child.owner = zone
