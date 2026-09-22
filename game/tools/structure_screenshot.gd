extends Node
## Dev tool: builds a real room with the PixelLab structure kit inside
## pradera.tscn and screenshots it from the player's own camera — the visual
## counterpart to validate_build_mode.gd's [10] section (which only checks
## source_ids, not what they actually look like). Does not assert.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/structure_screenshot.tscn

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const PRADERA_SCENE := "res://scenes/world/pradera.tscn"
const PRADERA_OVERRIDE := "res://scenes/world/pradera_markers.tscn"
const OUT_PATH := "user://structure_render.png"
const OUT_PATH_NO_ROOF := "user://structure_render_walls.png"
const ROOM_ORIGIN := Vector2i(-20, -20) # far from pradera's own placed content, inside world_size bounds


func _ready() -> void:
	var override_parked := false
	if ResourceLoader.exists(PRADERA_OVERRIDE):
		DirAccess.rename_absolute(PRADERA_OVERRIDE, PRADERA_OVERRIDE + ".parked")
		override_parked = true

	# The zone itself never instantiates a player (see world_zone.gd's
	# _spawn_player() — it just looks up Game.get_local_player()); that's
	# normally done by whatever scene hosts both. Do it here too.
	var player = load(PLAYER_SCENE).instantiate()
	add_child(player)
	await get_tree().physics_frame

	var zone = load(PRADERA_SCENE).instantiate()
	add_child(zone)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# A 5x4 room (long enough to show a real ridge, not just hips) with one
	# door on the south wall. Every cell's piece is picked explicitly now —
	# no neighbour inference — so this mirrors what a player clicking each
	# shape button by hand would place.
	const WIDTH := 5
	const HEIGHT := 4
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
	zone._place_marker("door", BuildGrid.cell_to_world(ROOM_ORIGIN + Vector2i(2, 3)))
	zone._place_marker("window_medium", BuildGrid.cell_to_world(ROOM_ORIGIN + Vector2i(1, 3)))
	zone._place_marker("torch", BuildGrid.cell_to_world(ROOM_ORIGIN + Vector2i(3, 3)))
	# The "with roof" shot needs an actual roof — generate_roof_over_walls()
	# was already the only thing that ever adds one (see world_zone.gd), this
	# tool just never called it.
	var original_roof_material := Game.build_roof_material
	Game.build_roof_material = "slate"
	zone.generate_roof_over_walls()
	Game.build_roof_material = original_roof_material
	await get_tree().physics_frame

	var markers: Node = zone.get_node_or_null("Markers")
	var structure_markers: Array = ZoneBuilder.collect_structures(markers) if markers else []
	print("-- %d StructureMarkers placed --" % structure_markers.size())
	var structures_layer: TileMapLayer = zone.get_node_or_null("Structures")
	for m in structure_markers:
		var sid := structures_layer.get_cell_source_id(m.grid_pos)
		print("  cell %s  wall_decor=%s  source_id=%d  local_pos=%s" % [m.grid_pos, m.wall_decor, sid, m.position])

	var room_center := BuildGrid.cell_to_world(ROOM_ORIGIN + Vector2i(2, 2))
	# NOT a big south push — that moves the CAMERA's visible window south too,
	# away from the tall roof to the north (had this backwards for a while).
	# A small east/south nudge just keeps the building off the HUD's top-left
	# corner overlay.
	player.global_position = room_center + Vector2(60, 20)
	# The root's own visible=false doesn't actually hide the character (its
	# CharacterVisual draws regardless — a real oddity, but not worth
	# chasing for a dev tool); hiding the visual pieces directly does.
	if "visual" in player and player.visual:
		player.visual.visible = false
	if "body_sprite" in player and player.body_sprite:
		player.body_sprite.visible = false
	if player.camera:
		player.camera.make_current()
		player.camera.zoom = Vector2(2.0, 2.0)
		# Default smoothing lags several frames behind a position jump this
		# big; without disabling it the shot below still shows the OLD view.
		player.camera.position_smoothing_enabled = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	if player.camera:
		print("camera global_position=%s zoom=%s current=%s" % [
			player.camera.global_position, player.camera.zoom, player.camera.is_current()])

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(OUT_PATH)
	if err != OK:
		push_error("could not save %s (%d)" % [OUT_PATH, err])
	else:
		print("wrote: " + ProjectSettings.globalize_path(OUT_PATH))

	# A second shot with the roof hidden — the hip roof legitimately covers
	# most of the building from directly above (that's correct for a real
	# roof), so this is the only way to actually see the wall/corner/door
	# pieces themselves in one screenshot.
	var roof_layer: TileMapLayer = zone.get_node_or_null("Roof")
	if roof_layer:
		roof_layer.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img2 := get_viewport().get_texture().get_image()
	var err2 := img2.save_png(OUT_PATH_NO_ROOF)
	if err2 != OK:
		push_error("could not save %s (%d)" % [OUT_PATH_NO_ROOF, err2])
	else:
		print("wrote: " + ProjectSettings.globalize_path(OUT_PATH_NO_ROOF))

	zone.free()
	player.free()
	if override_parked:
		DirAccess.rename_absolute(PRADERA_OVERRIDE + ".parked", PRADERA_OVERRIDE)
	get_tree().quit(0)
