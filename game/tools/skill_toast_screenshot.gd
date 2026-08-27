extends Node
## Dev tool: drives a real Player + HUD through a kill, a gather, and a craft
## to see what the toast label and the repurposed level_text actually show —
## checking whether the Vitality kicker's toast clobbers the primary skill's
## toast (single Label, no queue — see hud.gd's _on_toast) and whether
## level_text is readable. Screenshots + prints state, does not assert.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/skill_toast_screenshot.tscn

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const HUD_SCENE := "res://scenes/ui/hud.tscn"
const MOB_SCENE := "res://scenes/enemy/chase_mob.tscn"
const RESOURCE_NODE_SCENE := "res://scenes/world/resource_node.tscn"
const OUT_PATH := "user://skill_toast_render.png"


func _ready() -> void:
	var player = load(PLAYER_SCENE).instantiate()
	add_child(player)
	var hud = load(HUD_SCENE).instantiate()
	add_child(hud)
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("-- fresh spawn --")
	print("level_text: '%s'" % hud.level_text.text)
	print("toast visible: %s  text: '%s'" % [hud.toast_label.visible, hud.toast_label.text])

	var mob = load(MOB_SCENE).instantiate()
	mob.max_hp = 10.0
	mob.skill_gain = 18
	add_child(mob)
	await get_tree().physics_frame
	mob._last_attacker = player
	mob.health.take_damage({"damage": mob.health.max_hp + 10.0})
	await get_tree().physics_frame

	print("\n-- right after a kill (ARCHER/WARRIOR default kit) --")
	print("kit's combat skill: %s" % player.combat_skill_id())
	print("combat skill points: %.2f" % player.progression.get_points(player.combat_skill_id()))
	print("vitality points: %.2f" % player.progression.get_points("vitality"))
	print("toast text (what the player actually sees): '%s'" % hud.toast_label.text)
	print("level_text: '%s'" % hud.level_text.text)

	var vein = load(RESOURCE_NODE_SCENE).instantiate()
	vein.visual_type = "vein"
	vein.immortal = true
	add_child(vein)
	await get_tree().physics_frame
	for i in 3:
		vein.gather(true, player)
		await get_tree().physics_frame
		print("\n-- after auto-farm tick %d --" % (i + 1))
		print("mining points: %.2f" % player.progression.get_points("mining"))
		print("toast text: '%s'" % hud.toast_label.text)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(OUT_PATH)
	if err != OK:
		push_error("could not save %s (%d)" % [OUT_PATH, err])
		get_tree().quit(1)
		return
	print("\nwrote: " + ProjectSettings.globalize_path(OUT_PATH))
	get_tree().quit(0)
