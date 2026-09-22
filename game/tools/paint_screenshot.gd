extends Node2D
## Renders the free brush (PaintLayer) over a grass background, so the thing
## that can only be judged by eye can be judged by eye: the shape of the edge.
##
## The mask maths is easy to get right and easy to check headlessly. What is
## neither is whether the result looks like a worn dirt track or like a smooth
## vector blob pasted onto pixel art — that is what the shader's per-world-pixel
## threshold jitter is for, and this is the only way to see it.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/paint_screenshot.tscn
##
## Optional args: radius (world px) and jitter, to compare settings:
##   ... res://tools/paint_screenshot.tscn -- 40 0.22
##
## Or one stroke per brush, which is what PaintLayer.TEXTURES is curated
## against (the seam number alone gets brick wrong — see validate_paint_layer):
##   ... res://tools/paint_screenshot.tscn -- sampler

const OUT_PATH := "user://paint_render.png"
const ZONE := Vector2(960, 640)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and str(args[0]) == "sampler":
		await _sampler()
		return
	var radius := float(args[0]) if args.size() > 0 else 34.0
	var jitter := float(args[1]) if args.size() > 1 else -1.0

	_grass()
	var layer := PaintLayer.new()
	layer.world_size = ZONE
	layer.texture_id = "tierra"
	add_child(layer)
	if jitter >= 0.0:
		(layer.material as ShaderMaterial).set_shader_parameter("jitter", jitter)

	# A winding track, a wide clearing it opens into, and a thin tail — the
	# three things a free brush is actually used for.
	layer.begin_stroke()
	for i in 220:
		var t := i / 219.0
		var p := Vector2(60.0 + t * 520.0, 300.0 + sin(t * 5.2) * 150.0)
		layer.paint(p - ZONE * 0.5, radius, false)
	for i in 90:
		var a := i / 89.0 * TAU
		layer.paint(Vector2(720, 300) + Vector2(cos(a), sin(a)) * 70.0 - ZONE * 0.5,
			radius * 1.6, false)
	for i in 80:
		var t := i / 79.0
		layer.paint(Vector2(760.0 + t * 160.0, 300.0 - t * 200.0) - ZONE * 0.5,
			radius * 0.4, false)
	# And a bite taken back out, to prove erasing works and leaves the same
	# kind of edge rather than a clean circle.
	for i in 30:
		var a := i / 29.0 * TAU
		layer.paint(Vector2(360, 300) + Vector2(cos(a), sin(a)) * 26.0 - ZONE * 0.5,
			radius * 0.7, true)
	layer.end_stroke()

	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE
	cam.enabled = true
	add_child(cam)
	cam.make_current()
	get_viewport().get_window().size = Vector2i(ZONE)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.save_png(OUT_PATH) != OK:
		push_error("could not save " + OUT_PATH)
		get_tree().quit(1)
		return
	print("wrote: " + ProjectSettings.globalize_path(OUT_PATH))
	get_tree().quit(0)


## One stroke per brush over grass, labelled — the render TEXTURES is curated
## against. A texture that does not belong (a shore stripe, a flat colour)
## is obvious here and invisible in any number.
func _sampler() -> void:
	var ids := PaintLayer.TEXTURES.keys()
	var row_h := 76
	var size := Vector2(720, row_h * ids.size() + 16)
	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.53, 0.31)
	bg.size = size
	bg.position = -size * 0.5
	add_child(bg)

	for i in ids.size():
		var layer := PaintLayer.new()
		layer.world_size = size
		layer.texture_id = str(ids[i])
		add_child(layer)
		var y := -size.y * 0.5 + row_h * i + 46.0
		for step in 130:
			var t := step / 129.0
			layer.paint(Vector2(-260.0 + t * 500.0, y + sin(t * 6.0) * 15.0), 26.0, false)
		var label := Label.new()
		label.text = str(ids[i])
		label.position = Vector2(-size.x * 0.5 + 8, y - 40)
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		label.z_index = 10
		add_child(label)

	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE
	cam.enabled = true
	add_child(cam)
	cam.make_current()
	get_viewport().get_window().size = Vector2i(size)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT_PATH)
	print("wrote: " + ProjectSettings.globalize_path(OUT_PATH))
	get_tree().quit(0)


## Plain tiled grass to paint over — the point is the boundary between the
## two, so there has to be something on the other side of it.
func _grass() -> void:
	var path := PaintLayer.texture_path("pasto")
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var size := tex.get_size()
	for y in int(ZONE.y / size.y) + 1:
		for x in int(ZONE.x / size.x) + 1:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.position = Vector2(x * size.x, y * size.y) - ZONE * 0.5
			s.z_index = -10
			add_child(s)
