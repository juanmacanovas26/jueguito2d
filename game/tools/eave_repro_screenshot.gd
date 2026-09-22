extends Node
## Scratch dev tool: reproduce the user's report — placing a single
## roof_eave_e/roof_eave_w piece over a standalone wall_e/wall_w cell paints
## TWO roof cells from one click, and the result looks "frontal" rather than
## like a proper side eave. Does not assert; look at the PNG + printed cell
## counts.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/eave_repro_screenshot.tscn

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const PRADERA_SCENE := "res://scenes/world/pradera.tscn"
const PRADERA_OVERRIDE := "res://scenes/world/pradera_markers.tscn"
const OUT_PATH := "user://eave_repro_render.png"
const ORIGIN := Vector2i(-20, -20)


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

	# A wall_e run with NOTHING north of its top cell (open sky above) —
	# the case that actually triggers the eave-extension: the earlier repro
	# with a wall_n row directly above did NOT duplicate (the extension skips
	# a cell that already has its own wall marker).
	zone._place_marker("wall_e", BuildGrid.cell_to_world(ORIGIN + Vector2i(2, 1)))
	zone._place_marker("wall_e", BuildGrid.cell_to_world(ORIGIN + Vector2i(2, 2)))

	var roof: TileMapLayer = zone.get_node_or_null("Roof")
	print("cells painted BEFORE placing any roof piece: %d" % roof.get_used_cells().size())

	# ONE click on roof_eave_e, directly over the wall_e cell at (2,1) — the
	# TOP cell of the run, with open sky above it.
	Game.build_roof_material = "slate"
	zone._place_marker("roof_eave_e", BuildGrid.cell_to_world(ORIGIN + Vector2i(2, 1)))

	print("cells painted AFTER one roof_eave_e click: %d" % roof.get_used_cells().size())
	for c in roof.get_used_cells():
		print("  roof cell %s source_id=%d" % [c, roof.get_cell_source_id(c)])

	# Second repro: a corner (hip_ne) placed STANDALONE, no wall/floor at all
	# under it — reported as "las esquinas se ponen dobles con 1 clic".
	var before2 := roof.get_used_cells().size()
	zone._place_marker("roof_hip_ne", BuildGrid.cell_to_world(ORIGIN + Vector2i(8, 8)))
	var after2 := roof.get_used_cells().size()
	print("standalone roof_hip_ne (no wall under it): %d cell(s) added by one click (expected 1)" % (after2 - before2))

	# Third repro: an ISOLATED wall_s + roof_eave_s, nothing else around, to
	# check the PIECE_OFFSETS anchor nudge in complete isolation (no busy
	# room texture to obscure whether it actually shifted).
	var original_roof_material := Game.build_roof_material
	zone._place_marker("wall_s", BuildGrid.cell_to_world(ORIGIN + Vector2i(12, 8)))
	Game.build_roof_material = "slate"
	zone._place_marker("roof_eave_s", BuildGrid.cell_to_world(ORIGIN + Vector2i(12, 8)))
	Game.build_roof_material = original_roof_material

	var room_center := BuildGrid.cell_to_world(ORIGIN + Vector2i(12, 8))
	player.global_position = room_center + Vector2(40, 40)
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
