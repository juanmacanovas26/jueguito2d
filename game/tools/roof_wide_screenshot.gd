extends Node
## Dev tool: same room-building approach as structure_screenshot.gd, but
## zoomed out enough to see the WHOLE roof from directly above in one shot —
## structure_screenshot.gd's close-in camera mostly shows the front wall, not
## useful for judging whether the eave pieces tile cleanly across a wide
## edge (see docs/GDD.md's eave scallop fix).
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/roof_wide_screenshot.tscn

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const PRADERA_SCENE := "res://scenes/world/pradera.tscn"
const PRADERA_OVERRIDE := "res://scenes/world/pradera_markers.tscn"
const OUT_PATH := "user://roof_wide_render.png"
const ROOM_ORIGIN := Vector2i(-20, -20)


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

	const WIDTH := 6
	const HEIGHT := 5
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell := ROOM_ORIGIN + Vector2i(x, y)
			var at_n := y == 0
			var at_s := y == HEIGHT - 1
			var at_w := x == 0
			var at_e := x == WIDTH - 1
			var piece := "floor"
			if at_n and at_w: piece = "corner_out_nw"
			elif at_n and at_e: piece = "corner_out_ne"
			elif at_s and at_w: piece = "corner_out_sw"
			elif at_s and at_e: piece = "corner_out_se"
			elif at_n: piece = "wall_n"
			elif at_s: piece = "wall_s"
			elif at_w: piece = "wall_w"
			elif at_e: piece = "wall_e"
			zone._place_marker(piece, BuildGrid.cell_to_world(cell))
	zone._place_marker("door", BuildGrid.cell_to_world(ROOM_ORIGIN + Vector2i(2, 4)))
	var original_roof_material := Game.build_roof_material
	Game.build_roof_material = "slate"
	zone.generate_roof_over_walls()
	Game.build_roof_material = original_roof_material
	await get_tree().physics_frame

	var room_center := BuildGrid.cell_to_world(ROOM_ORIGIN + Vector2i(3, 2))
	# NOTE: with this room size/zoom, the south edge sits behind the HUD
	# hotbar at the bottom of frame — this framing was never fully solved
	# (camera position offsets had much less effect than expected, possibly
	# a Camera2D limit somewhere; not chased down). Good enough for judging
	# the north/east/west edges and corners; for the south edge specifically,
	# compare the raw PNGs directly (e.g. paste hip_sw+eave_s+eave_s+hip_se
	# side by side) rather than relying on this tool's screenshot.
	player.global_position = room_center + Vector2(0, -120)
	if "visual" in player and player.visual:
		player.visual.visible = false
	if "body_sprite" in player and player.body_sprite:
		player.body_sprite.visible = false
	if player.camera:
		player.camera.make_current()
		player.camera.zoom = Vector2(0.5, 0.5)
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
