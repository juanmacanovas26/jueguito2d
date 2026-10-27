extends Node2D
## Renders the TERRENO brush (BiomeTileset) over the zone's grass Floor, so the
## borders can be judged by eye: a lake with its beach, a river leaving it, a
## stone outcrop and a mud patch, plus one water cell dropped straight onto
## grass to show the hard edge you get without a sand ring.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/terrain_screenshot.tscn -- C:/ruta/salida.png
##
## Without an argument it writes user://terrain_render.png.

const CELLS := Vector2i(30, 24)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := str(args[0]) if args.size() > 0 else "user://terrain_render.png"
	# 1:1 pixels: the project stretches the canvas, which would blur the edges.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = CELLS * BiomeTileset.TILE_SIZE

	var floor_ts := FloorTileset.build()
	var floor_layer := TileMapLayer.new()
	floor_layer.tile_set = floor_ts
	add_child(floor_layer)
	for y in CELLS.y:
		for x in CELLS.x:
			floor_layer.set_cell(Vector2i(x, y), FloorTileset.wang_source_id(), Vector2i(3, 3))

	var built := BiomeTileset.build()
	var layer := TileMapLayer.new()
	layer.tile_set = built["tileset"]
	add_child(layer)
	var resolved := BiomeTileset.resolve(_design())
	for cell in resolved:
		var source_id := int(built["source_ids"].get(resolved[cell][0], -1))
		if source_id >= 0:
			layer.set_cell(cell, source_id, BiomeTileset.atlas_coords(int(resolved[cell][1])))

	for i in 3:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img.save_png(out_path) != OK:
		push_error("could not write " + out_path)
		get_tree().quit(1)
		return
	print("wrote ", ProjectSettings.globalize_path(out_path))
	get_tree().quit(0)


func _design() -> Dictionary:
	var painted := {}
	# Sand first, water over it: whatever is painted later wins the cell.
	_blob(painted, Vector2(8, 8), Vector2(6.6, 5.4), "arena")
	for x in range(12, 30):
		var y := 8.5 + sin(x * 0.45) * 2.0
		_blob(painted, Vector2(x, y), Vector2(2.2, 2.2), "arena")
	_blob(painted, Vector2(8, 8), Vector2(5.0, 3.9), "agua")
	for x in range(12, 30):
		var y := 8.5 + sin(x * 0.45) * 2.0
		_blob(painted, Vector2(x, y), Vector2(1.0, 1.0), "agua")
	# Kept clear of the sand: arena-piedra and arena-barro have no sheet, so
	# touching would draw a hard edge (that case is the lone water cell below).
	_blob(painted, Vector2(24, 19.5), Vector2(3.6, 2.6), "piedra")
	_blob(painted, Vector2(5, 19.5), Vector2(3.0, 2.4), "barro")
	_blob(painted, Vector2(14.5, 19.5), Vector2(2.4, 1.8), "barro")
	painted[Vector2i(19, 17)] = "agua"
	return painted


func _blob(painted: Dictionary, centre: Vector2, radii: Vector2, terrain: String) -> void:
	for y in range(int(centre.y - radii.y) - 1, int(centre.y + radii.y) + 2):
		for x in range(int(centre.x - radii.x) - 1, int(centre.x + radii.x) + 2):
			var d := Vector2((x + 0.5 - centre.x) / radii.x, (y + 0.5 - centre.y) / radii.y)
			if d.length() <= 1.0 and x >= 0 and y >= 0 and x < CELLS.x and y < CELLS.y:
				painted[Vector2i(x, y)] = terrain
