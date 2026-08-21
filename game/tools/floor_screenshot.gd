extends Node2D
## Renders a patch of the real world floor so the grass/dirt autotiling can be
## eyeballed. Dev tool.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/floor_screenshot.tscn

const WORLD_SCENE := "res://scenes/world/pradera.tscn"
const OUT_PATH := "user://floor_render.png"


func _ready() -> void:
	var world = load(WORLD_SCENE).instantiate()
	add_child(world)
	await get_tree().physics_frame

	# Frame the floor from above, ignoring the player's own camera.
	for cam in _find_cameras(world):
		cam.enabled = false
	var cam2 := Camera2D.new()
	# 1:1, the same as the in-game camera. A non-integer zoom introduces its own
	# sampling artifacts and would make real texture bleed impossible to judge.
	cam2.zoom = Vector2.ONE
	cam2.enabled = true
	add_child(cam2)
	cam2.make_current()

	# Hide everything that is not the floor so the tiling is unobstructed.
	var floor_layer: Node = world.find_child("Floor", true, false)
	for child in world.get_children():
		if child != floor_layer:
			if child is CanvasItem:
				child.visible = false

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(OUT_PATH)
	if err != OK:
		push_error("could not save %s (%d)" % [OUT_PATH, err])
		get_tree().quit(1)
		return
	print("wrote: " + ProjectSettings.globalize_path(OUT_PATH))
	if floor_layer is TileMapLayer:
		var used: Array = floor_layer.get_used_cells()
		print("floor cells painted: %d" % used.size())
		var per_source := {}
		for cell in used:
			var sid: int = floor_layer.get_cell_source_id(cell)
			var coords: Vector2i = floor_layer.get_cell_atlas_coords(cell)
			var key := "source %d  tile %s" % [sid, coords]
			per_source[key] = int(per_source.get(key, 0)) + 1
		var keys: Array = per_source.keys()
		keys.sort()
		print("distinct tiles used: %d" % keys.size())
		for k in keys:
			print("  %-24s x%d" % [k, per_source[k]])
	get_tree().quit(0)


func _find_cameras(node: Node) -> Array:
	var out: Array = []
	if node is Camera2D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_cameras(c))
	return out
