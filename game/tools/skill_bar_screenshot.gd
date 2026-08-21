extends Node
## Renders a real HUD's skill bar on the mage's 3-skill loadout, with one slot
## mid-cooldown, one just-flashed-ready, and one armed — so the whole visual
## language (icon, radial sweep, countdown, key label, armed border) can
## actually be looked at in one shot. Dev tool.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/skill_bar_screenshot.tscn

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const HUD_SCENE := "res://scenes/ui/hud.tscn"
const OUT_PATH := "user://skill_bar_render.png"


func _ready() -> void:
	var player = load(PLAYER_SCENE).instantiate()
	add_child(player)
	var hud = load(HUD_SCENE).instantiate()
	add_child(hud)
	await get_tree().physics_frame
	await get_tree().physics_frame

	player._set_kit(player.Kit.MAGE)
	await get_tree().process_frame
	await get_tree().process_frame

	# frost_nova: mid-cooldown, sweeping.
	player.skills._cooldowns["frost_nova"] = 5.0
	# arcane_bolt: ready — force the just-became-ready flash into frame.
	player.skills._cooldowns["arcane_bolt"] = 0.0
	# smite: armed, so the border shows its highlighted/glow state.
	player.aimer.arm("smite")

	for slot in hud.skill_bar._slots:
		slot.update(player.skills, player.aimer)
	for slot in hud.skill_bar._slots:
		if slot.skill_id == "arcane_bolt":
			slot._flash_ready()

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(OUT_PATH)
	if err != OK:
		push_error("could not save %s (%d)" % [OUT_PATH, err])
		get_tree().quit(1)
		return
	print("wrote: " + ProjectSettings.globalize_path(OUT_PATH))

	print("skill bar slots: %d" % hud.skill_bar._slots.size())
	for slot in hud.skill_bar._slots:
		print("  slot %-12s cooldown_left=%.2f armed=%s" % [
			slot.skill_id, player.skills.cooldown_left(slot.skill_id), slot._armed])
	# smite's arm() swaps in a custom OS cursor (see SkillAimer.CURSOR_TEX) —
	# clear it before quitting so its texture RID doesn't outlive the process.
	Input.set_custom_mouse_cursor(null)
	get_tree().quit(0)
