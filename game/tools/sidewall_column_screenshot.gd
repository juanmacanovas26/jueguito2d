extends Node
## Dev tool: renders a long vertical run of "wall_e" cells with a corner at
## the bottom — the exact case a user screenshot flagged as broken (each
## cell reading as a disconnected floating block instead of one continuous
## wall). Does not assert.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/sidewall_column_screenshot.tscn

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const PRADERA_SCENE := "res://scenes/world/pradera.tscn"
const PRADERA_OVERRIDE := "res://scenes/world/pradera_markers.tscn"
const OUT_PATH := "user://sidewall_column_render.png"
const ORIGIN := Vector2i(-15, -25)


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

	zone._place_marker("corner_out_ne", BuildGrid.cell_to_world(ORIGIN + Vector2i(0, 0)))
	for y in range(1, 6):
		zone._place_marker("wall_e", BuildGrid.cell_to_world(ORIGIN + Vector2i(0, y)))
	zone._place_marker("corner_out_se", BuildGrid.cell_to_world(ORIGIN + Vector2i(0, 6)))
	await get_tree().physics_frame
	# doc note: corners bookend the run on purpose — this is what a reported
	# screenshot showed breaking (a visible jog/gap at the corner-to-wall
	# seam), not just a lone run.

	player.global_position = BuildGrid.cell_to_world(ORIGIN + Vector2i(0, 3)) + Vector2(80, 0)
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
