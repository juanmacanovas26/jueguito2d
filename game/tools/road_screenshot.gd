extends Node2D
## Renders the "CAMINO (auto)" brush across the shapes a road is actually
## made of — a straight run, a right-angle turn, a diagonal, a fork and a
## plaza — so the autotiling can be EYEBALLED. Dev tool.
##
## validate_road_autotile.tscn already proves the mask maths picks the tile
## the table names; only a render proves the tile the table names is the one
## that belongs there. A mirrored stand-in whose bits are the wrong way round
## (see RoadAutotileTable) would pass every headless check and be obvious
## here at a glance.
##
##   Godot_v4.7.1-stable_win64_console.exe --path game \
##       res://tools/road_screenshot.tscn
##
## Renders every style by default; pass one to narrow it down:
##   ... res://tools/road_screenshot.tscn -- adoquin

const OUT_PATH := "user://road_render.png"
const CELL := BuildGrid.TILE_SIZE
## Cells between one style's block and the next, left for the labels.
const GAP := 3


func _ready() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		only = str(arg)
	var styles := RoadAutotiler.styles()
	if only != "":
		styles = styles.filter(func(s: String) -> bool: return s == only)
		if styles.is_empty():
			push_error("unknown style '%s' — have %s" % [only, RoadAutotiler.styles()])
			get_tree().quit(1)
			return

	var shape := _shape()
	var width: int = 0
	for cell in shape:
		width = maxi(width, cell.x + 2)
	var height: int = 0
	for cell in shape:
		height = maxi(height, cell.y + 2)

	# A flat dark backdrop rather than grass: the road tiles carry alpha, and
	# what has to be legible here is exactly WHERE the alpha is.
	var bg := ColorRect.new()
	bg.color = Color(0.17, 0.30, 0.16)
	bg.size = Vector2(width * CELL + 60, styles.size() * (height + GAP) * CELL + 40)
	add_child(bg)

	for i in styles.size():
		var style: String = styles[i]
		var origin := Vector2i(1, 1 + i * (height + GAP))
		_paint(style, shape, origin)
		var label := Label.new()
		label.text = style
		label.position = Vector2(8, (origin.y - 1) * CELL + 4)
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		add_child(label)

	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	cam.enabled = true
	add_child(cam)
	cam.make_current()
	get_viewport().get_window().size = Vector2i(bg.size)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.save_png(OUT_PATH) != OK:
		push_error("could not save " + OUT_PATH)
		get_tree().quit(1)
		return
	print("wrote: " + ProjectSettings.globalize_path(OUT_PATH))
	get_tree().quit(0)


## The test layout, in cells: separate figures rather than one sprawling
## road, so each case can be judged on its own.
##
##   1. a straight 2-wide run, the narrowest a road can be in this art
##   2. a right-angle turn — the "curve" case, which must stay ROUNDED
##   3. a 2-cell staircase down-right, the thinnest diagonal a square grid
##      has, and the case the bevels exist for
##   4. the same staircase up-right, to catch a mirror applied the wrong way
##   5. a plaza with a road feeding into it, for the interior fills and the
##      concave corners where the two meet
func _shape() -> Array:
	var cells := {}

	# 1. straight
	for y in range(7):
		for x in range(2):
			cells[Vector2i(x, y)] = true

	# 2. right-angle turn
	for y in range(5):
		for x in range(4, 6):
			cells[Vector2i(x, y)] = true
	for x in range(4, 10):
		for y in range(5, 7):
			cells[Vector2i(x, y)] = true

	# 3. staircase down-right
	for i in range(7):
		cells[Vector2i(12 + i, i)] = true
		cells[Vector2i(13 + i, i)] = true

	# 4. staircase up-right
	for i in range(7):
		cells[Vector2i(21 + i, 6 - i)] = true
		cells[Vector2i(22 + i, 6 - i)] = true

	# 5. plaza, entered from the west
	for y in range(1, 6):
		for x in range(34, 40):
			cells[Vector2i(x, y)] = true
	for x in range(30, 35):
		for y in range(3, 5):
			cells[Vector2i(x, y)] = true

	return cells.keys()


func _paint(style: String, shape: Array, origin: Vector2i) -> void:
	var built := PaintedFloorTileset.build()
	var layer := TileMapLayer.new()
	layer.tile_set = built["tileset"]
	add_child(layer)

	var source_ids: Dictionary = built["source_ids"]
	var cells := {}
	for cell in shape:
		cells[cell] = true
	for cell in shape:
		var mask := RoadAutotiler.mask_at(cells, cell)
		var picked := RoadAutotiler.resolve(
			style, mask, RoadAutotiler.bevel_at(cells, cell, mask))
		if picked.is_empty():
			continue
		var source_id := int(source_ids.get(str(picked[0]), -1))
		if source_id < 0:
			push_warning("%s: no source for %s" % [style, picked[0]])
			continue
		layer.set_cell(origin + cell, source_id, Vector2i.ZERO, int(picked[1]))
