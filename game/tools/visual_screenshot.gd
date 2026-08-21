extends Node2D
## Renders the real Player node through the real Godot renderer and saves a
## screenshot, so the live result (nearest filtering, flip_h, layer order, feet
## alignment against the collision box) can be checked, not just the source art.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/visual_screenshot.tscn
##
## Writes user://player_render.png. Needs a real (non-headless) run.

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const OUT_PATH := "user://player_render.png"

## anim -> the player State that produces it, laid out left to right.
## [animation, direction, frame to hold]. The attack frames are the swing
## itself, so the handed EAST vs WEST art can be compared side by side.
## [animation, direction, frame, visual_state]. An empty visual_state is the
## naked base body; naming one equips that appearance set, so the same pose can
## be compared with and without it.
## One pose per weapon kind, to show each drives its own attack animation.
const RACES := ["head/Human Male", "head/Orc male", "head/Skeleton",
	"head/Lizard male", "head/Minotaur", "head/Vampire"]

const POSES := [
	[&"attack_slash",  CharacterFacing.Direction.SOUTH, 4, "w:arming_sword"],
	[&"attack_slash",  CharacterFacing.Direction.EAST,  4, "w:scythe"],
	[&"attack_thrust", CharacterFacing.Direction.SOUTH, 5, "w:spear"],
	[&"attack_thrust", CharacterFacing.Direction.EAST,  5, "w:halberd"],
	[&"attack_cast",   CharacterFacing.Direction.SOUTH, 5, "w:simple_staff"],
	[&"attack_cast",   CharacterFacing.Direction.EAST,  5, "w:simple_staff"],
	[&"attack_shoot",  CharacterFacing.Direction.SOUTH, 8, "w:slingshot"],
	[&"attack_shoot",  CharacterFacing.Direction.EAST,  8, "w:slingshot"],
]

const SPACING := 110


func _ready() -> void:
	var packed = load(PLAYER_SCENE)
	var x := 80
	for pose in POSES:
		var p = packed.instantiate()
		p.position = Vector2(x, 150)
		add_child(p)
		# _physics_process re-enables itself on tree entry, and the player would
		# immediately reset the pose to idle/SOUTH. Disable it AFTER add_child.
		p.set_physics_process(false)
		# Each Player carries its own Camera2D; with several on screen the last
		# one would take over and push the rest out of frame.
		var cam: Camera2D = p.get_node_or_null("Camera2D")
		if cam != null:
			cam.enabled = false
		var v: CharacterVisual = p.get_node("CharacterVisual")
		var kit := str(pose[3])
		if kit.begins_with("w:"):
			v.set_equipment("armor", "leather_armor")
			v.set_equipment("legs", "pants")
			v.set_equipment("feet", "rimmed_boots")
			v.set_equipment("weapon", kit.substr(2))
		elif kit.begins_with("race"):
			# Identical gear, only the head swaps.
			v.set_appearance("body/Body Color", RACES[int(kit.substr(4))], "hair/Spiked")
			v.set_equipment("armor", "legion_armor")
			v.set_equipment("legs", "pantaloons")
			v.set_equipment("feet", "revised_boots")
			v.set_equipment("shoulders", "legion_pauldrons")
			v.set_equipment("weapon", "saber")
			v.set_equipment("secondary", "scutum_shield")
		elif kit == "full":
			v.set_equipment("armor", "plate_armor")
			v.set_equipment("legs", "plate_leggings")
			v.set_equipment("feet", "plate_boots")
			v.set_equipment("arms", "plate_bracers")
			v.set_equipment("gloves", "gloves")
			v.set_equipment("shoulders", "pauldrons")
			v.set_equipment("wrists", "bracers")
			v.set_equipment("helmet", "greathelm")
			v.set_equipment("weapon", "longsword")
			v.set_equipment("secondary", "crusader_shield")
		elif kit == "light":
			v.set_equipment("armor", "leather_armor")
			v.set_equipment("legs", "pants")
			v.set_equipment("feet", "rimmed_boots")
			v.set_equipment("shoulders", "mantle")
			v.set_equipment("wrists", "cuffs")
			v.set_equipment("weapon", "dagger")
		v.set_direction(pose[1])
		v.play(pose[0], true)
		v.set_process(false)           # freeze the clock...
		v.seek_frame(pose[2])          # ...on the frame we want to look at

		# Guide: the bottom edge of the 18x26 CollisionShape2D at (0, 2), i.e.
		# the point the character stands on. The feet must sit on this line.
		var dot := ColorRect.new()
		dot.color = Color(1, 0.2, 0.2)
		dot.size = Vector2(20, 1)
		dot.position = Vector2(x - 10, 150 + 15)
		add_child(dot)
		x += SPACING

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(OUT_PATH)
	if err != OK:
		push_error("could not save %s (%d)" % [OUT_PATH, err])
		get_tree().quit(1)
		return
	print("wrote: " + ProjectSettings.globalize_path(OUT_PATH))
	var names := PackedStringArray()
	for pose in POSES:
		var worn := str(pose[3]) if str(pose[3]) != "" else "naked"
		names.append("%s %s f%d (%s)" % [pose[0], CharacterFacing.dir_name(pose[1]), pose[2], worn])
	print("poses left to right: " + ", ".join(names))
	print("the red tick is the bottom of the collision box — the feet should sit on it")
	get_tree().quit(0)
