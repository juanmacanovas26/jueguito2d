extends Node
## Dev tool: renders the build-mode placement ghost (build_ghost.gd) right
## next to the SAME piece already placed, so the preview and the final
## result can be compared side by side in one shot. Does not assert.
##
## This exists because two separate "preview that lies" bugs shipped —
## the ghost forcing a fixed box size regardless of the real texture, and
## the ghost centering on the cursor when the placed tile is actually
## bottom-anchored on its cell. Neither was catchable headlessly (both are
## purely about where pixels land) and neither was obvious from the placed
## result alone, only from preview-vs-placed side by side.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/ghost_preview_screenshot.tscn

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const PRADERA_SCENE := "res://scenes/world/pradera.tscn"
const PRADERA_OVERRIDE := "res://scenes/world/pradera_markers.tscn"
const OUT_PATH := "user://ghost_preview_render.png"
const ORIGIN := Vector2(-640, -640)


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

	# A short wall run with a door already painted on it, as the reference
	# for what "placed" looks like.
	for x in range(5):
		zone._place_marker("wall_n", ORIGIN + Vector2(x * 32, 0))
	zone._place_marker("door", ORIGIN + Vector2(64, 0))
	await get_tree().physics_frame

	# Park the ghost on the cell immediately right of the placed run, with
	# "door" selected — same piece, same grid row, preview vs placed.
	Game.build_mode = true
	Game.build_selected_kind = "door"
	var ghost: Node2D = zone.get_node_or_null("BuildGhost")
	if ghost:
		# _process() would immediately snap this back to the real mouse
		# position (which is wherever the OS cursor happens to be in a
		# headless-ish run), so freeze it and place it by hand.
		ghost.set_process(false)
		ghost.global_position = BuildGrid.snap(ORIGIN + Vector2(5 * 32, 0))
		ghost.queue_redraw()

	player.global_position = ORIGIN + Vector2(80, 40)
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

	Game.build_mode = false
	zone.free()
	player.free()
	if override_parked:
		DirAccess.rename_absolute(PRADERA_OVERRIDE + ".parked", PRADERA_OVERRIDE)
	get_tree().quit(0)
