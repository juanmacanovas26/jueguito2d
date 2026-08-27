extends Node
## Dev tool: drives a real Player + HUD through learning an off-kit ability
## and then live-switching kit, to see the skill bar and stats actually
## update on screen (not just assert on internal state). Screenshots +
## prints state, does not assert.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/kit_switch_screenshot.tscn

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const HUD_SCENE := "res://scenes/ui/hud.tscn"
const OUT_PATH_BEFORE := "user://kit_switch_before.png"
const OUT_PATH_AFTER := "user://kit_switch_after.png"


func _ready() -> void:
	var player = load(PLAYER_SCENE).instantiate()
	add_child(player)
	var hud = load(HUD_SCENE).instantiate()
	add_child(hud)
	await get_tree().physics_frame
	await get_tree().physics_frame

	player.progression.gain("heavy_swords", 30.0)
	player.learn_ability("frost_nova")
	# SkillBar rebuilds in _process() (idle frame), not _physics_process() —
	# await THAT, or the read below observes a stale, one-step-late bar.
	await get_tree().process_frame
	await get_tree().process_frame

	print("-- WARRIOR, after gaining progression + learning frost_nova --")
	print("kit: %s" % player._kit_name())
	print("known_abilities: " + str(player.known_abilities))
	print("total skill points: %.1f" % player.progression.total_points())
	print("skill bar slot ids: " + str(_slot_ids(hud)))
	print("level_text: '%s'" % hud.level_text.text)
	await _shot(OUT_PATH_BEFORE)

	player._switch_kit_live(player.Kit.MAGE)
	await get_tree().process_frame
	await get_tree().process_frame

	print("\n-- after live-switching to MAGE --")
	print("kit: %s" % player._kit_name())
	print("known_abilities: " + str(player.known_abilities))
	print("total skill points: %.1f" % player.progression.total_points())
	print("skill bar slot ids: " + str(_slot_ids(hud)))
	print("level_text: '%s'" % hud.level_text.text)
	await _shot(OUT_PATH_AFTER)

	get_tree().quit(0)


func _slot_ids(hud: Node) -> Array:
	var ids: Array = []
	for slot in hud.skill_bar._slots:
		ids.append(slot.skill_id)
	return ids


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	if err != OK:
		push_error("could not save %s (%d)" % [path, err])
		return
	print("wrote: " + ProjectSettings.globalize_path(path))
