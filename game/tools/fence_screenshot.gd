extends Node2D
## Renderiza vallado de verdad —por la TileMapLayer y el TileSet horneado, no
## por una composición aparte— para mirar lo único que ningún test puede
## decir: si las piezas cierran o se ve la costura.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/fence_screenshot.tscn
##
## Dibuja un corral cerrado, una L y una tirada suelta: entre las tres pasan
## las 8 combinaciones del atlas.

const OUT_PATH := "user://fence_render.png"
const VIEW := Vector2(900, 520)
const WORLD_ZONE_SCRIPT := preload("res://scripts/world/world_zone.gd")


func _ready() -> void:
	get_viewport().get_window().size = Vector2i(VIEW)
	RenderingServer.set_default_clear_color(Color(0.29, 0.43, 0.24))

	var zone := Node2D.new()
	zone.set_script(WORLD_ZONE_SCRIPT)
	add_child(zone)
	zone.call("_build_fences")

	var style: String = FenceAutotiler.styles()[0]
	var kind := FenceAutotiler.palette_id(style)
	var cells: Array[Vector2i] = []
	# Corral cerrado 7x5.
	for x in range(1, 8):
		cells.append(Vector2i(x, 1))
		cells.append(Vector2i(x, 5))
	for y in range(2, 5):
		cells.append(Vector2i(1, y))
		cells.append(Vector2i(7, y))
	# Una L y una tirada suelta al costado.
	for x in range(10, 15):
		cells.append(Vector2i(x, 4))
	for y in range(1, 4):
		cells.append(Vector2i(10, y))
	for x in range(12, 16):
		cells.append(Vector2i(x, 1))

	for cell in cells:
		zone.call("_place_marker", kind, BuildGrid.cell_to_world(cell))
	zone.call("_rebuild_fences")

	var cam := Camera2D.new()
	cam.position = Vector2(8 * 32, 3 * 32)
	cam.zoom = Vector2(1.7, 1.7)
	add_child(cam)
	cam.make_current()

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	if img.save_png(OUT_PATH) != OK:
		push_error("no se pudo guardar " + OUT_PATH)
	print("wrote: " + ProjectSettings.globalize_path(OUT_PATH))
	get_tree().quit()
