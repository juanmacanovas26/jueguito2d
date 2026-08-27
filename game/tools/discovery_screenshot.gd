extends Node
## Dev tool: drives a real Player + HUD through crossing a discovery
## threshold to see the "1 de 3" panel actually appear and work — screenshots
## before and after picking a choice. Does not assert.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/discovery_screenshot.tscn

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const HUD_SCENE := "res://scenes/ui/hud.tscn"
const OUT_PATH_OFFER := "user://discovery_offer.png"
const OUT_PATH_AFTER := "user://discovery_after.png"


func _ready() -> void:
	var player = load(PLAYER_SCENE).instantiate()
	add_child(player)
	var hud = load(HUD_SCENE).instantiate()
	add_child(hud)
	await get_tree().physics_frame
	await get_tree().physics_frame

	player.progression.gain("heavy_swords", 30.0)  # crosses the first threshold (25)
	await get_tree().process_frame
	await get_tree().process_frame

	print("-- after crossing the first discovery threshold --")
	print("discovery panel visible: %s" % hud.discovery_panel.visible)
	var choice_labels: Array = []
	for child in hud.discovery_choices.get_children():
		choice_labels.append(child.text)
	print("choices offered: %s" % str(choice_labels))
	await _shot(OUT_PATH_OFFER)

	if hud.discovery_choices.get_child_count() > 0:
		var first_button: Button = hud.discovery_choices.get_child(0)
		first_button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame

	print("\n-- after picking the first choice --")
	print("discovery panel visible: %s" % hud.discovery_panel.visible)
	print("known_abilities: " + str(player.known_abilities))
	print("toast text: '%s'" % hud.toast_label.text)
	await _shot(OUT_PATH_AFTER)

	get_tree().quit(0)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	if err != OK:
		push_error("could not save %s (%d)" % [path, err])
		return
	print("wrote: " + ProjectSettings.globalize_path(path))
