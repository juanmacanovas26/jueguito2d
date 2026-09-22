extends Node
## Dev tool: checks the two roof-extension cases that must NOT interfere
## with each other — a stand-alone hand-painted roof piece over open ground
## (must render as exactly ONE tile) and a real roofed room (must still get
## its north eave extension). Does not assert; look at the PNGs.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/roof_regression_screenshot.tscn

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const PRADERA_SCENE := "res://scenes/world/pradera.tscn"
const PRADERA_OVERRIDE := "res://scenes/world/pradera_markers.tscn"
const OUT_PATH := "user://roof_regression_render.png"


func _ready() -> void:
	var override_parked := false
	if ResourceLoader.exists(PRADERA_OVERRIDE):
		DirAccess.rename_absolute(PRADERA_OVERRIDE, PRADERA_OVERRIDE + ".parked")
		override_parked = true

	var player = load(PLAYER_SCENE).instantiate()
	add_child(player)
	await get_tree().physics_frame

	var zone = load(PRADERA_SCENE).instantiate()
	add_child(zone)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# A single stand-alone roof piece over open ground — no wall anywhere
	# near it. Must render as exactly one tile, not two.
	var original_material := Game.build_roof_material
	Game.build_roof_material = "red"
	zone._place_marker("roof_interior", Vector2(-15 * 32, -15 * 32))
	Game.build_roof_material = original_material

	var roof: TileMapLayer = zone.get_node_or_null("Roof")
	var lone_cell := Vector2i(-15, -15)
	var above_lone := Vector2i(-15, -16)
	print("lone roof cell source_id=%d, cell above it source_id=%d (-1 = empty, expected)" % [
		roof.get_cell_source_id(lone_cell), roof.get_cell_source_id(above_lone)])

	player.global_position = Vector2(-15 * 32, -15 * 32) + Vector2(150, 60)
	if "visual" in player and player.visual:
		player.visual.visible = false
	if "body_sprite" in player and player.body_sprite:
		player.body_sprite.visible = false
	if player.camera:
		player.camera.make_current()
		player.camera.zoom = Vector2(2.5, 2.5)
		player.camera.position_smoothing_enabled = false
	await get_tree().physics_frame
	await get_tree().physics_frame

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(OUT_PATH)
	if err != OK:
		push_error("could not save %s (%d)" % [OUT_PATH, err])
	else:
		print("wrote: " + ProjectSettings.globalize_path(OUT_PATH))

	zone.free()
	player.free()
	if override_parked:
		DirAccess.rename_absolute(PRADERA_OVERRIDE + ".parked", PRADERA_OVERRIDE)
	get_tree().quit(0)
