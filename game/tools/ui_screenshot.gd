extends Node
## Opens the inventory panel on a real HUD with a real Player and screenshots
## it, so the equipment slots and item icons can actually be looked at. Dev tool.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/ui_screenshot.tscn

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const HUD_SCENE := "res://scenes/ui/hud.tscn"
const OUT_PATH := "user://ui_render.png"


func _ready() -> void:
	var player = load(PLAYER_SCENE).instantiate()
	add_child(player)
	var hud = load(HUD_SCENE).instantiate()
	add_child(hud)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Wear something in every slot so all four show a real icon.
	player.equip_weapon("rusty_blade")
	player.equip_armor("leather_armor")
	player.equip_helmet("iron_helmet")
	player.equip_secondary("wooden_shield")
	# Some loose items so the bag list shows icons and rarity colours too.
	for id in ["health_potion", "mana_potion", "iron_sword", "oak_staff",
			"apprentice_tome", "iron_ore", "wolf_fang", "mana_dust", "wood_log"]:
		player.inventory.add_item(id, 3)
	player.inventory.gold = 1234

	hud.inv_panel.visible = true
	hud._refresh_inv_list(player.inventory)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(OUT_PATH)
	if err != OK:
		push_error("could not save %s (%d)" % [OUT_PATH, err])
		get_tree().quit(1)
		return
	print("wrote: " + ProjectSettings.globalize_path(OUT_PATH))

	# Report what the UI is actually showing, so a blank panel cannot pass.
	print("bag rows: %d" % hud.inv_list.item_count)
	var with_icon := 0
	for i in hud.inv_list.item_count:
		if hud.inv_list.get_item_icon(i) != null:
			with_icon += 1
	print("bag rows with an icon: %d" % with_icon)
	for button in hud.equip_row.get_children():
		if button is Button:
			print("  slot %-10s icon=%s  disabled=%s" % [
				button.name, button.icon != null, button.disabled])
	print("stats line: %s" % hud.stats_text.text)
	get_tree().quit(0)
