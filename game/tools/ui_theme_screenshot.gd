extends Node
## Dev tool: opens build mode on a real zone and screenshots the BuildPanel
## with its Theme (game/resources/ui/build_panel_theme.tres) applied — the
## only way to actually judge a UI theme is a real render, not the .tres
## values. Does not assert.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/ui_theme_screenshot.tscn

const PRADERA_SCENE := "res://scenes/world/pradera.tscn"
const PRADERA_OVERRIDE := "res://scenes/world/pradera_markers.tscn"
const OUT_PATH := "user://ui_theme_render.png"


func _ready() -> void:
	var override_parked := false
	if ResourceLoader.exists(PRADERA_OVERRIDE):
		DirAccess.rename_absolute(PRADERA_OVERRIDE, PRADERA_OVERRIDE + ".parked")
		override_parked = true

	var zone = load(PRADERA_SCENE).instantiate()
	add_child(zone)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var hud: Node = zone.get_node_or_null("HUD")
	Game.build_mode = true
	var build_panel: PanelContainer = hud.get_node_or_null("BuildPanel") if hud else null
	if build_panel:
		build_panel.visible = true
	# Toggle a couple of shape/roof buttons on so the "selected" (pressed)
	# button style shows in the render too, not just the default state.
	if hud and "_build_kind_buttons" in hud:
		var buttons: Dictionary = hud._build_kind_buttons
		var wall_button: Button = buttons.get("corner_out_ne")
		if wall_button:
			wall_button.button_pressed = true
	await get_tree().process_frame
	await get_tree().process_frame

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(OUT_PATH)
	if err != OK:
		push_error("could not save %s (%d)" % [OUT_PATH, err])
	else:
		print("wrote: " + ProjectSettings.globalize_path(OUT_PATH))

	zone.free()
	if override_parked:
		DirAccess.rename_absolute(PRADERA_OVERRIDE + ".parked", PRADERA_OVERRIDE)
	get_tree().quit(0)
