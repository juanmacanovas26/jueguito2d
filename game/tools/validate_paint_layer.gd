extends Node
## Headless coverage for the "PINCEL (libre)" brush — PaintLayer's mask, the
## stroke/undo round trip, and the zone wiring that lets a click reach it.
##
## What it deliberately does NOT check is how the edge LOOKS; that lives in the
## shader and only a render shows it (tools/paint_screenshot.tscn).
##
##   Godot_v4.7.1-stable_win64_console.exe --headless --path game \
##       res://tools/validate_paint_layer.tscn
##
## Exits 0 when everything passes, 1 otherwise.

const WORLD_ZONE_SCRIPT := preload("res://scripts/world/world_zone.gd")
const TEST_SCENE_PATH := "res://tools/__validate_paint_layer_tmp.tscn"
const ZONE := Vector2(640, 480)
## Seam budget for _seam() below. A SMOKE TEST, not an oracle — read its doc
## before tightening it.
const MAX_SEAM := 1.0
const MIN_CHECKS := 25

var _failures: Array = []
var _checks := 0


func _ready() -> void:
	_test_textures()
	_test_brush()
	_test_stroke_undo()
	_test_persistence()
	_test_zone()

	_expect(_checks >= MIN_CHECKS,
		"ran at least %d checks (got %d) — did a section silently skip?" % [MIN_CHECKS, _checks])
	print("\n-- %d checks, %d failures --" % [_checks, _failures.size()])
	for f in _failures:
		print("FAIL: " + f)
	print("RESULT: " + ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _ok(label: String) -> void:
	_checks += 1
	print("  ok   " + label)


func _fail(label: String) -> void:
	_checks += 1
	_failures.append(label)
	print("  FAIL " + label)


func _expect(cond: bool, label: String) -> void:
	if cond:
		_ok(label)
	else:
		_fail(label)


## The shader tiles these across the whole zone, so a texture with a border
## baked into it would draw a grid of borders over every painted patch. This
## is the check that stops someone pointing TEXTURES at a nice-looking piece
## that happens not to repeat — which is exactly what the road art was full of.
func _test_textures() -> void:
	print("\n[textures]")
	_expect(not PaintLayer.TEXTURES.is_empty(), "the brush offers at least one texture")
	for id in PaintLayer.TEXTURES:
		var path := PaintLayer.texture_path(str(id))
		_expect(ResourceLoader.exists(path), "%s's art exists (%s)" % [id, path])
		if not ResourceLoader.exists(path):
			continue
		var seam := _seam(path)
		_expect(seam <= MAX_SEAM,
			"  and repeats without an obvious seam (%.2f, budget %.2f)" % [seam, MAX_SEAM])
		var tex: Texture2D = load(path)
		_expect(tex.get_size() == Vector2(BuildGrid.TILE_SIZE, BuildGrid.TILE_SIZE),
			"  and is one %dpx cell" % BuildGrid.TILE_SIZE)
	_expect(PaintLayer.is_paint_id(PaintLayer.palette_id("tierra")),
		"a palette id round-trips through is_paint_id()")
	_expect(not PaintLayer.is_paint_id("paint_nonexistent"),
		"  and an unknown texture is not mistaken for one")
	_expect(not PaintLayer.is_paint_id("floor_autoroad_adoquin"),
		"  nor is a grid brush")


## How much the seam between two copies of a tile stands out against the
## sharpest transition the tile already makes internally. Lower is better; 1.0
## means the seam is exactly as strong as the tile's own worst edge.
##
## Deliberately measured against the WORST internal transition, not the
## average one. The average is what tools/bake_road_autotile.py uses, and for
## the question it asks (does this ROAD EDGE repeat along its run?) it is
## right — but as a test of "is this a tileable fill" it rejects brick
## outright: a brick wall's columns are near-identical except at the mortar
## joints, so its average transition is tiny and any seam landing on a joint
## looks catastrophic by that yardstick, while tiling perfectly.
##
## This is a SMOKE TEST and nothing more. It catches a texture that does not
## repeat at all; it cannot tell a ground from a stripe, and it disagrees with
## the eye in both directions in the middle of its range. What actually
## decides TEXTURES is looking at a 3x3 render of each candidate — see
## tools/paint_screenshot.tscn's sampler and PaintLayer's note.
func _seam(path: String) -> float:
	var img: Image = (load(path) as Texture2D).get_image()
	var w := img.get_width()
	var h := img.get_height()
	var seam_h := 0.0
	var seam_v := 0.0
	for y in h:
		seam_h += _diff(img.get_pixel(w - 1, y), img.get_pixel(0, y))
	for x in w:
		seam_v += _diff(img.get_pixel(x, h - 1), img.get_pixel(x, 0))
	var worst_h := 1.0
	for x in w - 1:
		var col := 0.0
		for y in h:
			col += _diff(img.get_pixel(x, y), img.get_pixel(x + 1, y))
		worst_h = maxf(worst_h, col)
	var worst_v := 1.0
	for y in h - 1:
		var row := 0.0
		for x in w:
			row += _diff(img.get_pixel(x, y), img.get_pixel(x, y + 1))
		worst_v = maxf(worst_v, row)
	return maxf(seam_h / worst_h, seam_v / worst_v)


func _diff(a: Color, b: Color) -> float:
	return (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) * 255.0


func _layer() -> PaintLayer:
	var layer := PaintLayer.new()
	layer.world_size = ZONE
	layer.texture_id = "tierra"
	return layer


func _test_brush() -> void:
	print("\n[brush]")
	var layer := _layer()
	_expect(layer.is_empty(), "a fresh layer has nothing painted")
	_expect(layer.coverage_at(Vector2.ZERO) == 0.0, "  and no coverage anywhere")
	# A zone builds one layer per brush, so an unpainted one must cost nothing
	# but the node — eight masks at full size would be ~34MB per zone whether
	# or not anybody painted. texture stays null until the mask is allocated.
	_expect(layer.texture == null, "  and has allocated no mask at all")
	_expect(PaintLayer.TEXTURES.size() >= 2,
		"  (a real saving: there are %d brushes)" % PaintLayer.TEXTURES.size())

	layer.paint(Vector2.ZERO, 40.0, false)
	_expect(layer.texture != null, "the first dab allocates the mask")
	_expect(layer.coverage_at(Vector2.ZERO) > 0.9, "a dab covers its centre")
	_expect(layer.coverage_at(Vector2(200, 0)) == 0.0, "  and nothing far from it")
	_expect(not layer.is_empty(), "  so the layer is no longer empty")

	# The falloff is what the shader thresholds into a ragged edge, so there
	# has to BE a falloff: a ring of partial coverage between the solid middle
	# and the untouched outside.
	var partial := 0
	for r in range(10, 42, 2):
		var c := layer.coverage_at(Vector2(r, 0))
		if c > 0.05 and c < 0.95:
			partial += 1
	_expect(partial >= 3, "a dab has a soft rim, not a hard disc (%d partial samples)" % partial)

	# THE regression: dabs compose with max(), not alpha-over. Under alpha-over
	# a drag's overlapping dabs drive even a 0.1 edge pixel to ~1, the rim
	# collapses into a hard circle, and the ragged edge goes with it. This was
	# a real bug, caught by rendering rather than by any of the above.
	var dragged := _layer()
	for i in 60:
		dragged.paint(Vector2(-100.0 + i * 2.0, 0), 40.0, false)
	var soft := 0
	for r in range(10, 44, 2):
		var c := dragged.coverage_at(Vector2(0, r))
		if c > 0.05 and c < 0.95:
			soft += 1
	_expect(soft >= 3,
		"a long drag of overlapping dabs KEEPS that soft rim (%d partial samples)" % soft)
	_expect(dragged.coverage_at(Vector2.ZERO) <= 1.0, "  and coverage never exceeds 1")

	# Erasing takes coverage away rather than painting a hole of "not dirt".
	layer.paint(Vector2.ZERO, 40.0, true)
	_expect(layer.coverage_at(Vector2.ZERO) < 0.05, "erasing clears what it covers")

	# Out-of-bounds dabs are clipped, not wrapped onto the other side.
	var edge := _layer()
	edge.paint(-ZONE * 0.5, 40.0, false)
	_expect(edge.coverage_at(ZONE * 0.5 - Vector2(2, 2)) == 0.0,
		"a dab at one corner does not bleed to the opposite one")
	for spare in [layer, dragged, edge]:
		spare.free()


func _test_stroke_undo() -> void:
	print("\n[stroke / undo]")
	var layer := _layer()
	_expect(layer.end_stroke().is_empty(), "closing a stroke that never opened yields nothing")

	layer.begin_stroke()
	_expect(layer.end_stroke().is_empty(), "  as does one that painted nothing")

	layer.begin_stroke()
	for i in 20:
		layer.paint(Vector2(-60.0 + i * 6.0, 10), 24.0, false)
	var step := layer.end_stroke()
	_expect(not step.is_empty(), "a stroke that painted yields an undo step")
	_expect(step.has("rect") and step.has("before"), "  carrying a rect and its previous pixels")
	var rect: Rect2i = step["rect"]
	var full := Vector2i(int(ZONE.x * PaintLayer.MASK_SCALE), int(ZONE.y * PaintLayer.MASK_SCALE))
	_expect(rect.size.x < full.x and rect.size.y < full.y,
		"  bounded to the stroke, not the whole zone (%s of %s)" % [rect.size, full])
	_expect(layer.coverage_at(Vector2(0, 10)) > 0.5, "  and the paint is there")

	layer.restore(rect, step["before"])
	_expect(layer.coverage_at(Vector2(0, 10)) == 0.0, "undoing the stroke puts the mask back")
	_expect(layer.is_empty(), "  leaving the layer empty again")
	layer.free()


func _test_persistence() -> void:
	print("\n[persistence]")
	var layer := _layer()
	_expect(layer.encode_mask().is_empty(), "an untouched layer encodes to nothing at all")

	layer.paint(Vector2(30, -20), 30.0, false)
	var blob := layer.encode_mask()
	_expect(not blob.is_empty(), "a painted layer encodes to a PNG blob")

	# The blob is what gets written into the zone scene, so what comes back
	# out of it has to be the same mask — this is the save/reload round trip.
	var reloaded := PaintLayer.new()
	reloaded.world_size = ZONE
	reloaded.texture_id = "tierra"
	reloaded.mask_png = blob
	for probe in [Vector2(30, -20), Vector2(40, -10), Vector2(200, 100)]:
		_expect(absf(reloaded.coverage_at(probe) - layer.coverage_at(probe)) < 0.01,
			"  and reloads with the same coverage at %s" % probe)
	layer.free()
	reloaded.free()


func _test_zone() -> void:
	print("\n[zone]")
	for id in PaintLayer.TEXTURES:
		_expect(BuildCatalog.ids_in_category("pincel").has(PaintLayer.palette_id(str(id))),
			"the palette offers '%s' under PINCEL (libre)" % PaintLayer.palette_id(str(id)))
		_expect(BuildIcons.get_icon(PaintLayer.palette_id(str(id))) != null,
			"  and it has a palette icon")
	_expect(BuildCatalog.ids_in_category("pincel").size() == PaintLayer.TEXTURES.size(),
		"the palette offers exactly the brush's textures")

	# A free brush must NOT be a grid kind: that flag drives snapping, the
	# per-cell dedup, and whether a drag paints a run of cells — all wrong here.
	_expect(not BuildPlacement.is_grid_kind(PaintLayer.palette_id("tierra")),
		"the free brush is not treated as a grid kind")

	# Never added to the live tree — world_zone.gd's real _ready() wants a
	# Floor child this suite has no reason to build. Same shape
	# validate_build_mode.gd's _make_zone() uses, for the same reason.
	var zone := Node2D.new()
	zone.set_script(WORLD_ZONE_SCRIPT)
	zone.scene_file_path = TEST_SCENE_PATH
	zone.set("world_size", ZONE)
	zone.call("_build_paint_layers")

	var kind := PaintLayer.palette_id("tierra")
	var layer: PaintLayer = zone.call("paint_layer_for", kind)
	_expect(layer != null, "the zone builds a layer for '%s'" % kind)
	if layer == null:
		zone.free()
		return
	_expect(layer.z_index == WORLD_ZONE_SCRIPT.Z_PINTURA,
		"  at Z_PINTURA (got %d)" % layer.z_index)
	_expect(WORLD_ZONE_SCRIPT.Z_FLOOR < WORLD_ZONE_SCRIPT.Z_PINTURA
		and WORLD_ZONE_SCRIPT.Z_PINTURA < WORLD_ZONE_SCRIPT.Z_SUELO,
		"  between the base floor and the painted floor (%d < %d < %d)"
			% [WORLD_ZONE_SCRIPT.Z_FLOOR, WORLD_ZONE_SCRIPT.Z_PINTURA, WORLD_ZONE_SCRIPT.Z_SUELO])
	_expect(zone.call("paint_layer_for", "floor_autoroad_adoquin") == null,
		"  and no layer for a kind that is not a brush")

	zone.call("paint_at", kind, Vector2(20, 20), false, 30.0)
	_expect(layer.coverage_at(Vector2(20, 20)) > 0.5, "a click through the zone paints")

	# Bounds are the zone's, same as every other tool: painting past the edge
	# of the world is refused rather than silently clamped inward.
	var outside := Vector2(ZONE.x, ZONE.y)
	zone.call("paint_at", kind, outside, false, 30.0)
	_expect(layer.coverage_at(outside) == 0.0, "  but a click outside the zone does not")
	zone.free()

	# The EDITOR path. The addon never calls _build_paint_layers() itself — it
	# calls ensure_render_layers(), the one entry point that primes a zone
	# being edited (see plugin.gd's _ensure_zone_layers()). If the brush is
	# not wired into THAT, the palette button exists and painting silently
	# does nothing, which is exactly the failure that is hard to spot.
	var edited := Node2D.new()
	edited.set_script(WORLD_ZONE_SCRIPT)
	edited.scene_file_path = TEST_SCENE_PATH
	edited.set("world_size", ZONE)
	var base_floor := TileMapLayer.new()
	base_floor.name = "Floor"
	edited.add_child(base_floor)
	edited.call("ensure_render_layers")
	for id in PaintLayer.TEXTURES:
		var made: PaintLayer = edited.call("paint_layer_for", PaintLayer.palette_id(str(id)))
		_expect(made != null,
			"ensure_render_layers() primes the '%s' brush layer for the editor" % id)
	edited.free()
