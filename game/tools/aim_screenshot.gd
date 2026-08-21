extends Node2D
## Renders the aiming indicator for one skill of each targeting mode, so the
## range and area preview can actually be looked at. Dev tool.

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const OUT_PATH := "user://aim_render.png"

## [skill, where the cursor is relative to the player]
const SHOTS := [
	["whirlwind", Vector2(0, 0)],
	["shoulder_bash", Vector2(120, -30)],
	["smite", Vector2(160, 10)],
	["frost_nova", Vector2(140, -40)],
	["arcane_bolt", Vector2(150, -60)],
	["multishot", Vector2(150, -60)],
]

const SPACING := 320


func _ready() -> void:
	var packed = load(PLAYER_SCENE)
	var x := 200
	var aimers: Array = []
	for shot in SHOTS:
		var p = packed.instantiate()
		p.position = Vector2(x, 260)
		add_child(p)
		p.set_physics_process(false)
		var cam: Camera2D = p.get_node_or_null("Camera2D")
		if cam != null:
			cam.enabled = false
		var aimer: SkillAimer = p.get_node("SkillAimer")
		aimer.arm(str(shot[0]))
		aimer.set_process(false)
		# multishot doubles as the demo for the "can't cast" warning icon —
		# nobody in this headless render has a bow equipped.
		if str(shot[0]) == "multishot":
			aimer.blocked = true
		# Place the aim point by hand: no real mouse in a headless-ish run.
		aimer._point = p.position + (shot[1] as Vector2)
		aimer.queue_redraw()
		aimers.append(aimer)
		x += SPACING

	var cam2 := Camera2D.new()
	cam2.zoom = Vector2(0.42, 0.42)
	add_child(cam2)
	cam2.make_current()
	cam2.global_position = Vector2(float(x - SPACING) * 0.5 + 100.0, 260)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT_PATH)
	print("wrote: " + ProjectSettings.globalize_path(OUT_PATH))
	for a in aimers:
		print("  %-12s aiming=%s visible=%s" % [a.current_skill(), a.is_aiming(), a.visible])
	# smite's arm() swaps in a custom OS cursor (see SkillAimer.CURSOR_TEX) —
	# clear it before quitting so its texture RID doesn't outlive the process.
	Input.set_custom_mouse_cursor(null)
	get_tree().quit(0)
