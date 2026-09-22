extends Node
## Dev tool: places every FREESTANDING decor_* palette id via the real
## build-mode _place_marker() path and screenshots them — confirms each prop
## actually renders through the same pipeline a player's click would use.
## Does not assert (see [12] in validate_build_mode.gd for that).
##
## Windows/torch used to be here too, but moved to StructureTileset.
## WALL_DECOR — painted onto an existing wall cell instead of free-placed
## (see pack_expansion_screenshot.gd for a render of those, alongside a
## door, on a real wall).
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/decor_screenshot.tscn

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const PRADERA_SCENE := "res://scenes/world/pradera.tscn"
const PRADERA_OVERRIDE := "res://scenes/world/pradera_markers.tscn"
const OUT_PATH := "user://decor_render.png"
const ORIGIN := Vector2(-640, -640) # far from pradera's own placed content

const IDS := [
	"decor_barrel", "decor_crate", "decor_crate_stack", "decor_banner",
	"decor_cart", "decor_cart_wheel", "decor_bush", "decor_spigot",
	"decor_fence", "decor_garden_bed", "decor_plank", "decor_dormer_red",
	"decor_dormer_blue", "decor_stone_platform",
]


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

	# Spread on a grid, 5 per row, spacing well past MIN_MARKER_SPACING.
	for i in IDS.size():
		var col := i % 5
		var row := i / 5
		var pos := ORIGIN + Vector2(col * 80, row * 100)
		zone._place_marker(IDS[i], pos)
	await get_tree().physics_frame

	player.global_position = ORIGIN + Vector2(160, 50)
	if "visual" in player and player.visual:
		player.visual.visible = false
	if "body_sprite" in player and player.body_sprite:
		player.body_sprite.visible = false
	if player.camera:
		player.camera.make_current()
		player.camera.zoom = Vector2(0.9, 0.9)
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
